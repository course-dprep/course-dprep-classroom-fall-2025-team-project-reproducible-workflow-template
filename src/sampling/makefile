# -----------------------------------
# Makefile: Sampling data
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_RAW        := ../../data/raw_data
DATA_DIR_TRAINING   := ../../data/training_data
DATA_DIR_VALIDATION := ../../data/validation_data

# ----------------------------
# Input Files
# ----------------------------
REVIEW_RAW   := $(DATA_DIR_RAW)/review.rds
BUSINESS_RAW := $(DATA_DIR_RAW)/business.rds
CHECKIN_RAW  := $(DATA_DIR_RAW)/checkin.rds

# ----------------------------
# Script
# ----------------------------
SCRIPT := sampling.R

# ----------------------------
# Output Files
# ----------------------------
TRAINING_SAMPLED  := $(DATA_DIR_TRAINING)/reviews_sampled.rds
VALIDATION_SAMPLED := $(DATA_DIR_VALIDATION)/reviews_validation.rds

TARGETS := $(TRAINING_SAMPLED) $(VALIDATION_SAMPLED)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rules
# ----------------------------
$(DATA_DIR_TRAINING):
	Rscript -e "if (!dir.exists('$(DATA_DIR_TRAINING)')) dir.create('$(DATA_DIR_TRAINING)', recursive = TRUE)"

$(DATA_DIR_VALIDATION):
	Rscript -e "if (!dir.exists('$(DATA_DIR_VALIDATION)')) dir.create('$(DATA_DIR_VALIDATION)', recursive = TRUE)"

# ----------------------------
# Sampling Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEW_RAW) $(BUSINESS_RAW) $(CHECKIN_RAW) | $(DATA_DIR_TRAINING) $(DATA_DIR_VALIDATION)
	@echo "Running sampling script..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Cleaning sampled data..."
	Rscript -e "files <- strsplit('$(TARGETS)', ' ')[[1]]; unlink(files, recursive = TRUE, force = TRUE)"
