## Define directories
SAMPLING = scripts/sampling
DOWNLOAD = scripts/data_download
TOPIC_MODELLING = scripts/topic_modelling

# Main target of make file: 
all: data/raw_data data/training_data/reviews_sampled.rds

# Step 1: Download raw data
data/raw_data: $(DOWNLOAD)/data_download.R
	Rscript $(DOWNLOAD)/data_download.R

# Step 2: Sampling data
data/training_data/reviews_sampled.rds: $(SAMPLING)/sampling.R
	Rscript $(SAMPLING)/sampling.R

# Step 3: Top modelling
data/training_data/reviews_python_in.csv: $(TOPIC_MODELLING)/data_cleaning_for_bert.r
	Rscript $(TOPIC_MODELLING)/data_cleaning_for_bert.r