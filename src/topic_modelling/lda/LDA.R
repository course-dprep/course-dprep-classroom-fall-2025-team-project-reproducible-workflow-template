# ========== SETUP ==========

# Packages used in this script
required_packages <- c("tidyverse","here","data.table",
					   "tidytext","textmineR","digest", "RColorBrewer", 
					   "quanteda", "scales", "gt", "proxy")

# Load all required packages, or print a reminder if missing
for (pkg in required_packages) {
	if (requireNamespace(pkg, quietly = TRUE)) {
		suppressWarnings(
			suppressPackageStartupMessages(
				library(pkg, character.only = TRUE)
			)
		)
	} else {
		message(sprintf(
			"Package '%s' is not installed. Please run dependencies/install_packages.R first.",
			pkg
		))
	}
}


# ========== GLOBAL SETTINGS ==========

# Define main output directories for saving tables and processed data
out_dir_tables <- here::here("gen", "tables")
out_dir_final_data <- here::here("data", "final_data")

# Create folders if they don't exist yet
if (!dir.exists(out_dir_tables)) dir.create(out_dir_tables, recursive = TRUE)
if (!dir.exists(out_dir_final_data)) dir.create(out_dir_final_data, recursive = TRUE)

# Input file paths
input_paths <- list(
	reviews_ner_masked = here("data", "training_data", "reviews_ner_masked.csv"),
	reviews_sampled    = here("data", "training_data", "reviews_sampled.rds")
)

# Output file paths (for models, tables, plots)
output_paths <- list(
	theta               = here("data", "final_data", "theta.csv"),
	phi                 = here("data", "final_data", "phi.csv"),
	coherence_table     = here("gen","tables", "coherence_table.html"),
	coherence_elbow     = here("gen", "figures", "coherence_elbow_plot.pdf"),
	lda_vis             = here("gen", "figures", "lda_vis.pdf"),
	top_terms_pre_frex  = here("gen", "tables", "top_terms_pre_frex.html"),
	top_terms_post_frex = here("gen", "tables", "top_terms_post_frex.html"),
	lda_model           = here("data", "final_data", "lda_model.rds")
)

# Set seed for reproducibility
set.seed(999)


# ========== INPUT ==========

# Load masked reviews
reviews <- read.csv(input_paths$reviews_ner_masked)
reviews <- tibble::as_tibble(reviews)

# Keep only the text column used for topic modeling
data <- reviews %>% transmute(text = masked_for_lda, id = review_id)

# Load the sampled review set (for reference)
reviews_sampled <- readRDS(input_paths$reviews_sampled)


# ========== TEXT CLEANING & TOKENIZATION ==========

# Pattern for placeholder tags created during NER masking
PLACE <- "(?i)_(?:FOOD|RESTAURANT|LOCATION)_"

# Remove placeholders from text and count how many were replaced
data <- data %>%
	dplyr::mutate(
		n_placeholders = str_count(text, PLACE),
		text = str_squish(str_replace_all(text, PLACE, " "))
	)

# Tokenize text and clean it up
tokens <- data %>%
	tidytext::unnest_tokens(word, text, strip_punct = TRUE) %>%   
	filter(!(word %in% quanteda::stopwords("en"))) %>%  # remove stopwords
	filter(nchar(word) > 1) %>%                         # remove single-letter tokens
	mutate(word = tolower(word)) %>%                    # lowercase everything
	mutate(word = gsub("[[:digit:]]+", " ", word)) %>%  # remove numbers
	mutate(word = str_squish(word)) %>%                 # trim extra spaces
	filter(word != "")                                  # drop empty tokens

# Recombine tokens back into a clean string per review
data_cleaned <- tokens %>%
	group_by(id) %>%
	summarise(text = paste(word, collapse = " "), .groups = "drop")


# ========== CREATE DTM & FILTER VOCABULARY ==========

# Build the document-term matrix
dtm <- textmineR::CreateDtm(data_cleaned$text,
							doc_names    = data_cleaned$id,
							ngram_window = c(1, 2))  

# Compute term and document frequencies
tf <- textmineR::TermDocFreq(dtm = dtm)

# Keep terms that occur at least twice but appear in fewer than 25% of documents
vocabulary <- tf$term[tf$term_freq > 1 & tf$doc_freq < nrow(dtm) / 4 ]

