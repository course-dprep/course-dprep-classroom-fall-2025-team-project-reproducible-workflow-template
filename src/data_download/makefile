# -----------------------------------
# Makefile: Data download step
# -----------------------------------

# Paths
DATA_DIR := ../../data/raw_data
SCRIPT := data_download.R

# Output files produced by the script
TARGETS := \
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

# Default target: build all data
all: $(TARGETS)

# Create data directory
$(DATA_DIR):
	if not exist $(DATA_DIR) mkdir $(DATA_DIR)

$(TARGETS): $(SCRIPT)|$(DATA_DIR)
	@echo "Downloading raw data..."
	Rscript data_download.R

.PHONY: clean
clean:
	del /Q $(subst /,\,$(TARGETS)) 2>nul || true