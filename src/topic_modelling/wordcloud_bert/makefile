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
$(DATA_DIR_TRAINING) $(GEN_DIR_FIGURES):
	if not exist $@ mkdir $@

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
	del /Q $(subst /,\,$(TARGETS)) 2>nul || true