# Get sentiment lexicon and exclude its words from our vocabulary
bing_words <- get_sentiments("bing")
valid_terms <- setdiff(vocabulary, bing_words$word)

# Filter the DTM to only include valid terms
dtm_filtered <- dtm[, colnames(dtm) %in% valid_terms]


# ========== K-SELECTION (TESTING NUMBER OF TOPICS) ==========

# Function that fits multiple LDA models for different k values and saves results
sweep_k_seq <- function(dtm,
						k_list       = 1:15,
						iterations   = 100,
						coherence_M  = 5,
						seed         = 1234,
						cache_prefix = "models_i100_") {
	
	# Cache directory to avoid refitting models unnecessarily
	vocab_hash <- digest::digest(colnames(dtm), algo = "sha1")
	cache_dir  <- here("cache", paste0(cache_prefix, vocab_hash))
	if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
	
	models <- list()
	
	# Fit models for each k
	for (k in k_list) {
		f <- file.path(cache_dir, sprintf("k_%03d.rds", k))
		
		if (file.exists(f)) {
			m <- readRDS(f)
		} else {
			set.seed(seed + k)
			m <- textmineR::FitLdaModel(dtm = dtm, k = k, iterations = iterations)
			m$k              <- k
			m$coherence      <- textmineR::CalcProbCoherence(phi = m$phi, dtm = dtm, M = coherence_M)
			m$mean_coherence <- mean(m$coherence)
			saveRDS(m, f)
		}
		models[[as.character(k)]] <- m
	}
	
	# Create summary of coherence scores per k
	coh_tbl <- data.frame(
		k              = vapply(models, function(m) m$k,              integer(1)),
		mean_coherence = vapply(models, function(m) m$mean_coherence, numeric(1)),
		stringsAsFactors = FALSE
	)
	
	# Pick the model with the highest mean coherence
	best_idx   <- which.max(coh_tbl$mean_coherence)
	best_model <- models[[best_idx]]
	
	list(models = models, summary = coh_tbl, best = best_model, cache_dir = cache_dir)
}

# Run LDA sweep to test k values
res <- sweep_k_seq(dtm_filtered, k_list = 1:15, iterations = 100, coherence_M = 5, seed = 1234)


# ========== PICKING BEST K VALUE ==========

# Function to find local maxima in coherence (prevents overfitting)
function_k_scores <- function(coh_table){
	coh_table <- coh_table %>% filter(k > 1)
	
	coh_table <- coh_table %>%
		mutate(
			prev = lag(mean_coherence),
			nxt = lead(mean_coherence),
			is_local_max = mean_coherence > prev & mean_coherence > nxt,
			is_local_max = replace_na(is_local_max, FALSE),
			strength = (mean_coherence - coalesce(prev, mean_coherence)) +
				(mean_coherence - coalesce(nxt, mean_coherence))
		) %>%
		mutate(
			mu = mean(mean_coherence),
			st.d = sd(mean_coherence),
			coh_z = (mean_coherence - mu)/st.d,
			coh_rel = scales::rescale(coh_z, to = c(0,1)),
			pen_strength = strength/sqrt(k),
			score = ifelse(is_local_max, coh_rel*pen_strength, NA_real_)
		)
	return(coh_table)
}

# Apply and extract best-scoring k
k_scores <- function_k_scores(res$summary)
best_k <- k_scores$k[which.max(k_scores$score)] %>% as.numeric()

# View top words for this model
terms_best_k_low_iterations <- GetTopTerms(res$models[[paste0(best_k)]]$phi, M = 15)


# ========== FIT FINAL LDA MODEL ==========

# Fit the LDA again with more iterations and tuned parameters
lda_model <- FitLdaModel(
	dtm              = dtm_filtered,
	k                = best_k,
	iterations       = 2000,        
	burnin           = 500,
	alpha			 = 0.2,  # smaller alpha = fewer topics per doc
	beta             = 0.1,  # lower beta = more distinctive topics
	optimize_alpha   = TRUE,
	calc_likelihood  = TRUE,
	calc_coherence   = TRUE,
	calc_r2          = FALSE,
	cpus             = 1
)

# Average topic coherence before FREX filtering
coherence_pre_frex <- lda_model$coherence %>% mean() * 100


# ========== FREX ADJUSTMENT ==========

