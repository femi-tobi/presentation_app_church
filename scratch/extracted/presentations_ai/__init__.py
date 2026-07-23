"""Presentations.AI Python SDK.

Create, transform, and manage presentations programmatically.

Usage:
    from presentations_ai import PresentationsAI

    client = PresentationsAI(api_key="pai_...")
    result = client.create_from_topic(topic="Q4 Strategy", export_type="pptx")
    print(result.docurl)
"""

from presentations_ai._async_client import AsyncPresentationsAI
from presentations_ai._client import PresentationsAI
from presentations_ai._exceptions import (
    AgentError,
    APIConnectionError,
    APIError,
    APITimeoutError,
    AuthenticationError,
    BadRequestError,
    InsufficientCreditsError,
    InternalServerError,
    NotFoundError,
    PresentationsAIError,
    RateLimitError,
)
from presentations_ai._polling import async_poll_until_complete, poll_until_complete
from presentations_ai._token_budget import (
    estimate_tokens,
    is_within_token_budget,
    truncate_to_token_budget,
)
from presentations_ai._version import __version__

__all__ = [
    # Clients
    "PresentationsAI",
    "AsyncPresentationsAI",
    # Errors
    "PresentationsAIError",
    "APIError",
    "BadRequestError",
    "AuthenticationError",
    "InsufficientCreditsError",
    "NotFoundError",
    "RateLimitError",
    "InternalServerError",
    "APITimeoutError",
    "APIConnectionError",
    "AgentError",
    # Polling
    "poll_until_complete",
    "async_poll_until_complete",
    # Token budget
    "estimate_tokens",
    "truncate_to_token_budget",
    "is_within_token_budget",
    # Version
    "__version__",
]
