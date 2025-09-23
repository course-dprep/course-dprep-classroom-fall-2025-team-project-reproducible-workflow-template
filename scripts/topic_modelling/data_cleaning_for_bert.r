required_packages <- c("tidyverse", "data.table", "here", "googledrive", "cld3")

for (pkg in required_packages) {
	if (!requireNamespace(pkg, quietly = TRUE)) {
		suppressMessages(install.packages(pkg))
	}
}
#load all the dependencies
invisible(lapply(required_packages, function(pkg) {
	suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

folder_id <- "1oRNbZpA4kXZRsvcNe5K1FRYFKqqT5W2h"	#folder id
googledrive::drive_deauth()
folder <- drive_ls(as_id(folder_id))
filename <- "reviews_sampled.rds"
file_id <- folder[folder$name==filename,] %>% pull(id) %>% as.character()
drive_download(as_id(file_id), path = here("data", "training_data",filename), overwrite = TRUE)

reviews_sampled <- readRDS(here("data", "training_data", filename))

business <- readRDS(here("data","raw_data","business.rds")) #get business datatable in environment
reviews_sampled[business, is_open := i.is_open, on = "business_id"] #extract is_open variable
reviews_sampled %>% pull(is_open) %>% table() #indeed a 50/50 split

#detect review's language and filter
reviews_sampled$language <- cld3::detect_language(reviews_sampled$text)
reviews_sampled %>% pull(language) %>% table()
reviews_sampled <- reviews_sampled %>% filter(language == "en")

#remove reviews that are too short for BERT
reviews_sampled$length <- str_length(reviews_sampled$text)
reviews_sampled <- reviews_sampled %>% filter(length >= 30)

# Detect HTML tags
stringr::str_detect(reviews_sampled$text, "<[^>]+>") %>% table()

#remove links
reviews_sampled$text <- str_replace_all(
	reviews_sampled$text,
	"(?i)\\b(?:https?://|www\\.)\\S+",
	"")

#strip city and restaurants names
reviews_sampled[business, name := i.name, on = "business_id"]
reviews_sampled[business, city := i.city, on = "business_id"]

regex_escape <- function(x) {
	str_replace_all(x, "([\\^$.|?*+()\\[\\]{}\\\\])", "\\\\\\1")
}

reviews_sampled <- reviews_sampled %>%
	mutate(
		# tokenize names/cities, lowercase, drop 1-char tokens
		name_tokens = str_split(str_to_lower(coalesce(name, "")), "\\W+") %>%
			map(~ .x[nchar(.x) >= 2]),
		city_tokens = str_split(str_to_lower(coalesce(city, "")), "\\W+") %>%
			map(~ .x[nchar(.x) >= 2]),
		
		# build regex patterns ("" if no tokens)
		name_pat = map_chr(name_tokens, function(tok) {
			if (length(tok) > 0) {
				paste0("\\b(", paste(regex_escape(tok), collapse = "|"), ")\\b")
			} else {
				""
			}
		}),
		city_pat = map_chr(city_tokens, function(tok) {
			if (length(tok) > 0) {
				paste0("\\b(", paste(regex_escape(tok), collapse = "|"), ")\\b")
			} else {
				""
			}
		})
	) %>%
	mutate(
		# remove punctuation 
		text_label = str_to_lower(text) %>%
			str_replace_all("[[:punct:]]+", " "),
		
		# remove name & city tokens if patterns are not empty
		text_label = ifelse(name_pat != "", str_remove_all(text_label, name_pat), text_label),
		text_label = ifelse(city_pat != "", str_remove_all(text_label, city_pat), text_label),
		
		text_label = str_squish(text_label)
	) %>%
	select(-name_tokens, -city_tokens, -name_pat, -city_pat)

#write csv 
write_csv(reviews_sampled %>% 
		  	select(review_id, business_id, is_open, text, text_label),
		  here("data", "training_data", "reviews_python_in.csv")
)

#write csv 
write_csv(reviews_sampled %>% 
		  	select(text)%>%slice_sample(n = 500),
		  here("data", "training_data", "reviews_text.csv")
)