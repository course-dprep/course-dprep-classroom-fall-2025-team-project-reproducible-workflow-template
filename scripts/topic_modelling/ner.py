import spacy
from spacy.util import filter_spans

# === Data handling ===
import pandas as pd
from pathlib import Path

# === Loading in the dataset
project_root = Path(__file__).resolve().parents[2]
csv_path_in = project_root / "data" / "training_data" / "reviews_python_in.csv"
csv_path_out = project_root / "data" / "training_data" / "reviews_after_ner.csv"

df = pd.read_csv(csv_path_in, usecols=["review_id", "text"])

# load base NER (ORG, GPE, LOC, FAC)
base_nlp = spacy.load("en_core_web_md")

# === FOOD NER via Transformers ===
from transformers import AutoTokenizer, AutoModelForTokenClassification, pipeline

model_id = "Dizex/InstaFoodRoBERTa-NER"
tok = AutoTokenizer.from_pretrained(model_id)
mdl = AutoModelForTokenClassification.from_pretrained(model_id)

ner = pipeline("token-classification", model=mdl, tokenizer=tok, aggregation_strategy="simple")

# === Combined masking function ===
PLACE = {
    "FOOD":"_FOOD_",
    "ORG":"_RESTAURANT_",
    "GPE":"_LOCATION_",
    "LOC":"_LOCATION_",
    "FAC":"_LOCATION_"
}
BASE_KEEP = {"ORG","GPE","LOC","FAC"}

def mask_food_and_base(text: str) -> str:
    if not isinstance(text, str) or not text:
        return "" if text is None else str(text)

    # run BOTH on the same original text
    doc = base_nlp(text)          
    ents_food = ner(text)         

    # collect spans from spaCy
    spans = [e for e in doc.ents if e.label_ in BASE_KEEP]

    # collect FOOD spans from HF (convert offsets → spaCy spans)
    for e in ents_food:
        if e.get("entity_group") == "FOOD":
            s, t = e["start"], e["end"]
            sp = doc.char_span(s, t, label="FOOD", alignment_mode="expand")
            if sp is not None:
                spans.append(sp)

    # resolve overlaps (keep longest), rebuild with placeholders
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

# === Apply to your DataFrame ===
df["masked_for_lda"] = df["text"].fillna("").astype(str).map(mask_food_and_base)

#quick check of the result
print(df.head(5))

#write csv
df[["review_id", "text", "masked_for_lda"]].to_csv(csv_path_out, index=False)
print("✅ File saved to:", csv_path_out)

import datetime
print("Finished at", datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))