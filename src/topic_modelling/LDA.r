# ========== SETUP ==========

# Required packages
required_packages <- c("tidyverse","here","data.table","googledrive",
					   "tidytext","textmineR","digest","reshape2",
					   "wordcloud","RColorBrewer", "quanteda", "scales", "gt", "proxy", "RColorBrewer")

# Loading packages 
for (pkg in required_packages) {
	if (requireNamespace(pkg, quietly = TRUE)) {
		suppressWarnings(
			suppressPackageStartupMessages(
				library(pkg, character.only = TRUE)
			)
		)
	} else {
		message(sprintf(
			"Package '%s' is not installed. Make sure to first install all the required packages for this project by running dependencies/install_packages.R",
			pkg
		))
	}
}

# === Global parameters ===

# Relative paths of the input files
input_paths <- list(
	reviews_ner_masked = here("data", "training_data", "reviews_ner_masked.csv"),
	reviews_sampled = here("data", "training_data", "reviews_sampled.rds")
)

# Relative paths of the output files
output_paths <- list(
	theta = here("data", "final_data", "theta.csv"),
	phi = here("data", "final_data", "phi.csv"),
	coherence_table = here("gen","tables", "coherence_table.html"),
	coherence_elbow = here("gen", "figures", "coherence_elbow_plot.pdf"),
	lda_vis = here("gen", "figures", "lda_vis.pdf"),
	top_terms_pre_frex = here("gen", "tables", "top_terms_pre_frex.html"),
	top_terms_post_frex = here("gen", "tables", "top_terms_post_frex.html"),
	lda_model = here("data", "final_data", "lda_model.rds")
)

# Setting seed for reproducibility
set.seed(999)

# ========== INPUT ==========

# Load masked reviews into environment
reviews <- read.csv(input_paths$reviews_ner_masked)

# Ensuring tibble format of the data
reviews <- tibble::as_tibble(reviews)

# Extracting the columns needed for LDA
data <- reviews %>% transmute(text = masked_for_lda, id = review_id)

# Load sampled reviews into environment
reviews_sampled <- readRDS(here("data", "training_data", "reviews_sampled.rds"))

# ========== TRANSFORMATION ==========

# Informing the placeholder format
PLACE <- "(?i)_(?:FOOD|RESTAURANT|LOCATION)_" 

# Removing the NER placeholders from review text
data <- data %>%
	dplyr::mutate(
		n_placeholders = str_count(text, PLACE),
		text = str_squish(str_replace_all(text, PLACE, " "))
	)

# Tokenizing the reviews
tokens <- data %>%
	tidytext::unnest_tokens(word, text, strip_punct = TRUE) %>%   
	filter(!(word %in% quanteda::stopwords("en"))) %>%	# Remove stopwords
	filter(nchar(word) > 1) %>%							# Remove 1 character words
	mutate(word = tolower(word)) %>%					# Lowercase the words
	mutate(word = gsub("[[:digit:]]+", " ", word)) %>%	# Remove digits
	mutate(word = str_squish(word)) %>%					# Remove whitespaces
	filter(word != "")									# Filter empty tokens out
	
	
# Convert back to character strings for textmineR 
data_cleaned <- tokens %>%
	group_by(id) %>%
	summarise(text = paste(word, collapse = " "), .groups = "drop")

# Build document-term matrix
dtm <- textmineR::CreateDtm(data_cleaned$text,
                            doc_names    = data_cleaned$id,
                            ngram_window = c(1, 2))  

# Build term-doc frequency 
tf <- textmineR::TermDocFreq(dtm = dtm)

# Build vocabulary for LDA: 
	#term_freq > 1 & doc_freq <  docs / 4
	# docs / 4: ignore words that occur in over 25% of the reviews
vocabulary <- tf$term[tf$term_freq > 1 & tf$doc_freq < nrow(dtm) / 4 ]

# Get bing lexicon
bing_words <- get_sentiments("bing")

# Words in your vocabulary but NOT in bing
valid_terms <- setdiff(vocabulary, bing_words$word)

# Create filtered dtm
dtm_filtered <- dtm[, colnames(dtm) %in% valid_terms]

# LDA k-selection 
sweep_k_seq <- function(dtm,
						k_list       = 1:15,
						iterations   = 100,
						coherence_M  = 5,
						seed         = 1234,
						cache_prefix = "models_i100_") {
	
	# Store results in a cache directory based on vocab hash
	vocab_hash <- digest::digest(colnames(dtm), algo = "sha1")
	cache_dir  <- here("cache", paste0(cache_prefix, vocab_hash))
	if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
	
	models <- list()
	
	# Loop across candidate K values
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
	
	# Run function with low iterations
	
	
	# Summarize coherence per K
	coh_tbl <- data.frame(
		k              = vapply(models, function(m) m$k,              integer(1)),
		mean_coherence = vapply(models, function(m) m$mean_coherence, numeric(1)),
		stringsAsFactors = FALSE
	)
	
	best_idx   <- which.max(coh_tbl$mean_coherence)
	best_model <- models[[best_idx]]
	
	list(
		models    = models,
		summary   = coh_tbl,
		best      = best_model,
		cache_dir = cache_dir
	)
}

