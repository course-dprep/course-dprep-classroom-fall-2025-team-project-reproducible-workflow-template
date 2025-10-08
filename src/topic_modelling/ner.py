# ========== SETUP ==========

# Modules
import spacy
from spacy.util import filter_spans
import pandas as pd
from pathlib import Path
from transformers import AutoTokenizer, AutoModelForTokenClassification, pipeline
import datetime

# === Global parameters ===

# Relative location of the project root
project_root = Path(__file__).resolve().parents[2]

# Data input paths
input_paths = {
    "reviews_cleaned_for_ner": project_root / "data" / "training_data" / "reviews_cleaned_for_ner.csv"
}

# Data output paths
output_paths = {
    "reviews_ner_masked": project_root / "data" / "training_data" / "reviews_ner_masked.csv"
}

# Load base Named Entity Recognition (ORG, GPE, LOC, FAC)
base_nlp = spacy.load("en_core_web_md")

# Load Named Entity Recognition for Food, via Transformers 
model_id = "Dizex/InstaFoodRoBERTa-NER"
tok = AutoTokenizer.from_pretrained(model_id)
mdl = AutoModelForTokenClassification.from_pretrained(model_id)

# Food specific NER pipeline
ner = pipeline("token-classification", model=mdl, tokenizer=tok, aggregation_strategy="simple")

# Entities to name from the base NER
BASE_KEEP = {"ORG","GPE","LOC","FAC"}

# Defined placeholders for the selected named entities from base + food ner
PLACE = {
    "FOOD":"_FOOD_",
    "ORG":"_RESTAURANT_",
    "GPE":"_LOCATION_",
    "LOC":"_LOCATION_",
    "FAC":"_LOCATION_"
}

# ========== INPUT ==========

df = pd.read_csv(input_paths["reviews_cleaned_for_ner"])

# ========== TRANSFORMATION ==========

# Function that masks selected entities from BOTH NER models
def mask_food_and_base(text: str) -> str:
    if not isinstance(text, str) or not text:
        return "" if text is None else str(text)

    # Run BOTH on the same original text
    doc = base_nlp(text)          
    ents_food = ner(text)         

    # Collect selected spans from spaCy
    spans = [e for e in doc.ents if e.label_ in BASE_KEEP]

    # Collect FOOD spans
    for e in ents_food:
        if e.get("entity_group") == "FOOD":
            s, t = e["start"], e["end"]
            sp = doc.char_span(s, t, label="FOOD", alignment_mode="expand")
            if sp is not None:
                spans.append(sp)

    # Rebuild with placeholders
    spans = filter_spans(spans)
    spans = sorted(spans, key=lambda s: s.start_char)

    out, i = [], 0
    for s in spans:
        if s.start_char > i:
            out.append(text[i:s.start_char])
        out.append(PLACE.get(s.label_, "_MASK_"))
        i = s.end_char
    out.append(text[i:])
    return "".join(out)

# Apply masking function to the reviews
df["masked_for_lda"] = df["text_clean_ner"].fillna("").astype(str).map(mask_food_and_base)

# Quick check of the result
print(df.head(5))

# ========== OUTPUT ==========

#write csv
df[["review_id", "text_clean_ner", "masked_for_lda"]].to_csv(output_paths["reviews_ner_masked"], index=False)
print("✅ File saved to:", output_paths["reviews_ner_masked"])
print("Finished at", datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))