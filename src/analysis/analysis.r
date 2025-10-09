# ========== SETUP ==========

# Loading required packages
suppressPackageStartupMessages({
	suppressWarnings({
		library(tidyverse)
		library(data.table)
		library(here)
		library(compositions)
		library(lme4)
		library(lmerTest)
		library(performance)
		library(gt)
		library(stargazer)
		library(pROC)
	})
})

# === Global parameters ===

# Define input file paths
input_paths <- list(
	business = here("data", "raw_data", "business.rds"),
	reviews_sampled = here("data", "training_data", "reviews_sampled.rds"),
	sentiment = here("data", "final_data", "sentiment_scores.csv"),
	theta = here("data", "final_data", "theta.csv")
)

# Define output file paths
output_paths <- list(
	avg_sent_per_dominant_topic = here("gen", "tables", "avg_sentiment_per_dominant_topic.html"),
	logistic_regression = here("gen", "tables", "logistic_regression.html"),
	topic_on_sentiment = here("gen", "tables", "topic_on_sentiment.html"),
	model_performance = here("gen", "tables", "model_performance_statistics.html"),
	logistic_model = here("data", "final_data", "logistic_model.rds")
)

# Set seed for reproducibility
set.seed(1234)

# ========== INPUT ==========

# Load cleaned review sample
reviews_sampled <- readRDS(input_paths$reviews_sampled)

# Load business metadata
business <- readRDS(input_paths$business)

# Load sentiment scores
sentiment <- read_csv(input_paths$sentiment)

# Load topic proportions (θ matrix from LDA)
theta <- read_csv(input_paths$theta)

# ========== TRANSFORMATION & OUTPUT ==========

# Identify topic probability columns (e.g., t_1, t_2, ...)
topic_cols <- colnames(theta)[startsWith(colnames(theta), "t")]

# Apply CLR transformation to topic proportions to remove compositional dependency
theta_clr <- cbind(
	review_id = theta$review_id,
	as.data.frame(compositions::clr(theta[, topic_cols] + 1e-20)) # add tiny constant to avoid log(0)
)

# Merge topic, sentiment, review, and business data into a single dataset
data <- merge(theta_clr, sentiment,
			  by = "review_id",
			  all = TRUE) %>%
	merge(., reviews_sampled[, c("business_id", "review_id")],
		  by = "review_id",
		  all.x = TRUE) %>%
	merge(., business[, c("business_id", "is_open")],
		  by = "business_id",
		  all.x = TRUE)

# Assign each review its dominant topic (highest probability)
data$assigned_topic <- topic_cols[max.col(data[, topic_cols], ties.method = "first")]

# Aggregate mean topic weights and sentiment per business
data_agg <- data %>%
	group_by(business_id) %>%
	summarise(
		across(all_of(c(topic_cols, "compound")), mean, na.rm = TRUE),
		.groups = "drop"
	)

# Add business-level open/closed status
data_agg <- merge(data_agg, business[, c("business_id", "is_open")],
				  by = "business_id",
				  all.x = TRUE)

# Ensure is_open is a factor
data_agg$is_open <- as.factor(data_agg$is_open)

# Build dynamic logistic regression formula (topics × sentiment)
formula_str <- paste("is_open ~ (", paste(topic_cols, collapse = " + "), ")*compound")

# Fit logistic regression predicting business closure
model_logistic <- glm(as.formula(formula_str), data = data_agg, family = "binomial")

# Save fitted model
saveRDS(model_logistic, output_paths$logistic_model)

# Inspect model summary
summary(model_logistic)

# Compute predicted probabilities and classifications
data_agg$pred_prob <- predict(model_logistic, type = "response")
data_agg$pred_class <- round(data_agg$pred_prob)

# === Mixed-effects models: topic effects on sentiment ===

# Fit one mixed model per topic (random intercept per business)
models_lmer <- lapply(topic_cols, function(t) {
	formula <- as.formula(paste("compound ~", t, "+ (1 | business_id)"))
	lmer(formula, data = data)
})

# Extract coefficients, p-values, and marginal R²
results_lmer_sentiment <- data.frame(
	topic = topic_cols,
	beta = sapply(models_lmer, function(m) fixef(m)[2]),
	p_value = sapply(models_lmer, function(m) summary(m)$coefficients[2, 5]),
	R2 = sapply(models_lmer, function(m) performance::r2(m)$R2_marginal)
)