# Run the coherence function
res <- sweep_k_seq(dtm_filtered, k_list = 1:15, iterations = 100, coherence_M = 5, seed = 1234)

# Determine best K, accounting for local maximums
function_k_scores <- function(coh_table){
	coh_table <- coh_table %>% filter(k > 1)  # Ignore k=1
	
	# Find local maxima
	coh_table <- coh_table %>%
		mutate(
			prev = lag(mean_coherence),
			nxt = lead(mean_coherence),
			is_local_max = mean_coherence > prev & mean_coherence > nxt,
			is_local_max = replace_na(is_local_max, FALSE),
			strength = (mean_coherence - coalesce(prev, mean_coherence)) +
				(mean_coherence - coalesce(nxt, mean_coherence))
		)%>% mutate(
			mu = mean(mean_coherence),
			st.d = sd(mean_coherence)
		)%>% mutate(
			coh_z = (mean_coherence - mu)/st.d
		)%>% mutate(
			coh_rel = scales::rescale(coh_z, to = c(0,1)),
			pen_strength = strength/sqrt(k)
		)%>% mutate(
			score = ifelse(is_local_max, coh_rel*pen_strength, NA_real_)
		)
		
	
	
	return(coh_table)
}

# Compute the coherence scores
k_scores <- function_k_scores(res$summary)

# Store the best K value
best_k <- k_scores$k[which.max(k_scores$score)]%>%as.numeric()

# Get the top terms from the best k
terms_best_k_low_iterations <- GetTopTerms(res$models[[paste0(best_k)]]$phi, M = 15)

## Plot code ###
#to be added
	
# Fit LDA for best k with more iterations
lda_model <- FitLdaModel(
	dtm              = dtm_filtered,
	k                = best_k,
	iterations       = 2000,        
	burnin           = 500,
	alpha			 = 0.2,		# Less topics per review
	beta             = 0.1, 	# Low beta to force more distinctive words    
	optimize_alpha   = TRUE,
	calc_likelihood  = TRUE,
	calc_coherence   = TRUE,
	calc_r2          = FALSE,
	cpus             = 1#max(1, parallel::detectCores() - 1)
)

# Average topic coherence of the LDA model
coherence_pre_frex <- lda_model$coherence%>%mean()*100

#Topic coherence per topic
coherence_per_topic_pre_frex <- lda_model$coherence%>%as.data.frame()

# Top terms per topic
top_terms_pre_frex <- GetTopTerms(phi = lda_model$phi, M = 10) %>%as.data.frame()

# Function to calculate Frequency Exclusivity scores (FREX)
CalcFrex <- function(phi, w = 0.5) {
	# phi = topic-term matrix (topics x words)
	freq <- phi
	excl <- phi / matrix(colSums(phi), nrow = nrow(phi), ncol = ncol(phi), byrow = TRUE)
	
	frex <- matrix(NA, nrow = nrow(phi), ncol = ncol(phi))
	rownames(frex) <- rownames(phi)
	colnames(frex) <- colnames(phi)
	
	for (k in 1:nrow(phi)) {
		# Rank frequencies & exclusivities for topic k
		r_freq <- rank(-freq[k, ])       # higher prob = lower rank number
		r_excl <- rank(-excl[k, ])
		
		frex[k, ] <- 1 / (w / r_excl + (1 - w) / r_freq)
	}
	
	return(frex)
}

# Run the FREX function
frex <- CalcFrex(phi = lda_model$phi, w = 0.5)  

# Store the FREX scores in a dataframe
frex_df <- as.data.frame(as.table(as.matrix(frex)))
colnames(frex_df) <- c("topic", "word", "frex")

# Compute the average FREX score per word instead of per every (Topic x Word) combination
avg_frex <- frex_df %>%
	group_by(word) %>%
	summarise(avg_frex = mean(frex, na.rm = TRUE), .groups = "drop") %>%
	arrange(desc(avg_frex))

# Select the words with lowest Frequency-Exclusivity
low_frex_words <- avg_frex %>%
	arrange(avg_frex) %>%
	slice(1:50) %>%
	pull(word) %>% as.vector()

# Create a filtered dtm that excludes low frex words
dtm_frex <- dtm_filtered[, !colnames(dtm_filtered) %in% low_frex_words]
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
	cpus             = 1#max(1, parallel::detectCores() - 1)
)

# Average topic coherence after FREX adjustments
coherence_post_frex <- lda_model_frex$coherence%>%mean()*100

