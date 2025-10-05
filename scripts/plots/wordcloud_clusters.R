required_packages <- c("tidyverse", "tidyr", "dplyr" "readr", "data.table", "here", "googledrive", "cld3", "wordcloud", "RColorBrewer")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    suppressMessages(install.packages(pkg))
  }
}

install.packages(c("wordcloud","tm"),repos="http://cran.r-project.org")
library(wordcloud)
library(tm)


#load all the dependencies
invisible(lapply(required_packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

filename <- "bertopic_topic_info.csv"

# load data 
bertopic_topic_info <- read_csv(here("data", "training_data", filename))

# Split + unnest words + frequency of words
BERTopic_viz <- bertopic_topic_info %>% select(Topic, Representation)
BERTopic_words <- BERTopic_viz %>%
  separate_rows(Representation, sep = "\\s+") %>%  # split words
  mutate(Representation = gsub("[^a-zA-Z0-9]", "", Representation)) %>%  # keep only letters/numbers
  filter(Representation != "") %>%
  count(Topic, Representation, sort = TRUE)

# Create folder "plots" if it doesn’t exist
if (!dir.exists("plots")) {
  dir.create("plots")
}

# Define color palette
pal <- brewer.pal(8, "Dark2")

# Create and save a wordcloud for each topic
for (t in unique(BERTopic_words$Topic)) {
  
  # Subset words for this topic
  topic_words <- BERTopic_words %>% filter(Topic == t)
  
  # Create png_name
  png_name <- file.path("plots", paste0("wordcloud_topic_", t, ".png"))
  
  # Save as PNG
  png(png_name, width = 800, height = 600)
  
  # Add title and plot wordcloud
  wordcloud(words = topic_words$Representation,
            freq = topic_words$n,
            min.freq = 1,
            max.words = 20,
            random.order = FALSE,
            colors = pal)
  
  title(main = paste("Wordcloud for Topic", t), cex.main = 1.5, col.main = "black")
  
  dev.off()
  
  cat("✅ Saved:", png_name, "\n")
}

