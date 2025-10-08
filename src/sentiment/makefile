# -----------------------------------
# Makefile: Sentiment Analysis
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_TRAINING := ../../data/training_data
DATA_DIR_FINAL    := ../../data/final_data

# ----------------------------
# Input Files
# ----------------------------
REVIEWS_MASKED := $(DATA_DIR_TRAINING)/reviews_ner_masked.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := sentiment.R

# ----------------------------
# Output Files
# ----------------------------
SENTIMENT := $(DATA_DIR_FINAL)/sentiment_scores.csv

TARGETS := $(SENTIMENT)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rule
# ----------------------------
$(DATA_DIR_FINAL):
	if not exist $@ mkdir $@

# ----------------------------
# Sentiment Analysis Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEWS_MASKED) | $(DATA_DIR_FINAL)
	@echo "Running VADER sentiment analysis script and saving the results..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	del /Q $(subst /,\,$(TARGETS)) 2>nul || true
