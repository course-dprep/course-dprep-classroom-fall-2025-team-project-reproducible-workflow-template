# -----------------------------------
# Makefile: Analysis
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_TRAINING := ../../data/training_data
DATA_DIR_FINAL    := ../../data/final_data
DATA_DIR_RAW := ../../data/raw_data
GEN_DIR_TABLES := ../../gen/tables

# ----------------------------
# Input Files
# ----------------------------
REVIEWS := $(DATA_DIR_TRAINING)/reviews_sampled.rds
BUSINESS_RAW := $(DATA_DIR_RAW)/business.rds
SENTIMENT := $(DATA_DIR_FINAL)/sentiment_scores.csv
THETA := $(DATA_DIR_FINAL)/theta.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := analysis.R

# ----------------------------
# Output Files
# ----------------------------
SENT_PER_TOPIC := $(GEN_DIR_TABLES)/avg_sentiment_per_dominant_topic.html
LOGISTIC_REGRESSION := $(GEN_DIR_TABLES)/logistic_regression.html
TOPIC_ON_SENTIMENT := $(GEN_DIR_TABLES)/topic_on_sentiment.html
MODEL_PERFORMANCE := $(GEN_DIR_TABLES)/model_performance_statistics.html
LOGISTIC_MODEL := $(DATA_DIR_FINAL)/logistic_model.rds

TARGETS := \
	$(SENT_PER_TOPIC) \
	$(LOGISTIC_REGRESSION) \
	$(TOPIC_ON_SENTIMENT) \
	$(MODEL_PERFORMANCE) \
	$(LOGISTIC_MODEL)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rule
# ----------------------------
$(DATA_DIR_FINAL) $(GEN_DIR_TABLES):
	if not exist $@ mkdir $@

# ----------------------------
# Sentiment Analysis Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEWS) $(BUSINESS_RAW) $(SENTIMENT) $(THETA) | $(DATA_DIR_FINAL) $(GEN_DIR_TABLES)
	@echo "Running analysis script and saving the results..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	del /Q $(subst /,\,$(TARGETS)) 2>nul || true
