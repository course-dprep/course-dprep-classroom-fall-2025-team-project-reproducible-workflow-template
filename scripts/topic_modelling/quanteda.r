required_packages <- c("tidyverse", "data.table", "here", "quanteda", "quanteda.textstats", "keyATM")

for (pkg in required_packages) {
	if (!requireNamespace(pkg, quietly = TRUE)) {
		suppressMessages(install.packages(pkg))
	}
}
#load all the dependencies
invisible(lapply(required_packages, function(pkg) {
	suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

reviews <- read_csv(here("data", "training_data", "reviews_python_out.csv"))

#corpus
corp <- corpus(reviews, text_field = "text")
docvars(corp, "review_id") <- reviews$review_id

#tokenize
toks <- tokens(
	corp,
	remove_punct = TRUE,
	remove_numbers = TRUE,
	remove_symbols = TRUE,
	remove_url = TRUE) %>%
	tokens_tolower() %>%
	tokens_remove(stopwords("en")) %>%
	tokens_select (min_nchar = 2)		#this part cleans the reviews 

dfm_clean <- dfm(toks)
doc_len <- ntoken(dfm_clean)
sum(doc_len == 0) 


#dictionary
dict <- dictionary(list(
	service       = c("service*", "staff", "waiter", "waitress", "server*", "attentive", "rude"),
	price_value   = c("price*", "expens*", "cheap", "value", "overpric*", "worth*"),
	cleanliness   = c("clean*", "dirty", "hygien*", "sanit*"),
	wait_time     = c("wait*", "queue*", "slow", "delay*", "late"),
	taste_quality = c("taste*", "flavor*", "delici*", "fresh*", "bland", "stale"),
	app_ordering  = c("app", "order*", "deliver*", "pickup", "online", "website", "bug*", "crash*")
))	#here we add our topics to investigate. We have to feed this dictionary based on the words that appear a lot

topic_counts_dfm <- dfm_lookup(dfm_clean, dictionary = dict)

counts_mat <- as.matrix(topic_counts_dfm)	#count of words from each dic topic in every review
doc_len    <- ntoken(dfm_clean)				#gets length of every review for proportion variable
prop_mat   <- counts_mat / doc_len[rownames(counts_mat)]  #creates new proportion matrix

#keyATM to feed the list of topics

toks_list <- as.list(toks) # keyATM expects a list of token vectors

docs <- keyATM_read(texts = dfm_clean)

keywords <- list(
	service       = c("service","waiter","waitress","server","attentive","rude","staff"),
	price_value   = c("price","expensive","cheap","value","overpriced","worth"),
	cleanliness   = c("clean","dirty","sanitary"),
	wait_time     = c("wait","slow","delay","late"),
	taste_quality = c("taste","flavor","delicious","fresh","bland","stale"),
	app_ordering  = c("app","order","delivery","pickup","online","website","bug")
)

fit <- keyATM(
	docs = docs,
	keywords = as.list(keywords),
	no_keyword_topics = 0,  # set to 1–3 if you want a few free topics
	model = "base",
	options = list(seed = 123, 
	iterations = 1500))


tw <- top_words(fit, n = 50)   # 30 words per topic
print(tw)