# Top terms per topic after FREX adjustments
top_terms_post_frex <- GetTopTerms(phi = lda_model_frex$phi, M = 10) %>%as.data.frame()

# Coherence per topic after FREX adjustments
coherence_per_topic_post_frex <- lda_model_frex$coherence%>%as.data.frame() 

# Create theta dataframe ready for exportation
theta_df <- lda_model_frex$theta %>% as.data.frame() %>%
	tibble::rownames_to_column("review_id")

# Create phi dataframe ready for exportation
phi_df <- lda_model_frex$phi %>% as.data.frame()

# Create dataframe with the coherence statistics of both the LDA models
coherence_df <- data.frame(
	topic = paste0("Topic ", seq_len(length(lda_model$coherence))),
	pre_frex  = lda_model$coherence*100,
	post_frex = lda_model_frex$coherence*100
)

# Average coherence data
coherence_avg <- data.frame(
	topic = "Average",
	pre_frex = coherence_pre_frex,
	post_frex = coherence_post_frex
)

# Combine the coherence dataframes
coherence_df <- rbind(coherence_df, coherence_avg)%>%
	mutate(across(pre_frex:post_frex, ~round(.x,2)))

# ========== OUTPUT ==========

# Save the LDA model for model validation phase
saveRDS(lda_model_frex, output_paths$lda_model)
# Save theta results as .csv
write_csv(theta_df, file = output_paths$theta)

#Save phi results as .csv 
write_csv(phi_df, file = output_paths$phi)

# "Elbow-plot" for mean coherence
ggplot(res$summary, aes(x = k, y = mean_coherence)) +
	geom_line()			+
	geom_point()		+
	scale_x_continuous(breaks = 1:15) +
	scale_y_reverse()	+
	labs(
		x = "Number of topics (k)",
		y = "Average topic coherence",
		title = "Coherence vs. Number of Topics"
	)					+
	theme_minimal()

ggsave(output_paths$coherence_elbow,
	   width = 7, height = 5, dpi = 300, bg = "white")


# Create publication ready pre-frex, top terms per topic table
top_terms_pre_frex <- GetTopTerms(phi = lda_model$phi, M = 10) %>%as.data.frame()

# Convert to dataframe with readable topic names
top_terms_pre_frex_tbl <- top_terms_pre_frex %>%
	as.data.frame() %>%
	tibble::rownames_to_column("Rank") %>%
	rename_with(~ gsub("t_", "Topic ", .x))

gt_top_terms_pre_frex <- top_terms_pre_frex_tbl %>%
	gt() %>%
	tab_header(
		title = "Top Terms per Topic (Pre-FREX)",
		subtitle = "Top 10 most representative words per topic before FREX adjustment"
	) %>%
	fmt_markdown(columns = everything()) %>%
	tab_options(
		table.font.size = px(14),
		table.width = pct(100),
		data_row.padding = px(4),
		heading.title.font.weight = "bold"
	)%>%gtsave(., output_paths$top_terms_pre_frex) # Save as HTML

# Create publication ready post-frex, top terms per topic table
top_terms_post_frex <- GetTopTerms(phi = lda_model_frex$phi, M = 10) %>%as.data.frame()

# Convert to dataframe with readable topic names
top_terms_post_frex_tbl <- top_terms_post_frex %>%
	as.data.frame() %>%
	tibble::rownames_to_column("Rank") %>%
	rename_with(~ gsub("t_", "Topic ", .x))

gt_top_terms_post_frex <- top_terms_post_frex_tbl %>%
	gt() %>%
	tab_header(
		title = "Top Terms per Topic (Post-FREX)",
		subtitle = "Top 10 most representative words per topic after FREX adjustment"
	) %>%
	fmt_markdown(columns = everything()) %>%
	tab_options(
		table.font.size = px(14),
		table.width = pct(100),
		data_row.padding = px(4),
		heading.title.font.weight = "bold"
	)%>%gtsave(., output_paths$top_terms_post_frex)

# Create publication ready coherence table 
coherence_df %>%
	gt(rowname_col = "topic") %>%
	fmt_number(columns = c(pre_frex, post_frex), decimals = 2) %>%
	tab_header(
		title = "Topic Coherence Before and After FREX Filtering",
		subtitle = "Average and per-topic coherence comparison"
	) %>%
	tab_spanner(
		label = "Average Topic Coherence (%)",
		columns = c(pre_frex, post_frex)
	) %>%
	cols_label(
		pre_frex  = "Pre-FREX",
		post_frex = "Post-FREX"
	) %>%
	tab_style(
		style = cell_text(weight = "bold"),
		locations = cells_body(rows = topic == "Average")
	) %>%
	opt_table_outline() %>%
	opt_align_table_header("center")%>%
	gtsave(., output_paths$coherence_table)

# === PLOT code: Visualize distances between the LDA topics ===

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
