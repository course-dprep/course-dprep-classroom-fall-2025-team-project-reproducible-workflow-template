# -----------------------------------
# Makefile: BERTopic Modeling
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_TRAINING := ../../../data/training_data

# ----------------------------
# Input Files
# ----------------------------
REVIEWS_CLEANED := $(DATA_DIR_TRAINING)/reviews_cleaned_for_bert.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := topic_model_bert.py

# ----------------------------
# Output Files
# ----------------------------
TOPIC_PROBABILITIES := $(DATA_DIR_TRAINING)/bertopic_cluster_probabilities.csv
TOPIC_INFO          := $(DATA_DIR_TRAINING)/bertopic_topic_info.csv

TARGETS := $(TOPIC_PROBABILITIES) $(TOPIC_INFO)

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
# Topic Modeling Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEWS_CLEANED) | $(DATA_DIR_TRAINING)
	@echo "Running BERTopic model..."
	py -3.11 $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Cleaning data..."
	Rscript -e "files <- strsplit('$(TARGETS)', ' ')[[1]]; unlink(files, recursive = TRUE, force = TRUE)"
