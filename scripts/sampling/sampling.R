# ========== SETUP ==========

# Loading packages
required_packages <- c("tidyverse", "data.table", "here")

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

# == Global parameters ==

#Setting seed for reproducability
set.seed(2310)  

# Date cutoff to ensure recency of the reviews when the sampling
date_cutoff <- "2018-01-01"

# ========== INPUT ==========

#Loading data into environment
review <- readRDS(here("data", "raw_data","review.rds"))
business <- readRDS(here("data", "raw_data","business.rds"))
checkin <- readRDS(here("data", "raw_data", "checkin.rds"))

# ========== TRANSFORMATION ==========

# Making the datasets data.tables as it is faster
setDT(review)
setDT(business)
setDT(checkin)

# Create a vector with all all & only restaurant business id's in it
restaurant_ids <- business %>%
	filter(grepl("Restaurants", categories)) %>%
	pull(business_id)

setindex(review, business_id) #speeds up the data filtering in the next step

# Create data.table with only reviews on restaurants
review_restaurants <- review[.(restaurant_ids), on = "business_id", nomatch = 0L]

# Create a data.table with restaurant information: no. of reviews and open/closed status
restaurant_info <- review_restaurants[, .(n_reviews = .N), by = business_id][
	business[, .(business_id, is_open)], on = "business_id", nomatch = 0L]

# Create new variable that holds the last recorded timestamp of a checkin
checkin[,last_checkin := as.IDate(fifelse(is.na(date),NA_character_, str_sub(date, -19,-10)))]

# Change the format of $date to Idate (YYYY - MM - DD) 
review_restaurants[, date := as.IDate(date)]

# Sample eligible business id's:

	# Restaurants only
	# 200 business_id's in total
	# 50/50 split between open/closed restaurants
	# At least 50 reviews between date cutoff and last registered checkin timestamp

sampled_ids <- review_restaurants[
	checkin[, .(business_id, last_checkin)], 
	on = "business_id", 
	last_checkin := i.last_checkin			# Join last_checkin column into the dataframe by business_id
][
	date >= as.IDate(date_cutoff) & 
		!is.na(last_checkin) & 
		date <= last_checkin,   			# Compute no. of reviews between cutoff date and last checkin stamp
	.N, by = business_id
][
	N >= 50                     			# Select only restaurants with 50 or more reviews in that period
][
	business[, .(business_id, is_open)], on = "business_id", nomatch = 0L
][
	, .SD[sample(.N, 100)], by = is_open	# Sample exactly 100 id's per is_open condition
][
	, business_id							# Pull the sampled business id's
]

# Sampling 25 reviews per sampled business_id
reviews_sampled <- review_restaurants[
	business_id %in% sampled_ids												# Filter only eligible sampled id's				
][
	date >= as.IDate(date_cutoff) & !is.na(last_checkin) & date <= last_checkin	# Keeping only eligible reviews
][
	, .SD[sample(.N, 25, replace = .N < 25)], by = business_id              	# Sample per business id
]

# ========== OUTPUT ==========

# Create root/data/training_data directory if it has not been created yet
dir.create(here("data", "training_data"), recursive = TRUE, showWarnings = FALSE)

# Store the sampled reviews as .rds file
saveRDS(reviews_sampled, here("data","training_data","reviews_sampled.rds"))
local_path <- here("data","training_data","reviews_sampled.rds")	#local path where file is stored

# Output message
message(paste0("Stored the sampled reviews as a .rds file in the following directory: ",local_path))




