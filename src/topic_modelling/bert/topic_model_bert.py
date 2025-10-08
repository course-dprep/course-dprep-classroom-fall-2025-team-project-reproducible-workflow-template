# ========== SETUP ==========

# Modules
import pandas as pd
from bertopic import BERTopic
from sentence_transformers import SentenceTransformer
from umap import UMAP
from hdbscan import HDBSCAN
from sklearn.feature_extraction.text import CountVectorizer, ENGLISH_STOP_WORDS
from pathlib import Path
import numpy as np

# === Global parameters ===

# Relative location of the project root
project_root = Path(__file__).resolve().parents[3]

# Data input paths
input_paths = {
    "reviews_cleaned_for_bert": project_root / "data" / "training_data" / "reviews_cleaned_for_bert.csv"
}

# Data output paths
output_paths = {
    "bertopic_cluster_probabilities": project_root / "data" / "training_data" / "bertopic_cluster_probabilities.csv",
    "bertopic_topic_info": project_root / "data" / "training_data" / "bertopic_topic_info.csv"
}

# Model used to compute the review embeddings
embedding_model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

# Stop word list
stop_words = list(ENGLISH_STOP_WORDS)

# UMAP model
umap_model = UMAP(
    n_neighbors=25,
    n_components=10,
    min_dist=0.0,
    metric="cosine",
    random_state=42
)

# HDBSCAN model
hdbscan_model = HDBSCAN(
    min_cluster_size=50,
    min_samples=5,
    prediction_data=True
)

#Vectorizer model
vectorizer_model = CountVectorizer(
    ngram_range=(1, 2),
    stop_words=stop_words,  
    min_df=5,
    max_df=0.6
)

# Topic model
topic_model = BERTopic(
    embedding_model=embedding_model,
    umap_model=umap_model,
    hdbscan_model=hdbscan_model,
    vectorizer_model=vectorizer_model,
    calculate_probabilities=True,
    verbose=True
)

# ========== INPUT ==========

# Cleaned dataset with reviews, specifically for BERTopic
df = pd.read_csv(input_paths["reviews_cleaned_for_bert"])

# ========== TRANSFORMATION ==========

# Keep review_id as index so it stays the reviews as index
df = df.set_index("review_id")

# Specify the text column that BERT needs to use
docs = df["text_bert"].astype(str).tolist()             # For Embeddings
docs_label = df["text_label"].astype(str).tolist()      # For naming clusters

# Embedding parameters
embeddings = embedding_model.encode(
    docs,
    batch_size=156,
    show_progress_bar=True,
    convert_to_numpy=True,
    normalize_embeddings=True
)

# Fit BERTopic on the reviews
topics, probs = topic_model.fit_transform(docs_label, embeddings)

# Create hard assigned topic column
df["assigned_topic_id"] = topics

# Create dataframe with cluster_id, N, cluster_name, top words per cluster, and representative docs
topic_info = topic_model.get_topic_info()
print(topic_info)

# Create probability columns
topic_order = topic_model.get_topic_freq().Topic.tolist()
topic_order_no_noise = [t for t in topic_order if t != -1]

# Dataframe with topic probabilties per review_id
probs_df = pd.DataFrame(
    probs,
    index=df.index, 
    columns=[f"prob_topic_{t}" for t in topic_order_no_noise]
)

# Dataframe with all the topic probabilities per review and the hard assigned topic
df_out = pd.concat([df, probs_df], axis=1).reset_index()

# ========== OUTPUT ==========

# Export df_out as .csv
df_out.to_csv(output_paths["bertopic_cluster_probabilities"], index=False, encoding="utf-8")
print(f"Exported topic probabilities to: {output_paths['bertopic_cluster_probabilities']}")

# Export topic_info as .csv
topic_info.to_csv(output_paths["bertopic_topic_info"], index=False, encoding="utf-8")
print(f"Exported topic_info to: {output_paths['bertopic_topic_info']}")