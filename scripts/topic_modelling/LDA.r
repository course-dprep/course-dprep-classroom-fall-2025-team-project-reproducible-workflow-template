##data cleaning and preparation for LDA

pkgs <- c(
  "readr","dplyr","tidyr","ggplot2","stringr","purrr",
  "here","data.table","googledrive",
  "tibble","tidytext","textmineR","digest","reshape2","wordcloud","RColorBrewer"
)
for(p in pkgs) if(!requireNamespace(p, quietly=TRUE)) install.packages(p)
invisible(lapply(pkgs, require, character.only=TRUE))

set.seed(1234)

# ---- Paths & folders
dir.create(here("data","training_data"), recursive = TRUE, showWarnings = FALSE)

# ---- Download raw review sample 
folder_id <- "1oRNbZpA4kXZRsvcNe5K1FRYFKqqT5W2h"
googledrive::drive_deauth()
folder <- drive_ls(as_id(folder_id))
filename <- "reviews_sampled.rds"
file_id <- folder[folder$name==filename,] %>% pull(id) %>% as.character()
drive_download(as_id(file_id), path = here("data","training_data",filename), overwrite = TRUE)

# --- Load data
reviews_sampled <- readRDS(here::here("data","training_data", "reviews_sampled.rds"))
business <- readRDS(here::here("data","raw_data","business.rds"))

# --- Merge info business (dplyr join)
reviews_sampled <- reviews_sampled %>%
  dplyr::left_join(
    business %>% dplyr::select(business_id, is_open, name, city),
    by = "business_id"
  )

# --- Filter language
reviews_sampled$language <- cld3::detect_language(reviews_sampled$text)
reviews_sampled <- reviews_sampled %>% dplyr::filter(language == "en")

# --- Remove too short reviews (char length)
reviews_sampled <- reviews_sampled %>%
  dplyr::mutate(length = stringr::str_length(text)) %>%
  dplyr::filter(length >= 30)

# --- Remove links
reviews_sampled <- reviews_sampled %>%
  dplyr::mutate(text = stringr::str_replace_all(
    text, "(?i)\\b(?:https?://|www\\.)\\S+", ""
  ))

# --- Strip city and restaurant names
regex_escape <- function(x) {
  stringr::str_replace_all(x, "([\\^$.|?*+()\\[\\]{}\\\\])", "\\\\\\1")
}

reviews_sampled <- reviews_sampled %>%
  dplyr::mutate(
    name_tokens = strsplit(tolower(coalesce(name, "")), "\\W+"),
    city_tokens = strsplit(tolower(coalesce(city, "")), "\\W+"),
    name_tokens = purrr::map(name_tokens, ~ .x[nchar(.x) >= 2]),
    city_tokens = purrr::map(city_tokens, ~ .x[nchar(.x) >= 2]),
    name_pat = purrr::map_chr(name_tokens, ~ if(length(.x)>0) paste0("\\b(", paste(regex_escape(.x), collapse="|"), ")\\b") else ""),
    city_pat = purrr::map_chr(city_tokens, ~ if(length(.x)>0) paste0("\\b(", paste(regex_escape(.x), collapse="|"), ")\\b") else "")
  ) %>%
  dplyr::mutate(
    text_label = tolower(text) %>%
      stringr::str_replace_all("[[:punct:]]+", " "),
    text_label = ifelse(name_pat != "", stringr::str_remove_all(text_label, name_pat), text_label),
    text_label = ifelse(city_pat != "", stringr::str_remove_all(text_label, city_pat), text_label),
    text_label = stringr::str_squish(text_label)
  ) %>%
  dplyr::select(-name_tokens, -city_tokens, -name_pat, -city_pat)

# --- Convert to tibble (compatibility)
reviews_sampled <- tibble::as_tibble(reviews_sampled)


# =========================
#   Medium steps (textmineR)
# =========================

# 1) LOADING OF DATA 
data <- reviews_sampled %>% transmute(text = text_label, id = review_id)

# 2) PRE-PROCESSING 

data$text <- sub("RT.*:", "", data$text)
data$text <- sub("@.* ", "", data$text)

text_cleaning_tokens <- data %>%
  tidytext::unnest_tokens(word, text)

text_cleaning_tokens$word <- gsub('[[:digit:]]+', '', text_cleaning_tokens$word)
text_cleaning_tokens$word <- gsub('[[:punct:]]+', '', text_cleaning_tokens$word)

text_cleaning_tokens <- text_cleaning_tokens %>%
  dplyr::filter(!(nchar(word) == 1)) %>%
  dplyr::anti_join(tidytext::stop_words, by = "word")

tokens <- text_cleaning_tokens %>% dplyr::filter(!(word == ""))


tokens <- tokens %>%
  dplyr::group_by(id) %>%
  dplyr::mutate(ind = dplyr::row_number()) %>%
  tidyr::spread(key = ind, value = word)
tokens[is.na(tokens)] <- ""
tokens <- tidyr::unite(tokens, text, -id, sep = " ")
tokens$text <- trimws(tokens$text)

# 3) MODEL BUILDING (CreateDtm / TermDocFreq / vocabulary)
dtm <- textmineR::CreateDtm(tokens$text,
                            doc_names    = tokens$id,
                            ngram_window = c(1, 2))  # uni + bigrammi come nel post

tf <- textmineR::TermDocFreq(dtm = dtm)
original_tf <- tf %>% dplyr::select(term, term_freq, doc_freq)
rownames(original_tf) <- 1:nrow(original_tf)

