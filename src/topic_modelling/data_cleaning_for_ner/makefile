# -----------------------------------
# Makefile: Data Cleaning for NER
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_TRAINING := ../../../data/training_data

# ----------------------------
# Input Files
# ----------------------------
REVIEWS_SAMPLE := $(DATA_DIR_TRAINING)/reviews_sampled.rds

# ----------------------------
# Script
# ----------------------------
SCRIPT := data_cleaning_for_ner.R

# ----------------------------
# Output Files
# ----------------------------
REVIEWS_CLEANED_NER := $(DATA_DIR_TRAINING)/reviews_cleaned_for_ner.csv

TARGETS := $(REVIEWS_CLEANED_NER)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rule
# ----------------------------
$(DATA_DIR_TRAINING):
	Rscript -e "if (!dir.exists('$(DATA_DIR_TRAINING)')) dir.create('$(DATA_DIR_TRAINING)', recursive = TRUE)"

# ----------------------------
# Cleaning Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEWS_SAMPLE) | $(DATA_DIR_TRAINING)
	@echo "Cleaning reviews specifically for NER masking..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting data..."
	Rscript -e "files <- strsplit('$(TARGETS)', ' ')[[1]]; unlink(files, recursive = TRUE, force = TRUE)"
