"""Token budget utilities for content truncation.

Mirrors the Node.js shared/token-budget.ts implementation.
"""

from __future__ import annotations

import math

from presentations_ai._constants import (
    AVG_CHARS_PER_TOKEN,
    MAX_SAFE_CHARS,
    MAX_TOKENS,
    SAFETY_MARGIN,
)


def estimate_tokens(text: str) -> int:
    """Estimate the number of tokens in a text string."""
    return math.ceil(len(text) / AVG_CHARS_PER_TOKEN)


def truncate_to_token_budget(text: str, max_tokens: int = MAX_TOKENS) -> str:
    """Truncate text to fit within a token budget.

    If the text exceeds the budget, it is truncated and a notice is appended.
    """
    max_chars = int(max_tokens * AVG_CHARS_PER_TOKEN * SAFETY_MARGIN)
    if len(text) <= max_chars:
        return text
    return text[:max_chars] + "\n\n[Output truncated to fit token budget]"


def is_within_token_budget(text: str) -> bool:
    """Check if text fits within the default token budget."""
    return len(text) <= MAX_SAFE_CHARS
