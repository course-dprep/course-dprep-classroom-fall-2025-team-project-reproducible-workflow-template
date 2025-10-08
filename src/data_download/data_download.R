# ========== SETUP ==========

# Required packages
required_packages <- c("tidyverse", "googledrive", "data.table", "here")

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

# Create raw data folder if it has not been created yet
if (!dir.exists(here("data", "raw_data"))) {
	dir.create(here("data", "raw_data"), recursive = TRUE, showWarnings = FALSE)
}

# Make sure no authentication is required when downloading the raw data
googledrive::drive_deauth()

# === Global parameters ===

	# The raw datasets to download from the drive 
datasets <- c(business="business", checkin="checkin", tip="tip", user="user", review="review")

	# Google drive folder id
folder_id <- "1WHSh8ZQYzQ3IQI8tJX90cYGR4bDy13v3"

# ========== INPUT & OUTPUT ==========

# Discover the Google drive folder
drive_folder <- drive_ls(as_id(folder_id))

# Loop to download raw data and save them as .rds files

# Loop over each raw dataset
# Loop over each dataset
# │
# ├─ 1. Check if RDS exists?
# │   ├─ Yes → Message: "OK, skip this dataset" → Next dataset
# │   └─ No →
# │       ├─ 2. Check if CSV exists?
# │       │   ├─ Yes → Message: "Found CSV"
# │       │   └─ No →
# │       │       ├─ Locate file on Drive
# │       │       ├─ Report download size
# │       │       └─ Download CSV
# │       │
# │       ├─ 3. Read CSV with fread()
# │       ├─ 4. Save as RDS
# │       └─ 5. Cleanup (rm + gc) + timing message
# │
# └─ End loop

for (dataset in datasets) {
	rds_path <- here("data", "raw_data", paste0(dataset, ".rds"))
	csv_path <- here("data", "raw_data", paste0("yelp_academic_dataset_", dataset, ".csv"))
	
	if (file.exists(rds_path)) {
		message("OK: ", rds_path, " already exists. Skipping.")
		next
	}
	
	if (!file.exists(csv_path)) {
		message("CSV missing for ", dataset, ". Downloading from Drive...")
		file <- drive_folder[str_detect(drive_folder$name, dataset), ]
		size_bytes <- as.numeric(file$drive_resource[[1]]$size)
		size_mb <- round(size_bytes / (1024^2), 2)
		message("Download size: ", size_mb, " MB")
		googledrive::drive_download(as_id(file$id), path = csv_path, overwrite = TRUE)
		rm(file)
	} else {
		message("Found CSV: ", csv_path)
	}
	
	message("Reading CSV with fread() → writing RDS: ", rds_path)
	t0 <- Sys.time()
	dat <- data.table::fread(csv_path, showProgress = TRUE)
	saveRDS(dat, rds_path, compress = FALSE)              
	rm(dat); gc()
	message("Done (", round(difftime(Sys.time(), t0, units = "secs"), 1), " sec).")
}