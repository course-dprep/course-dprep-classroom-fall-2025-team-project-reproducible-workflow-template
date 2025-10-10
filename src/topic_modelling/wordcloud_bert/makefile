# -----------------------------------
# Makefile: Wordcloud BERT
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_TRAINING := ../../../data/training_data
GEN_DIR_FIGURES := ../../../gen/figures

# ----------------------------
# Input Files
# ----------------------------
BERTOPIC_TOPICS := $(DATA_DIR_TRAINING)/bertopic_topic_info.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := wordcloud_bert.R

# ----------------------------
# Output Files
# ----------------------------
WORDCLOUD := $(GEN_DIR_FIGURES)/wordcloud_bert.pdf


TARGETS := $(WORDCLOUD)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rule
# ----------------------------
$(DATA_DIR_TRAINING):
	Rscript -e "if (!dir.exists('$(DATA_DIR_TRAINING)')) dir.create('$(DATA_DIR_TRAINING)', recursive = TRUE)"

$(GEN_DIR_FIGURES):
	Rscript -e "if (!dir.exists('$(GEN_DIR_FIGURES)')) dir.create('$(GEN_DIR_FIGURES)', recursive = TRUE)"

# ----------------------------
# Wordcloud rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(BERTOPIC_TOPICS) | $(DATA_DIR_TRAINING) $(GEN_DIR_FIGURES)
	@echo "Creating BERTopic wordclouds..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting plot..."
	Rscript -e "files <- strsplit('$(TARGETS)', ' ')[[1]]; unlink(files, recursive = TRUE, force = TRUE)"
