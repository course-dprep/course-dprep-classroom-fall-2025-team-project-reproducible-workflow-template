## define directories
SAMPLING = scripts/sampling
DOWNLOAD = scripts/data_download

# main target of make file: 
all: data/raw_data data/training_data/reviews_sampled.rds

# Step 1: Download raw data
data/raw_data: $(DOWNLOAD)/data_download.R
	Rscript $(DOWNLOAD)/data_download.R

# Sampling Data
data/training_data/reviews_sampled.rds: $(SAMPLING)/sampling.R
	Rscript $(SAMPLING)/sampling.R

# 