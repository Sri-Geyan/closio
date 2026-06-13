import requests
import json
from sumy.parsers.plaintext import PlaintextParser
from sumy.nlp.tokenizers import Tokenizer
from sumy.summarizers.text_rank import TextRankSummarizer
import nltk
import os

# Download punkt tokeniser for sumy if not present
try:
    nltk.data.find('tokenizers/punkt')
    nltk.data.find('tokenizers/punkt_tab')
except LookupError:
    nltk.download('punkt')
    nltk.download('punkt_tab')

def summarise_text(text_block: str) -> list[str]:
    """
    Attempts to use HuggingFace Inference API for an abstractive summary.
    Falls back to local TextRank summarizer if it fails.
    """
    if not text_block or len(text_block.strip()) < 50:
        return ["Not enough conversation to summarise."]

    # Try Option A: HuggingFace API (BART large CNN)
    hf_token = os.getenv("HUGGINGFACE_API_KEY", "")
    if hf_token:
        try:
            API_URL = "https://api-inference.huggingface.co/models/facebook/bart-large-cnn"
            headers = {"Authorization": f"Bearer {hf_token}"}
            payload = {
                "inputs": text_block,
                "parameters": {"max_length": 100, "min_length": 30, "do_sample": False}
            }
            response = requests.post(API_URL, headers=headers, json=payload, timeout=5)
            if response.status_code == 200:
                summary = response.json()[0]['summary_text']
                # Convert paragraph into 3 bullet points
                sentences = [s.strip() for s in summary.split('.') if len(s.strip()) > 5]
                return [f"• {s}" for s in sentences[:3]]
        except Exception as e:
            print(f"HF API failed: {e}. Falling back to local summarizer.")

    # Option C: Local Fallback (TextRank via sumy)
    try:
        parser = PlaintextParser.from_string(text_block, Tokenizer("english"))
        summarizer = TextRankSummarizer()
        # Extract top 3 sentences
        summary_sentences = summarizer(parser.document, 3)
        return [f"• {str(s)}" for s in summary_sentences]
    except Exception as e:
        print(f"Local summarizer failed: {e}")
        return ["Could not generate summary."]
