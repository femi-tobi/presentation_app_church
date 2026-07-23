"""Default configuration constants for the Presentations.AI SDK."""

DEFAULT_BASE_URL = "https://api.presentations.ai"
DEFAULT_TIMEOUT_MS = 60_000

# Retry configuration (matching Node.js api-client)
DEFAULT_MAX_RETRIES = 3
DEFAULT_BASE_DELAY_MS = 1_000
DEFAULT_MAX_DELAY_MS = 30_000
RETRYABLE_STATUS_CODES = frozenset({429, 500, 502, 503, 504})

# Token budget constants (matching Node.js shared/token-budget)
AVG_CHARS_PER_TOKEN = 4
MAX_TOKENS = 25_000
SAFETY_MARGIN = 0.9
MAX_SAFE_CHARS = int(MAX_TOKENS * AVG_CHARS_PER_TOKEN * SAFETY_MARGIN)
