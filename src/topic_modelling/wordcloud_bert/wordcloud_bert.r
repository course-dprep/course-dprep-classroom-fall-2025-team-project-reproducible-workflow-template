# ========== SETUP ==========

# Activate renv environment
setwd("../..")
source("renv/activate.R")

# Loading required packages
suppressPackageStartupMessages({
	suppressWarnings({
		library(tidyverse)
		library(data.table)
		library(here)
		library(wordcloud)
		library(RColorBrewer)
	})
})

# === Global parameters ===

# Set seed for reproducibility
set.seed(123)  

# Relative paths of the input files
input_paths <- list(
	bertopic_topic_info = here("data", "training_data", "bertopic_topic_info.csv")
)

# Relative paths of the output files
output_paths <- list(
	wordcloud_bert = here("gen", "figures", "wordcloud_bert.pdf")
)

# Output directories to be created
out_dir <- here::here("gen", "figures")

# ========== INPUT ==========

# Load BERTopic Topic Information
bertopic_topic_info <- readr::read_csv(input_paths$bertopic_topic_info, show_col_types = FALSE)

# ========== TRANSFORMATION ==========

# Select the needed columns
BERTopic_viz <- dplyr::select(bertopic_topic_info, Topic, Representation)

# Collapse the data
BERTopic_words <- BERTopic_viz %>%
	tidyr::separate_rows(Representation, sep = "\\s+") %>%
	dplyr::mutate(
		Representation = gsub("[^a-zA-Z0-9]", "", Representation),
		Representation = tolower(Representation)
	) %>%
	dplyr::filter(Representation != "") %>%
	dplyr::count(Topic, Representation, sort = TRUE)

# Define color palette
pal <- RColorBrewer::brewer.pal(8, "Dark2")

# Get list of unique topics (sorted for stable ordering)
topics <- sort(unique(BERTopic_words$Topic))

# Calculate layout of the pdf
n_topics <- length(topics)
n_cols   <- ceiling(sqrt(n_topics * 0.8))        # Slightly fewer columns to give more vertical space
n_rows   <- ceiling(n_topics / n_cols)

# ========== OUTPUT ==========

# Create output directory (create parent folders too)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# One tall page with all topics
pdf(output_paths$wordcloud_bert, width = 8.5, height = 12)  # Portrait format
par(mfrow = c(n_rows, n_cols), mar = c(1, 1, 4, 1))

for (t in topics) {
	topic_words <- dplyr::filter(BERTopic_words, Topic == t)
	
	wordcloud::wordcloud(
		words        = topic_words$Representation,
		freq         = topic_words$n,
		min.freq     = 1,
		max.words    = 30,           
		random.order = FALSE,
		scale        = c(3.5, 0.7),  
		colors       = pal
	)
	
	title(main = paste("Topic", t), cex.main = 1.2)
}
dev.off()
message("Saved: ", as.character(output_paths$wordcloud_bert))
