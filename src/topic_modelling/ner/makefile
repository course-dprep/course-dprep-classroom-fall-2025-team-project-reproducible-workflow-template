# -----------------------------------
# Makefile: Named Entity Masking (NER)
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_TRAINING := ../../../data/training_data

# ----------------------------
# Input Files
# ----------------------------
REVIEWS_CLEANED_NER := $(DATA_DIR_TRAINING)/reviews_cleaned_for_ner.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := ner.py

# ----------------------------
# Output Files
# ----------------------------
REVIEWS_MASKED := $(DATA_DIR_TRAINING)/reviews_ner_masked.csv

TARGETS := $(REVIEWS_MASKED)

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
# Masking Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEWS_CLEANED_NER) | $(DATA_DIR_TRAINING)
	@echo "Running NER script to mask named and food entities in reviews..."
	py -3.11 $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting masked reviews..."
	Rscript -e "files <- strsplit('$(TARGETS)', ' ')[[1]]; unlink(files, recursive = TRUE, force = TRUE)"
