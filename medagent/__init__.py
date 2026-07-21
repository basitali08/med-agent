"""MED AGENT — multi-agent, privacy-aware health decision-support pipeline.

Agents 1 (History Extractor), 2 (Clinical Summarizer), 3 (Multi-Specialty Analyst),
4 (Action & Treatment Recommender), validated by a Supervisor layer. Runs on a local
Ollama instance (e.g. qwen2.5:1.5b).

NOT a medical device. Every output is decision-support requiring physician review.

Run the CLI with:  python -m medagent.pipeline --input "..."
"""

__version__ = "0.1.0"