# Custom FREX function to improve exclusivity of top terms
CalcFrex <- function(phi, w = 0.5) {
	freq <- phi
	excl <- phi / matrix(colSums(phi), nrow = nrow(phi), ncol = ncol(phi), byrow = TRUE)
	
	frex <- matrix(NA, nrow = nrow(phi), ncol = ncol(phi))
	rownames(frex) <- rownames(phi)
	colnames(frex) <- colnames(phi)
	
	for (k in 1:nrow(phi)) {
		r_freq <- rank(-freq[k, ])
		r_excl <- rank(-excl[k, ])
		frex[k, ] <- 1 / (w / r_excl + (1 - w) / r_freq)
	}
	return(frex)
}

# Calculate FREX scores
frex <- CalcFrex(phi = lda_model$phi, w = 0.5)  

# Compute average FREX per word
avg_frex <- as.data.frame(as.table(as.matrix(frex))) %>%
	rename(topic = Var1, word = Var2, frex = Freq) %>%
	group_by(word) %>%
	summarise(avg_frex = mean(frex, na.rm = TRUE), .groups = "drop") %>%
	arrange(desc(avg_frex))

# Remove 50 lowest-FREX words and refit the model
low_frex_words <- avg_frex %>%
	arrange(avg_frex) %>%
	slice(1:50) %>%
	pull(word)

dtm_frex <- dtm_filtered[, !colnames(dtm_filtered) %in% low_frex_words]

# Refit LDA using FREX-filtered vocabulary
lda_model_frex <- FitLdaModel(
	dtm              = dtm_frex,
	k                = best_k,
	iterations       = 2000,       
	burnin           = 500,       
	alpha			 = 0.2,
	beta             = 0.1,        
	optimize_alpha   = TRUE,
	calc_likelihood  = TRUE,
	calc_coherence   = TRUE,
	calc_r2          = FALSE,
	cpus             = 1
)

# Average coherence after FREX
coherence_post_frex <- lda_model_frex$coherence %>% mean() * 100


# ========== EXPORT MODEL RESULTS ==========

# Save LDA model
saveRDS(lda_model_frex, output_paths$lda_model)

# Save theta (document-topic) and phi (topic-word) matrices
write_csv(lda_model_frex$theta %>% as.data.frame() %>% tibble::rownames_to_column("review_id"), output_paths$theta)
write_csv(lda_model_frex$phi %>% as.data.frame(), output_paths$phi)


# ========== PLOTS & TABLES ==========

# Plot coherence vs number of topics ("elbow" plot)
ggplot(res$summary, aes(x = k, y = mean_coherence)) +
	geom_line() +
	geom_point() +
	scale_x_continuous(breaks = 1:15) +
	scale_y_reverse() +
	labs(
		x = "Number of topics (k)",
		y = "Average topic coherence",
		title = "Coherence vs. Number of Topics"
	) +
	theme_minimal()

ggsave(output_paths$coherence_elbow, width = 7, height = 5, dpi = 300, bg = "white")


# Top terms tables (before and after FREX)
top_terms_pre_frex <- GetTopTerms(phi = lda_model$phi, M = 10) %>% as.data.frame()
top_terms_post_frex <- GetTopTerms(phi = lda_model_frex$phi, M = 10) %>% as.data.frame()

# Format for readability
top_terms_pre_frex_tbl <- top_terms_pre_frex %>%
	tibble::rownames_to_column("Rank") %>%
	rename_with(~ gsub("t_", "Topic ", .x))

gt(top_terms_pre_frex_tbl) %>%
	tab_header(
		title = "Top Terms per Topic (Pre-FREX)",
		subtitle = "Top 10 most representative words before FREX adjustment"
	) %>%
	tab_options(table.font.size = px(14)) %>%
	gtsave(output_paths$top_terms_pre_frex)

top_terms_post_frex_tbl <- top_terms_post_frex %>%
	tibble::rownames_to_column("Rank") %>%
	rename_with(~ gsub("t_", "Topic ", .x))

gt(top_terms_post_frex_tbl) %>%
	tab_header(
		title = "Top Terms per Topic (Post-FREX)",
		subtitle = "Top 10 most representative words after FREX adjustment"
	) %>%
	tab_options(table.font.size = px(14)) %>%
	gtsave(output_paths$top_terms_post_frex)


# ========== COHERENCE TABLE ==========