# === Descriptive summary: mean sentiment per dominant topic ===
topic_sentiment_summary <- data %>%
	group_by(assigned_topic) %>%
	summarise(
		mean_sentiment = mean(compound, na.rm = TRUE),
		sd_sentiment = sd(compound, na.rm = TRUE),
		n = n()
	) %>%
	arrange(desc(mean_sentiment))

# Save sentiment summary table as HTML
topic_sentiment_summary %>%
	mutate(
		mean_sentiment = round(mean_sentiment, 3),
		sd_sentiment = round(sd_sentiment, 3),
		assigned_topic = gsub("t_", "", assigned_topic)
	) %>%
	gt() %>%
	tab_header(
		title = "Average Sentiment per Dominant Topic",
		subtitle = "Based on hard topic assignment of each review"
	) %>%
	cols_label(
		assigned_topic = "Topic",
		mean_sentiment = "Mean Sentiment",
		sd_sentiment = "SD",
		n = "N"
	) %>%
	fmt_number(columns = c(mean_sentiment, sd_sentiment), decimals = 3) %>%
	gtsave(., output_paths$avg_sent_per_dominant_topic)

# Save logistic regression summary as HTML
stargazer(model_logistic, type = "html", out = output_paths$logistic_regression)

# Save mixed-effects model summary table
results_lmer_sentiment %>%
	mutate(
		beta = round(beta, 3),
		p_value = formatC(p_value, format = "e", digits = 2),
		R2 = round(R2, 3),
		topic = gsub("t_", "", topic)
	) %>%
	gt() %>%
	tab_header(
		title = "Topic-Level Effects on Sentiment (Mixed Model)",
		subtitle = "Fixed effects from topic-specific LMER models controlling for business-level dependence"
	) %>%
	cols_label(
		topic = "Topic",
		beta = "β (Effect on Sentiment)",
		p_value = "p-value",
		R2 = "Marginal R²"
	) %>%
	fmt_number(columns = c(beta, R2), decimals = 3) %>%
	tab_options(
		table.font.size = px(13),
		heading.title.font.size = px(16),
		heading.subtitle.font.size = px(13),
		data_row.padding = px(4)
	) %>%
	gtsave(., output_paths$topic_on_sentiment)

# === Model performance summary ===

# Compute overall classification accuracy
model_accuracy <- mean(data_agg$pred_class == as.numeric(as.character(data_agg$is_open)))

# Build confusion matrix
cm <- table(Predicted = data_agg$pred_class, Actual = data_agg$is_open)
TP <- cm["1", "1"]
TN <- cm["0", "0"]
FP <- cm["1", "0"]
FN <- cm["0", "1"]

# Derive evaluation metrics
precision <- TP / (TP + FP)
recall <- TP / (TP + FN)
specificity <- TN / (TN + FP)
f1 <- (2 * precision * recall) / (precision + recall)

# Compute AUC
auc_val <- roc(data_agg$is_open, data_agg$pred_prob) %>% auc

# Compile performance metrics into a summary table
model_summary <- tibble::tibble(
	Model = "Logistic (Topic × Sentiment)",
	Accuracy = round(model_accuracy, 3),
	AUC = round(as.numeric(auc_val), 3),
	Precision = round(precision, 3),
	Recall = round(recall, 3),
	Specificity = round(specificity, 3),
	F1 = round(f1, 3),
	TPR = round(recall, 3),
	TNR = round(specificity, 3),
	TP = TP, TN = TN, FP = FP, FN = FN
) %>%
	gt() %>%
	tab_header(
		title = "Model Performance Summary",
		subtitle = "Logistic Regression with Topic × Sentiment Interaction"
	) %>%
	fmt_number(columns = c(Accuracy, AUC, Precision, Recall, Specificity, F1, TPR, TNR), decimals = 3) %>%
	cols_label(
		Model = "Model",
		Accuracy = "Accuracy",
		AUC = "Area Under Curve (AUC)",
		Precision = "Precision",
		Recall = "Recall",
		Specificity = "Specificity",
		F1 = "F1 Score",
		TPR = "True Positive Rate",
		TNR = "True Negative Rate",
		TP = "True Positives",
		TN = "True Negatives",
		FP = "False Positives",
		FN = "False Negatives"
	) %>%
	tab_options(
		table.font.size = px(13),
		heading.title.font.size = px(16),
		heading.subtitle.font.size = px(13),
		data_row.padding = px(4)
	) %>%
	gtsave(., output_paths$model_performance)
