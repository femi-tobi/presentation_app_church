"""Exception hierarchy for the Presentations.AI SDK.

Mirrors the Node.js StructuredError with {code, message, remediation} pattern.
"""

from __future__ import annotations


class PresentationsAIError(Exception):
    """Base exception for all Presentations.AI SDK errors."""

    code: str | None
    remediation: str | None

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        remediation: str | None = None,
    ) -> None:
        self.message = message
        self.code = code
        self.remediation = remediation
        super().__init__(message)

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(code={self.code!r}, message={self.message!r})"


# ─── API Errors (HTTP response received) ─────────────────────


class APIError(PresentationsAIError):
    """API returned an error HTTP response."""

    status_code: int
    body: dict[str, object] | None

    def __init__(
        self,
        message: str,
        *,
        status_code: int,
        code: str | None = None,
        remediation: str | None = None,
        body: dict[str, object] | None = None,
    ) -> None:
        self.status_code = status_code
        self.body = body
        super().__init__(message, code=code, remediation=remediation)

    def __repr__(self) -> str:
        return (
            f"{self.__class__.__name__}("
            f"status_code={self.status_code}, code={self.code!r}, message={self.message!r})"
        )


class BadRequestError(APIError):
    """400 — Invalid request parameters."""


class AuthenticationError(APIError):
    """401 — Invalid or missing API key."""


class InsufficientCreditsError(APIError):
    """402 — Account has insufficient credits."""


class NotFoundError(APIError):
    """404 — Requested resource does not exist."""


class RateLimitError(APIError):
    """429 — Too many requests."""


class InternalServerError(APIError):
    """5xx — Server-side error."""


# ─── Transport Errors (no HTTP response) ─────────────────────


class APITimeoutError(PresentationsAIError):
    """Request timed out before receiving a response."""


class APIConnectionError(PresentationsAIError):
    """Could not connect to the API (DNS, TLS, network failure)."""

    cause: Exception | None

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        remediation: str | None = None,
        cause: Exception | None = None,
    ) -> None:
        self.cause = cause
        super().__init__(message, code=code, remediation=remediation)


# ─── Agent / MCP Errors ─────────────────────────────────────


class AgentError(PresentationsAIError):
    """Error from the Agent runtime (MCP connector, tool execution)."""


# ─── Status Code → Exception Mapping ─────────────────────────

_STATUS_CODE_MAP: dict[int, type[APIError]] = {
    400: BadRequestError,
    401: AuthenticationError,
    402: InsufficientCreditsError,
    404: NotFoundError,
    429: RateLimitError,
}

_ERROR_REMEDIATIONS: dict[int, str] = {
    400: (
        "Check the request parameters. Ensure topic is not empty, "
        "slideCount is 1-50, and exportType is valid."
    ),
    401: (
        "Verify your API key at console.presentations.ai/apiref/docs/. "
        'Ensure the Authorization header uses "Bearer <key>".'
    ),
    402: (
        "Your account has insufficient credits. "
        "Purchase more at console.presentations.ai or check your balance."
    ),
    404: "The requested resource was not found. Verify the ID or endpoint path.",
    429: "Too many requests. Wait before retrying.",
}

_ERROR_CODES: dict[int, str] = {
    400: "API_VALIDATION_FAILED",
    401: "API_UNAUTHORIZED",
    402: "API_INSUFFICIENT_CREDITS",
    404: "API_NOT_FOUND",
    429: "API_RATE_LIMITED",
}
