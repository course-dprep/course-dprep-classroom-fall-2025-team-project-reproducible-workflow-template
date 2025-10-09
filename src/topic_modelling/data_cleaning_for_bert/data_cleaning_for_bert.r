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
	reviews_sampled = here("data", "training_data", "reviews_sampled.rds"),
	business = here("data", "raw_data", "business.rds")
)

# Relative paths of the output files
output_paths <- list(
	reviews_cleaned_for_bert = here("data", "training_data", "reviews_cleaned_for_bert.csv")
)

# ========== INPUT ==========

# Load the sampled reviews .rds file
reviews_sampled <- readRDS(input_paths$reviews_sampled)

# Load the business information .rds file
business <- readRDS(input_paths$business)

# ========== TRANSFORMATION ==========

# Removing links and html tags from the reviews
reviews_sampled$text <- reviews_sampled$text %>%
	str_replace_all("<[^>]+>", "") %>%
	str_replace_all("(?i)\\b(?:https?://|www\\.)\\S+", "")
	
# Data filtering: English only and minimal length of 30 characters
reviews_sampled <- reviews_sampled %>%
	mutate(language = cld3::detect_language(text))%>%
	filter(language == "en")%>%							# Detect a review's language and keep "en"-only
	mutate(length = str_length(text))%>%
	filter(length >= 30)								# Keep only reviews that are at least 30 characters

# Data join:
reviews_sampled <- reviews_sampled %>%
	left_join(business %>% select(business_id, name, city),
			  by = "business_id")		# Joining $name and $city column from business dataset

# Function to strip restaurant and city names from the reviews, to prevent them from impacting the BERT-clusters

regex_escape <- function(x) {
	# Helper: escape special regex characters in strings
	str_replace_all(x, "([\\^$.|?*+()\\[\\]{}\\\\])", "\\\\\\1")
}

reviews_sampled <- reviews_sampled %>%
	mutate(
		# Tokenize names/cities, lowercase, drop 1-char tokens
		name_tokens = str_split(str_to_lower(coalesce(name, "")), "\\W+") %>%
			map(~ .x[nchar(.x) >= 2]),
		city_tokens = str_split(str_to_lower(coalesce(city, "")), "\\W+") %>%
			map(~ .x[nchar(.x) >= 2]),
		
		# Build regex patterns (case-insensitive so it can be used for $text_label and $text_bert)
		name_pat = map_chr(name_tokens, function(tok) {
			if (length(tok) > 0) {
				paste0("(?i)\\b(", paste(regex_escape(tok), collapse = "|"), ")\\b")
			} else {
				""
			}
		}),
		city_pat = map_chr(city_tokens, function(tok) {
			if (length(tok) > 0) {
				paste0("(?i)\\b(", paste(regex_escape(tok), collapse = "|"), ")\\b")
			} else {
				""
			}
		})
	) %>%
	mutate(
		# $text_label: lowercased, stripped, no names/cities
		text_label = str_to_lower(text) %>%
			str_replace_all("[[:punct:]]+", " "),
		text_label = ifelse(name_pat != "", str_remove_all(text_label, name_pat), text_label),
		text_label = ifelse(city_pat != "", str_remove_all(text_label, city_pat), text_label),
		text_label = str_squish(text_label),
		
		# $text_bert: keeps punctuation/capital letters, replace names/cities with placeholders
		text_bert = ifelse(name_pat != "", str_replace_all(text, name_pat, "[RESTAURANT]"), text),
		text_bert = ifelse(city_pat != "", str_replace_all(text_bert, city_pat, "[CITY]"), text_bert)
	) %>%
	select(-name_tokens, -city_tokens, -name_pat, -city_pat) # Removing the temporary variables

# ========== OUTPUT ==========

# Write .csv file that will be used for BERTopic
write_csv(reviews_sampled %>% 
		  	select(review_id, business_id, text, text_label, text_bert),
		  output_paths$reviews_cleaned_for_bert
)
