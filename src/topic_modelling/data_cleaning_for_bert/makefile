# -----------------------------------
# Makefile: Data Cleaning for BERTopic
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_RAW      := ../../../data/raw_data
DATA_DIR_TRAINING := ../../../data/training_data

# ----------------------------
# Input Files
# ----------------------------
REVIEWS_SAMPLE := $(DATA_DIR_TRAINING)/reviews_sampled.rds
BUSINESS_RAW   := $(DATA_DIR_RAW)/business.rds

# ----------------------------
# Script
# ----------------------------
SCRIPT := data_cleaning_for_bert.R

# ----------------------------
# Output Files
# ----------------------------
REVIEWS_CLEANED := $(DATA_DIR_TRAINING)/reviews_cleaned_for_bert.csv

TARGETS := $(REVIEWS_CLEANED)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rule
# ----------------------------
$(DATA_DIR_TRAINING):
	if not exist $@ mkdir $@

# ----------------------------
# Cleaning Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEWS_SAMPLE) $(BUSINESS_RAW) | $(DATA_DIR_TRAINING)
	@echo "Cleaning data for BERTopic clustering..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	del /Q $(subst /,\,$(TARGETS)) 2>nul || true
