# -----------------------------------
# Makefile: LDA Topic Modeling
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_TRAINING := ../../../data/training_data
DATA_DIR_FINAL    := ../../../data/final_data
GEN_DIR_FIGURES   := ../../../gen/figures
GEN_DIR_TABLES    := ../../../gen/tables

# ----------------------------
# Input Files
# ----------------------------
REVIEWS_MASKED := $(DATA_DIR_TRAINING)/reviews_ner_masked.csv
REVIEWS_SAMPLE := $(DATA_DIR_TRAINING)/reviews_sampled.rds

# ----------------------------
# Script
# ----------------------------
SCRIPT := LDA.R

# ----------------------------
# Output Files
# ----------------------------
THETA              := $(DATA_DIR_FINAL)/theta.csv
PHI                := $(DATA_DIR_FINAL)/phi.csv
COHERENCE_ELBOW    := $(GEN_DIR_FIGURES)/coherence_elbow_plot.pdf
COHERENCE_TABLE    := $(GEN_DIR_TABLES)/coherence_table.html
LDA_VIS             := $(GEN_DIR_FIGURES)/lda_vis.pdf
TOPTERMS_PRE_FREX  := $(GEN_DIR_TABLES)/top_terms_pre_frex.html
TOPTERMS_POST_FREX := $(GEN_DIR_TABLES)/top_terms_post_frex.html
LDA_MODEL          := $(DATA_DIR_FINAL)/lda_model.rds

TARGETS := \
	$(THETA) \
	$(PHI) \
	$(COHERENCE_ELBOW) \
	$(COHERENCE_TABLE) \
	$(LDA_VIS) \
	$(TOPTERMS_PRE_FREX) \
	$(TOPTERMS_POST_FREX) \
	$(LDA_MODEL)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rules
# ----------------------------
$(DATA_DIR_TRAINING):
	Rscript -e "if (!dir.exists('$(DATA_DIR_TRAINING)')) dir.create('$(DATA_DIR_TRAINING)', recursive = TRUE)"

$(DATA_DIR_FINAL):
	Rscript -e "if (!dir.exists('$(DATA_DIR_FINAL)')) dir.create('$(DATA_DIR_FINAL)', recursive = TRUE)"

$(GEN_DIR_FIGURES):
	Rscript -e "if (!dir.exists('$(GEN_DIR_FIGURES)')) dir.create('$(GEN_DIR_FIGURES)', recursive = TRUE)"

$(GEN_DIR_TABLES):
	Rscript -e "if (!dir.exists('$(GEN_DIR_TABLES)')) dir.create('$(GEN_DIR_TABLES)', recursive = TRUE)"

# ----------------------------
# LDA Analysis Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(REVIEWS_MASKED) $(REVIEWS_SAMPLE) | $(DATA_DIR_FINAL) $(GEN_DIR_FIGURES) $(GEN_DIR_TABLES)
	@echo "Running LDA topic modeling and generating outputs..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting LDA data, figures and plots..."
	Rscript -e "files <- strsplit('$(TARGETS)', ' ')[[1]]; unlink(files, recursive = TRUE, force = TRUE)"
