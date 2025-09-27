## define directories


# main target of make file: 
einde: data/training_data/reviews_sampled.rds

# Step 1: Download raw data
data/raw_data: scripts/data_download/data_download.R
	Rscript scripts/data_download/datadownload.R

# Sampling Data
data/training_data/reviews_sampled.rds: scripts/sampling/sampling.R
	Rscript scripts/sampling/sampling.R

# 