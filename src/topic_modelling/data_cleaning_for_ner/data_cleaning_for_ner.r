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
		library(cld3)
	})
})

# === Global parameters ===

# Relative paths of the input files
input_paths <- list(
	reviews_sampled = here("data", "training_data", "reviews_sampled.rds")
)

# Relative paths of the output files
output_paths <- list(
	reviews_cleaned_for_ner = here("data", "training_data", "reviews_cleaned_for_ner.csv")
)

# ========== INPUT ==========

#load data into environment
reviews_sampled <- readRDS(input_paths$reviews_sampled)

#Keep only the review_id and actual review
reviews_sampled <- reviews_sampled %>% select(text,review_id)

# ========== TRANSFORMATION ==========

# Data filtering: English reviews only
reviews_sampled <- reviews_sampled %>%
	mutate(language = cld3::detect_language(text))%>%
	filter(language == "en")

 #Cleaning function to prepare data for NER
clean_for_ner <- function(x) {
	x |>
		str_replace_all("<[^>]+>", "") |>						# Remove HTML tags	
		str_replace_all("https?://\\S+|www\\.\\S+", " ") |> 	# Remove URLs 
		str_replace_all("[0-9]+", " ") |>                   	# Remove numbers
		str_replace_all("[[:punct:]&&[^']]+", " ") |>       	# Remove punctuation but keep apostrophes
		str_replace_all("\\s+", " ") |>                     	# Collapse multiple spaces into a single space
		str_trim()                                          	# Trim leading and trailing spaces
}

# Using the cleaning function on the review text column
reviews_sampled <- reviews_sampled %>%
	mutate(text_clean_ner = clean_for_ner(text))

# ========== OUTPUT ==========

# Saving the cleaned reviews as .csv
reviews_sampled %>%
	select(review_id, text_clean_ner) %>%
	readr::write_csv(output_paths$reviews_cleaned_for_ner)