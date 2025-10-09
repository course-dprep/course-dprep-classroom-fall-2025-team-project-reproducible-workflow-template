# -----------------------------------
# Makefile: Data download step
# -----------------------------------

# Paths
DATA_DIR := ../../data/raw_data
SCRIPT := data_download.R

# Marker file
TARGETS := $(DATA_DIR)/.done

# Actual data files
DATA := \
	$(DATA_DIR)/business.rds \
	$(DATA_DIR)/checkin.rds \
	$(DATA_DIR)/review.rds \
	$(DATA_DIR)/tip.rds \
	$(DATA_DIR)/user.rds \
	$(DATA_DIR)/yelp_academic_dataset_business.csv \
	$(DATA_DIR)/yelp_academic_dataset_checkin.csv \
	$(DATA_DIR)/yelp_academic_dataset_review.csv \
	$(DATA_DIR)/yelp_academic_dataset_tip.csv \
	$(DATA_DIR)/yelp_academic_dataset_user.csv

# Default target
all: $(TARGETS)

# Create data directory if needed
$(DATA_DIR):
	if not exist $(DATA_DIR) mkdir $(DATA_DIR)

# Build target: run the R script that generates all files
$(TARGETS): $(SCRIPT) | $(DATA_DIR)
	@echo "Downloading raw data..."
	Rscript $(SCRIPT)

# Clean target: remove all generated data and marker
.PHONY: clean
clean:
	del /Q $(subst /,\,$(DATA)) 2>nul || true
	del /Q $(subst /,\,$(TARGETS)) 2>nul || true
