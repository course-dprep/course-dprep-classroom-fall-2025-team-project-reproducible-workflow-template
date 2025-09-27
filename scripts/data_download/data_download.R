#check if all dependencies are installed, and install if needed
required_packages <- c("tidyverse", "googledrive", "data.table", "here")

for (pkg in required_packages) {
	if (!requireNamespace(pkg, quietly = TRUE)) {
		suppressMessages(install.packages(pkg))
	}
}
#load all the dependencies
invisible(lapply(required_packages, function(pkg) {
	suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

#3. check if TinyTex is installed
if (!tinytex::is_tinytex()) {
	message("TinyTeX not installed. Please run tinytex::install_tinytex() in the console.")}

# Always ensures data/raw_data/ exists at the project root
if (!dir.exists(here("data", "raw_data"))) {
	dir.create(here("data", "raw_data"), recursive = TRUE)
}

# 5) Datasets + Drive listing
datasets <- c(business="business", checkin="checkin", tip="tip", user="user", review="review")
googledrive::drive_deauth()
folder_id <- "1WHSh8ZQYzQ3IQI8tJX90cYGR4bDy13v3"
drive_folder <- drive_ls(as_id(folder_id))

# 6) Loop: ensure RDS exists; if not, make it (download CSV if needed); never assign to env
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
	saveRDS(dat, rds_path, compress = FALSE)              # consider:  compress = FALSE for speed
	rm(dat); gc()
	message("Done (", round(difftime(Sys.time(), t0, units = "secs"), 1), " sec).")
}