# Combine coherence values before and after FREX
coherence_df <- data.frame(
	topic = paste0("Topic ", seq_len(length(lda_model$coherence))),
	pre_frex  = lda_model$coherence * 100,
	post_frex = lda_model_frex$coherence * 100
)

# Add average row
coherence_df <- rbind(
	coherence_df,
	data.frame(topic = "Average", pre_frex = coherence_pre_frex, post_frex = coherence_post_frex)
) %>%
	mutate(across(pre_frex:post_frex, ~ round(.x, 2)))

# Save as HTML table
gt(coherence_df, rowname_col = "topic") %>%
	fmt_number(columns = c(pre_frex, post_frex), decimals = 2) %>%
	tab_header(
		title = "Topic Coherence Before and After FREX Filtering",
		subtitle = "Average and per-topic coherence comparison"
	) %>%
	tab_spanner(label = "Average Topic Coherence (%)", columns = c(pre_frex, post_frex)) %>%
	cols_label(pre_frex = "Pre-FREX", post_frex = "Post-FREX") %>%
	tab_style(style = cell_text(weight = "bold"), locations = cells_body(rows = topic == "Average")) %>%
	gtsave(output_paths$coherence_table)


# ========== TOPIC DISTANCE PLOT (2D MAP) ==========

# Compute cosine distance between topics
topic_dist <- proxy::dist(lda_model_frex$phi, method = "cosine")

# Perform MDS for 2D visualization
mds_coords <- cmdscale(topic_dist, k = 2) %>% as.data.frame()
colnames(mds_coords) <- c("x", "y")
mds_coords$topic <- rownames(lda_model_frex$phi)

# Compute topic prevalence to determine the size of the cluster
topic_weights <- colMeans(lda_model_frex$theta)
mds_coords$weight <- topic_weights

# Get top 5 words per topic to visualize in the plot
top_terms <- textmineR::GetTopTerms(lda_model_frex$phi, M = 5)
top_terms_t <- t(top_terms) # Transpose

# Combine into dataframe
top_terms_df <- data.frame(
	topic = rownames(top_terms_t),
	top_words = apply(top_terms_t, 1, function(x) paste(x, collapse = "\n")), # New line between words
	stringsAsFactors = FALSE
)

# Merge MDS coordinates with top words
mds_coords <- dplyr::left_join(mds_coords, top_terms_df, by = "topic")

# Convert topic to factor
mds_coords$topic <- factor(mds_coords$topic, levels = rownames(lda_model_frex$phi))

# Create color palette (distinct color per topic)
topic_palette <- brewer.pal(min(8, nrow(mds_coords)), "Set2")

# Plot
ggplot(mds_coords, aes(x = x, y = y)) +
	geom_point(
		aes(size = weight * 12, fill = topic),
		shape = 21, color = "grey35", alpha = 0.35
	) +
	geom_text(
		aes(label = top_words),
		hjust = 0.5, vjust = 0.5, size = 2.5, color = "black", lineheight = 0.9
	) +
	scale_size_continuous(range = c(20, 45), guide = "none") +
	scale_fill_brewer(
		palette = "Set2",
		name = "Topic",
		labels = function(x) gsub("t_", "", x)
	) +
	guides(
		fill = guide_legend(
			override.aes = list(size = 10, alpha = 0.7, shape = 21, color = "grey30")
		)
	) +   
	scale_x_continuous(limits = c(-0.6, 0.6),
					   breaks = seq(-0.6, 0.6, by = 0.3),
					   expand = expansion(mult = 0.02)) +
	scale_y_continuous(limits = c(-0.6, 0.6),
					   breaks = seq(-0.6, 0.6, by = 0.3),
					   expand = expansion(mult = 0.02)) +
	coord_cartesian(clip = "off"
	) +
	theme_minimal(base_size = 16) +
	labs(
		title = "Topic Distance Map",
		subtitle = "Topics positioned by MDS-scaled cosine distance",
		x = "Dimension 1",
		y = "Dimension 2"
	) +
	theme(
		plot.title = element_text(face = "bold", size = 18),
		plot.subtitle = element_text(size = 13),
		panel.grid = element_line(color = "gray85"),
		legend.position = "right",
		plot.margin = margin(20, 20, 20, 20)
	)

# Save the plot
ggsave(output_paths$lda_vis,
	   width = 7, height = 7, dpi = 300, bg = "white")