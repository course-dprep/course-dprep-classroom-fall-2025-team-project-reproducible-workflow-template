# ========== SETUP ==========

# Required packages
required_packages <- c(
	"tidyverse", "data.table", "here", "cld3", "textclean",
	"vader", "quanteda", "tm", "pROC", "gt"
)

# Load packages silently
for (pkg in required_packages) {
	if (requireNamespace(pkg, quietly = TRUE)) {
		suppressWarnings(
			suppressPackageStartupMessages(
				library(pkg, character.only = TRUE)
			)
		)
	} else {
		message(sprintf(
			"Package '%s' is not installed. Please install it first.",
			pkg
		))
	}
}

# Seed for reproducibility
set.seed(2310)

# Define input paths
input_paths <- list(
	reviews    = here("data", "training_data", "reviews_validation.rds"),
	lda_model  = here("data", "final_data", "lda_model.rds"),
	business   = here("data", "raw_data", "business.rds"),
	logistic_model = here("data", "final_data", "logistic_model.rds")
)

# Define output path
output_paths <- list(
	model_performance_val = here("gen", "tables", "model_performance_val.html")
)

# ========== INPUT ==========

# Load validation reviews and business info
reviews    <- readRDS(input_paths$reviews)
lda_model  <- readRDS(input_paths$lda_model)
business   <- readRDS(input_paths$business)

# ========== TRANSFORMATION ==========

# --- Clean text for sentiment analysis ---
reviews <- reviews %>%
	mutate(language = cld3::detect_language(text)) %>%
	filter(language == "en") %>%
	mutate(
		text_for_vader = text %>%
			replace_html() %>%         # Remove HTML tags
			replace_url() %>%          # Remove links
			str_squish()               # Trim whitespace
	)

# --- Run VADER sentiment analysis ---
vader_results <- vader_df(reviews$text_for_vader) %>%
	as.data.frame() %>%
	mutate(review_id = reviews$review_id)

# --- Prepare data for topic inference ---
data <- reviews %>%
	transmute(id = review_id, text = text)

# --- Tokenize and clean text ---
tokens <- data %>%
	tidytext::unnest_tokens(word, text, strip_punct = TRUE) %>%
	filter(!(word %in% quanteda::stopwords("en"))) %>%
	filter(nchar(word) > 1) %>%
	mutate(
		word = tolower(word),
		word = gsub("[[:digit:]]+", " ", word),
		word = str_squish(word)
	) %>%
	filter(word != "")

# --- Recombine cleaned tokens into text strings ---
data_cleaned <- tokens %>%
	group_by(id) %>%
	summarise(text = paste(word, collapse = " "), .groups = "drop")

# --- Create DTM for validation reviews ---
dtm_val <- textmineR::CreateDtm(
	data_cleaned$text,
	doc_names = data_cleaned$id,
	ngram_window = c(1, 2)
)

# --- Align validation DTM with training vocabulary ---
vocab_train <- colnames(lda_model$phi)
common_vocab <- intersect(colnames(dtm_val), vocab_train)
dtm_val_aligned <- dtm_val[, common_vocab]
phi_aligned <- lda_model$phi[, common_vocab]

# --- Compute topic probabilities (theta) via log-softmax inference ---
alpha <- mean(lda_model$alpha)
log_scores <- as.matrix(dtm_val_aligned) %*% t(log(phi_aligned + 1e-12))
log_scores <- sweep(log_scores, 2, log(alpha), "+")
theta_val <- exp(log_scores - apply(log_scores, 1, max))
theta_val <- theta_val / rowSums(theta_val)

# --- Add review_id for merging ---
theta_val <- theta_val %>%
	as.data.frame() %>%
	tibble::rownames_to_column("review_id")

# --- Combine topic, sentiment, and metadata ---
data_val <- theta_val %>%
	merge(vader_results, by = "review_id", all.x = TRUE) %>%
	merge(reviews, by = "review_id", all.x = TRUE) %>%
	merge(business[, c("business_id", "is_open")],
		  by = "business_id", all.x = TRUE)

# --- Aggregate to business level ---
data_agg <- data_val %>%
	group_by(business_id) %>%
	summarise(across(
		c(t_1, t_2, t_3, t_4, t_5, t_6, t_7, compound),
		mean, na.rm = TRUE
	), .groups = "drop") %>%
	left_join(business[, c("business_id", "is_open")], by = "business_id")

# --- Load trained logistic model ---
logistic_model_val <- readRDS(input_paths$logistic_model)

# --- Predict open/closed status ---
data_agg$pred_prob <- predict(logistic_model_val, newdata = data_agg, type = "response")
data_agg$pred_class <- round(data_agg$pred_prob)

# --- Compute model performance metrics ---
cm <- table(Predicted = data_agg$pred_class, Actual = data_agg$is_open)
TP <- cm["1", "1"]; TN <- cm["0", "0"]; FP <- cm["1", "0"]; FN <- cm["0", "1"]

precision <- TP / (TP + FP)
recall <- TP / (TP + FN)
specificity <- TN / (TN + FP)
f1 <- (2 * precision * recall) / (precision + recall)
auc_val <- roc(data_agg$is_open, data_agg$pred_prob) %>% auc()
accuracy <- mean(data_agg$pred_class == data_agg$is_open)

# --- Create clean performance summary table ---
model_summary <- tibble::tibble(
	Model = "Logistic (Topic × Sentiment)",
	Accuracy = round(accuracy, 3),
	AUC = round(as.numeric(auc_val), 3),
	Precision = round(precision, 3),
	Recall = round(recall, 3),
	Specificity = round(specificity, 3),
	F1 = round(f1, 3),
	TP = TP, TN = TN, FP = FP, FN = FN
) %>%
	gt() %>%
	tab_header(
		title = "Model Performance on Validation Data",
		subtitle = "Logistic Regression with Topic × Sentiment Interaction"
	) %>%
	fmt_number(
		columns = c(Accuracy, AUC, Precision, Recall, Specificity, F1),
		decimals = 3
	) %>%
	tab_options(
		table.font.size = px(13),
		heading.title.font.size = px(16),
		heading.subtitle.font.size = px(13),
		data_row.padding = px(4)
	)

# ========== OUTPUT   ==========

gc()

# --- Save table ---
gtsave(model_summary, output_paths$model_performance_val)
message("✅ Model validation results saved to: ", output_paths$model_performance_val)
