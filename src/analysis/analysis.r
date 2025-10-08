# ========== SETUP ==========

# Required packages
required_packages <- c("tidyverse","here","data.table", "compositions", "lme4", "lmerTest",
					   "performance", "gt", "stargazer", "pROC")

# Loading packages 
for (pkg in required_packages) {
	if (requireNamespace(pkg, quietly = TRUE)) {
		suppressWarnings(
			suppressPackageStartupMessages(
				library(pkg, character.only = TRUE)
			)
		)
	} else {
		message(sprintf(
			"Package '%s' is not installed. Make sure to first install all the required packages for this project by running dependencies/install_packages.R",
			pkg
		))
	}
}

# === Global parameters ===

# Relative paths of the input files
input_paths <- list(
	business = here("data", "raw_data", "business.rds"),
	reviews_sampled = here("data", "training_data", "reviews_sampled.rds"),
	sentiment = here("data", "final_data", "sentiment_scores.csv"),
	theta = here("data", "final_data", "theta.csv")
)

# Relative paths of the output files
output_paths <- list(
	avg_sent_per_dominant_topic = here("gen", "tables", "avg_sentiment_per_dominant_topic.html"),
	logistic_regression = here("gen", "tables", "logistic_regression.html"),
	topic_on_sentiment = here("gen", "tables", "topic_on_sentiment.html"),
	model_performance = here("gen", "tables", "model_performance_statistics.html")
)

# Setting seed for reproducibility
set.seed(1234)

# ========== INPUT ==========

# Loading reviews sampled data into environment
reviews_sampled <- readRDS(input_paths$reviews_sampled)

# Loading business data into environment
business <- readRDS(input_paths$business)

# Loading sentiment results into environment
sentiment <- read_csv(input_paths$sentiment)

# Loading LDA theta into environment
theta <- read_csv(input_paths$theta)

# ========== TRANSFORMATION ==========
topic_cols <- c("t_1", "t_2", "t_3", "t_4", "t_5", "t_6", "t_7")
# Apply CLR only to topic columns (removes compositional dependency)
theta_clr <- cbind(
	review_id = theta$review_id,
	as.data.frame(compositions::clr(theta[, topic_cols]))
)

# Create data, and add all the needed data to that dataframe
data <- merge(theta_clr, sentiment,
			  by = "review_id",
			  all = TRUE)%>%merge(
			  	.,reviews_sampled[,c("business_id","review_id")],
			  	by = "review_id",
			  	all.x = TRUE
			  )%>%merge(
			  	.,business[,c("business_id", "is_open")],
			  	by = "business_id",
			  	all.x = TRUE
			  )

# Theta columns in the data:
topic_cols <- c("t_1", "t_2", "t_3", "t_4", "t_5", "t_6", "t_7")

# Hard assign a topic to a review
data$assigned_topic <- topic_cols[max.col(data[, topic_cols], ties.method = "first")]

# Convert variable type of is_open to be sure 
data$is_open <- as.factor(data$is_open)

# Aggregate the results per business
data_agg <- data %>%
	group_by(business_id) %>%
	summarise(across(c(t_1, t_2, t_3, t_4, t_5, t_6, t_7, compound), mean, na.rm = TRUE), 
			  .groups = "drop")

data_agg <- merge(data_agg, business[,c("business_id", "is_open")],
				  by = "business_id",
				  all.x = TRUE)

# Convert variable type of is_open to be sure 
data_agg$is_open <- as.factor(data_agg$is_open)

# Fit statistical model
model_logistic <- glm(is_open ~ (t_1 + t_2 + t_3 + t_4 + t_5 + t_6 + t_7)*compound, 
					  data = data_agg,
					  family = "binomial")

saveRDS(model_logistic, here("data", "final_data", "logistic_model.rds"))
# Summary of statistical model
summary(model_logistic)

# Predicted open/closed probability per business
data_agg$pred_prob <- predict(model_logistic, type = "response")

# Predicted open/closed class per business
data_agg$pred_class <- round(data_agg$pred_prob)

# Accuracy of the model
mean(data_agg$pred_class == data_agg$is_open)

# Area under the curve of the model
roc_obj <- roc(data_agg$is_open, data_agg$pred_prob)
auc(roc_obj)


# == Fit logistic model, but applying ILR conversion to theta ==
theta_ilr <- cbind(
	review_id = theta$review_id,
	as.data.frame(ilr(theta[, !names(theta) %in% "review_id"]))
)

# Create data, and add all the needed data to that dataframe
data_ilr <- merge(theta_ilr, sentiment,
			  by = "review_id",
			  all = TRUE)%>%merge(
			  	.,reviews_sampled[,c("business_id","review_id")],
			  	by = "review_id",
			  	all.x = TRUE
			  )%>%merge(
			  	.,business[,c("business_id", "is_open")],
			  	by = "business_id",
			  	all.x = TRUE
			  )

