# -----------------------------------
# Makefile: Model Validation
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_VALIDATION := ../../data/validation_data
DATA_DIR_FINAL    := ../../data/final_data
DATA_DIR_RAW := ../../data/raw_data
GEN_DIR_TABLES := ../../gen/tables

# ----------------------------
# Input Files
# ----------------------------
REVIEWS := $(DATA_DIR_VALIDATION)/reviews_validation.rds
BUSINESS_RAW := $(DATA_DIR_RAW)/business.rds
LDA_MODEL := $(DATA_DIR_FINAL)/lda_model.rds
LOGISTIC_MODEL := $(DATA_DIR_FINAL)/logistic_model.rds

# ----------------------------
# Script
# ----------------------------
SCRIPT := validation.R

# ----------------------------
# Output Files
# ----------------------------
MODEL_PERFORMANCE_VAL := $(GEN_DIR_TABLES)/model_performance_val.html

TARGETS := $(MODEL_PERFORMANCE_VAL)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rule
# ----------------------------
$(GEN_DIR_TABLES):
	Rscript -e "if (!dir.exists('$(GEN_DIR_TABLES)')) dir.create('$(GEN_DIR_TABLES)', recursive = TRUE)"

# ----------------------------
# Sentiment Analysis Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEWS) $(BUSINESS_RAW) $(LDA_MODEL) $(LOGISTIC_MODEL) | $(GEN_DIR_TABLES)
	@echo "Running validation analysis on sampled validation reviews and saving the results..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting model validation output..."
	Rscript -e "files <- strsplit('$(TARGETS)', ' ')[[1]]; unlink(files, recursive = TRUE, force = TRUE)"
