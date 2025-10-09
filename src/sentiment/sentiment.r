# ========== SETUP ==========

# Activate renv environment
setwd("..")
source("renv/activate.R")

# Loading required packages
suppressPackageStartupMessages({
	suppressWarnings({
		library(tidyverse)
		library(data.table)
		library(here)
		library(vader)
	})
})

# === Global parameters ===

# Relative paths of the input files
input_paths <- list(
	reviews_ner_masked = here("data", "training_data", "reviews_ner_masked.csv")
)

# Relative paths of the output files
output_paths <- list(
	sentiment_scores = here("data", "final_data", "sentiment_scores.csv")
)

# ========== INPUT ==========

# Load the review data with the right amount of cleaning
reviews <- read_csv(input_paths$reviews_ner_masked)

# Select the right columns
reviews <- reviews%>%
	select(review_id, text_clean_ner)%>%
	transmute(text = text_clean_ner, review_id = review_id)

# ========== TRANSFORMATION ==========

# Run sentiment analysis on the review text
vader_results <- vader_df(reviews$text)

# Add review id to sentiment results data
vader_results$review_id <- reviews$review_id

# ========== OUTPUT ==========

# Writing a csv with the sentiment analysis results
write_csv(vader_results, output_paths$sentiment_scores)