# vocabulary: term_freq > 1 & doc_freq <  docs
vocabulary <- tf$term[ tf$term_freq > 1 & tf$doc_freq < nrow(dtm) / 2 ]

# 3b) Tuning coherence su k=1..20 (CalcProbCoherence)
k_list <- seq(1, 20, by = 1)
model_dir <- paste0("models_", digest::digest(vocabulary, algo = "sha1"))
if (!dir.exists(model_dir)) dir.create(model_dir)

#  Windows TmParallelApply use export 
model_list <- textmineR::TmParallelApply(
  X = k_list,
  FUN = function(k){
    filename = file.path(model_dir, paste0(k, "_topics.rda"))
    if (!file.exists(filename)) {
      m <- textmineR::FitLdaModel(dtm = dtm, k = k, iterations = 500)
      m$k <- k
      m$coherence <- textmineR::CalcProbCoherence(phi = m$phi, dtm = dtm, M = 5)
      save(m, file = filename)
    } else {
      load(filename)  # carica 'm'
    }
    m
  },
  export = c("dtm","model_dir")
)

coherence_mat <- data.frame(
  k = sapply(model_list, function(x) nrow(x$phi)),
  coherence = sapply(model_list, function(x) mean(x$coherence)),
  stringsAsFactors = FALSE
)

# coherence plot 
p_coh <- ggplot(coherence_mat, aes(x = k, y = coherence)) +
  geom_point() +
  geom_line(group = 1) +
  ggtitle("Best Topic by Coherence Score") +
  theme_minimal() +
  scale_x_continuous(breaks = seq(1,20,1))
ggplot2::ggsave(here("data","training_data","coherence_plot.png"), p_coh, width = 7, height = 4, dpi = 150)

# choose model
model <- model_list[[ which.max(coherence_mat$coherence) ]]

# top terms per topic (GetTopTerms)
model$top_terms <- textmineR::GetTopTerms(phi = model$phi, M = 20)
top20_wide <- as.data.frame(model$top_terms)
readr::write_csv(top20_wide, here("data","training_data","lda_top_terms_textmineR.csv"))

# 3c) Dendrogram (Hellinger + hclust) 
model$topic_linguistic_dist <- textmineR::CalcHellingerDist(model$phi)
model$hclust <- hclust(as.dist(model$topic_linguistic_dist), "ward.D")
png(here("data","training_data","topics_dendrogram.png"), width=900, height=600)
plot(model$hclust, main = "Topic Dendrogram (Hellinger, ward.D)")
dev.off()

# 4) Wordcloud per topic 

# table with words and weights
final_summary_words <- data.frame(top_terms = t(model$top_terms))
final_summary_words$topic <- rownames(final_summary_words)
rownames(final_summary_words) <- 1:nrow(final_summary_words)
final_summary_words <- reshape2::melt(final_summary_words, id.vars = c("topic"))
final_summary_words <- final_summary_words %>%
  dplyr::rename(word = value) %>%
  dplyr::select(-variable)

# 'allterms' = phi long format
allterms <- reshape2::melt(model$phi)
colnames(allterms) <- c("topic","word","value")
allterms$topic <- as.character(allterms$topic)

final_summary_words <- dplyr::left_join(final_summary_words, allterms, by = c("topic","word")) %>%
  dplyr::group_by(topic, word) %>%
  dplyr::arrange(dplyr::desc(value)) %>%
  dplyr::filter(dplyr::row_number() == 1) %>%
  dplyr::ungroup()

# (optional) merge frequencies
word_topic_freq <- dplyr::left_join(final_summary_words, original_tf, by = c("word" = "term"))

pdf(here("data","training_data","topics_wordclouds.pdf"))
for(i in sort(unique(as.integer(final_summary_words$topic)))) {
  subset_i <- final_summary_words %>% dplyr::filter(as.integer(topic) == i)
  wordcloud(words = subset_i$word,
            freq  = subset_i$value,
            min.freq = 1, max.words = 200,
            random.order = FALSE, rot.per = 0.35,
            colors = RColorBrewer::brewer.pal(8, "Dark2"))
  title(paste("Topic", i))
}
dev.off()

# 5) Export probabilities per document (theta) + match topics
theta <- model$theta                        # Document x Topic
doc_ids <- rownames(theta)

# Prob per topic: prob_topic_1..K
probs_wide <- as.data.frame(theta)
colnames(probs_wide) <- paste0("prob_topic_", seq_len(ncol(theta)))
probs_wide$review_id <- rownames(theta)

assigned <- data.frame(
  review_id = rownames(theta),
  assigned_topic_id = apply(theta, 1, which.max)
)

# join 
base <- reviews_sampled %>% dplyr::filter(review_id %in% doc_ids)

out <- base %>%
  dplyr::left_join(probs_wide, by = "review_id") %>%
  dplyr::left_join(assigned,   by = "review_id")

readr::write_csv(out, here("data","training_data","reviews_lda_out_textmineR.csv"))

# end
cat("\nDone!\n",
    "Saved files in data/training_data/:\n",
    " - reviews_python_in.csv (pulito)\n",
    " - coherence_plot.png\n",
    " - lda_top_terms_textmineR.csv\n",
    " - topics_dendrogram.png\n",
    " - topics_wordclouds.pdf\n",
    " - reviews_lda_out_textmineR.csv (prob per doc + topic dominante)\n")
