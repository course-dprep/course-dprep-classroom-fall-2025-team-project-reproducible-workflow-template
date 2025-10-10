# -----------------------------------
# Root Makefile: Full Data Pipeline
# -----------------------------------

# Define subdirectories (relative to project root)
SRC := src
DATA_DOWNLOAD := $(SRC)/data_download
SAMPLING := $(SRC)/sampling
CLEAN_BERT := $(SRC)/topic_modelling/data_cleaning_for_bert
BERT := $(SRC)/topic_modelling/bert
WORDCLOUD_BERT := $(SRC)/topic_modelling/wordcloud_bert
CLEAN_NER := $(SRC)/topic_modelling/data_cleaning_for_ner
NER := $(SRC)/topic_modelling/ner
LDA := $(SRC)/topic_modelling/lda
SENTIMENT := $(SRC)/sentiment
ANALYSIS := $(SRC)/analysis
VALIDATION := $(SRC)/model_validation
REPORTS := $(SRC)/reports

# -----------------------------------
# Default target: full pipeline
# -----------------------------------
all: data_download sampling clean_bert bert wordcloud_bert clean_ner ner lda sentiment analysis validation reports
	@echo "Full pipeline executed successfully."

# -----------------------------------
# Alternative target: skip data download
# -----------------------------------
nodownload: sampling clean_bert bert wordcloud_bert clean_ner ner lda sentiment analysis validation reports
	@echo "Pipeline executed successfully (skipped data download)."

# -----------------------------------
# Individual step targets
# -----------------------------------
data_download:
	$(MAKE) -C $(DATA_DOWNLOAD)

sampling: data_download
	$(MAKE) -C $(SAMPLING)

clean_bert: sampling
	$(MAKE) -C $(CLEAN_BERT)

bert: clean_bert
	$(MAKE) -C $(BERT)

wordcloud_bert: bert
	$(MAKE) -C $(WORDCLOUD_BERT)

clean_ner: sampling
	$(MAKE) -C $(CLEAN_NER)

ner: clean_ner
	$(MAKE) -C $(NER)

lda: ner
	$(MAKE) -C $(LDA)

sentiment: lda
	$(MAKE) -C $(SENTIMENT)

analysis: sentiment
	$(MAKE) -C $(ANALYSIS)

validation: analysis
	$(MAKE) -C $(VALIDATION)

reports: validation
	$(MAKE) -C $(REPORTS)

# -----------------------------------
# Clean everything
# -----------------------------------
.PHONY: clean
clean:
	@echo "Cleaning all submodules..."
	-$(MAKE) -C $(REPORTS) clean
	-$(MAKE) -C $(VALIDATION) clean
	-$(MAKE) -C $(ANALYSIS) clean
	-$(MAKE) -C $(SENTIMENT) clean
	-$(MAKE) -C $(LDA) clean
	-$(MAKE) -C $(NER) clean
	-$(MAKE) -C $(CLEAN_NER) clean
	-$(MAKE) -C $(WORDCLOUD_BERT) clean
	-$(MAKE) -C $(BERT) clean
	-$(MAKE) -C $(CLEAN_BERT) clean
	-$(MAKE) -C $(SAMPLING) clean
	-$(MAKE) -C $(DATA_DOWNLOAD) clean
	@echo "All submodules cleaned."
