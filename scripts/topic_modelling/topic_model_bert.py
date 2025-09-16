#dependencies
import pandas as pd
from bertopic import BERTopic
from sentence_transformers import SentenceTransformer
from umap import UMAP
from hdbscan import HDBSCAN
from sklearn.feature_extraction.text import CountVectorizer, ENGLISH_STOP_WORDS
from pathlib import Path
import numpy as np

# ---------- 1. Load data ----------
project_root = Path(__file__).resolve().parents[2]
csv_path_in = project_root / "data" / "training_data" / "reviews_python_in.csv"
csv_path_out = project_root / "data" / "training_data" / "reviews_python_out.csv"
# ---------- 1) Load + set stable key ----------
df = pd.read_csv(csv_path_in)

# sanity check: review_id must be unique
assert df["review_id"].is_unique, "review_id must be unique"

# keep review_id as index so it travels with the data
df = df.set_index("review_id")
print(df.head())

# ---------- 2) (optional) custom stopwords ----------
cuisine_stop = [
    "taco","tacos","burrito","salsa","quesadilla","pho","ramen","sushi","nigiri","tempura",
    "gumbo","jambalaya","beignet","burger","burgers","fries","pizza","pepperoni",
    "pasta","lasagna","gnocchi","naan","curry","samosa","shawarma","falafel","kimchi",
    "bibimbap","paella"
]
stop_words = list(ENGLISH_STOP_WORDS.union(cuisine_stop))

# ---------- 3) Configure models ----------
embedding_model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

docs = df["text"].astype(str).tolist()
embeddings = embedding_model.encode(
    docs,
    batch_size=156,
    show_progress_bar=True,
    convert_to_numpy=True,
    normalize_embeddings=True
)

umap_model = UMAP(
    n_neighbors=25,
    n_components=10,
    min_dist=0.0,
    metric="cosine",
    random_state=42
)

hdbscan_model = HDBSCAN(
    min_cluster_size=50,
    min_samples=5,
    prediction_data=True
)

vectorizer_model = CountVectorizer(
    ngram_range=(1, 2),
    stop_words=stop_words,   # use your custom union
    min_df=5,
    max_df=0.6
)

topic_model = BERTopic(
    embedding_model=embedding_model,
    umap_model=umap_model,
    hdbscan_model=hdbscan_model,
    vectorizer_model=vectorizer_model,
    calculate_probabilities=True,
    verbose=True
)

# ---------- 4) Fit + transform ----------
topics, probs = topic_model.fit_transform(docs, embeddings)

# attach hard assignment directly by index (review_id)
df["assigned_topic_id"] = topics

# ---------- 5) Topic info + probabilities ----------
topic_info = topic_model.get_topic_info()
print(topic_info)

# create probability columns with the SAME index (review_id)
topic_order = topic_model.get_topic_freq().Topic.tolist()
topic_order_no_noise = [t for t in topic_order if t != -1]

probs_df = pd.DataFrame(
    probs,
    index=df.index,  # <- critical: keep review_id alignment
    columns=[f"prob_topic_{t}" for t in topic_order_no_noise]
)

# final output, back to a regular column for review_id if you want
df_out = pd.concat([df, probs_df], axis=1).reset_index()

print(df_out.head())

# export df_out 
df_out.to_csv(csv_path_out, index=False, encoding="utf-8")
print(f"Exported results to: {csv_path_out}")