# Convert variable type of is_open to be sure 
data_ilr$is_open <- as.factor(data_ilr$is_open)

# Aggregate the results per business
data_ilr_agg <- data_ilr %>%
	group_by(business_id) %>%
	summarise(across(c(V1, V2, V3, V4, V5, V6 , compound), mean, na.rm = TRUE), 
			  .groups = "drop")

data_ilr_agg <- merge(data_ilr_agg, business[,c("business_id", "is_open")],
				  by = "business_id",
				  all.x = TRUE)

# Fit statistical model
model_logistic_ilr <- glm(is_open ~ (V1+V2+V3+V4+V5+V6)*compound, 
					  data = data_ilr_agg,
					  family = "binomial")

# Summary of statistical model
summary(model_logistic_ilr)

# Predicted open/closed probability per business
data_ilr_agg$pred_prob <- predict(model_logistic_ilr, type = "response")

# Predicted open/closed class per business
data_ilr_agg$pred_class <- round(data_ilr_agg$pred_prob)

# Accuracy of the model
mean(data_ilr_agg$pred_class == data_ilr_agg$is_open)

# Area under the curve of the model
roc_obj_ilr <- roc(data_ilr_agg$is_open, data_ilr_agg$pred_prob)
auc(roc_obj_ilr)




# === Fit linear model to see if there is a marginal effect of a topic on sentiment ===

#  Run mixed-effects models (one per topic)
models_lmer <- lapply(topic_cols, function(t) {
	formula <- as.formula(paste("compound ~", t, "+ (1 | business_id)"))
	lmer(formula, data = data)
})

# Extract fixed effects (beta), p-values, and R²
results_lmer_sentiment <- data.frame(
	topic = topic_cols,
	beta = sapply(models_lmer, function(m) fixef(m)[2]),
	p_value = sapply(models_lmer, function(m) {
		summary(m)$coefficients[2, 5]  # p-value from lmerTest summary
	}),
	R2 = sapply(models_lmer, function(m) {
		performance::r2(m)$R2_marginal  # Marginal R² (fixed effects only)
	})
)

# === Compute mean sentiment per hard assigned topic and save output as html ===
topic_sentiment_summary <- data %>%
	group_by(assigned_topic) %>%
	summarise(
		mean_sentiment = mean(compound, na.rm = TRUE),
		sd_sentiment = sd(compound, na.rm = TRUE),
		n = n()
	) %>%
	arrange(desc(mean_sentiment))

topic_sentiment_summary %>%
	mutate(
		mean_sentiment = round(mean_sentiment,3),
		sd_sentiment = round(sd_sentiment,3),
		assigned_topic = gsub("t_","",assigned_topic)
	)%>%
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
	fmt_number(columns = c(mean_sentiment, sd_sentiment), decimals = 3)%>%gtsave(
		., output_paths$avg_sent_per_dominant_topic
	)

# Save logistic regression output as HTML
stargazer(model_logistic, type = "html", out = output_paths$logistic_regression)

# Save marginal effect of topic on sentiment
results_lmer_sentiment %>%
	mutate(
		beta = round(beta, 3),
		p_value = formatC(p_value, format = "e", digits = 2),
		R2 = round(R2, 3),
		topic = gsub("t_","",topic)
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
	)%>%gtsave(., output_paths$topic_on_sentiment)

# Create table with model performance statistics

# Accuracy of the model
model_accuracy <- mean(data_agg$pred_class == data_agg$is_open)

# Create Confusion Matrix and classify values
cm <- table(Predicted = data_agg$pred_class, Actual = data_agg$is_open)
TP <- cm["1", "1"]
TN <- cm["0", "0"]
FP <- cm["1", "0"]
FN <- cm["0", "1"]

# Precision
precision <- TP/(TP+FP)

# Recall
recall <- TP/(TP+FN)

# Specificity
specificity <- TN / (TN + FP)

# F1
f1 <- (2 * precision * recall) / (precision + recall)

# Area under the curve statistic
auc_val <- roc(data_agg$is_open, data_agg$pred_prob)%>%auc

# Combine everything into a single-row tibble
model_summary <- tibble::tibble(
	Model = "Logistic (Topic * Sentiment)",
	Accuracy = round(model_accuracy, 3),
	AUC = round(as.numeric(auc_val), 3),
	Precision = round(precision, 3),
	Recall = round(recall, 3),
	Specificity = round(specificity, 3),
	F1 = round(f1, 3),
	TPR = round(recall, 3),
	TNR = round(specificity, 3),
	TP = TP,
	TN = TN,
	FP = FP,
	FN = FN
)%>%
	gt() %>%
	tab_header(
		title = "Model Performance Summary",
		subtitle = "Logistic Regression with Topic × Sentiment Interaction"
	) %>%
	fmt_number(
		columns = c(Accuracy, AUC, Precision, Recall, Specificity, F1, TPR, TNR),
		decimals = 3
	) %>%
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
	)%>%gtsave(., output_paths$model_performance)

model_summary
