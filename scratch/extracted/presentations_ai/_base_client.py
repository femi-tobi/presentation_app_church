"""Shared base client logic: headers, serialization, retry, error mapping."""

from __future__ import annotations

import json
import math
import os
import random
import time
from typing import Any

import httpx

from presentations_ai._constants import (
    DEFAULT_BASE_DELAY_MS,
    DEFAULT_BASE_URL,
    DEFAULT_MAX_DELAY_MS,
    DEFAULT_MAX_RETRIES,
    DEFAULT_TIMEOUT_MS,
    RETRYABLE_STATUS_CODES,
)
from presentations_ai._exceptions import (
    _ERROR_CODES,
    _ERROR_REMEDIATIONS,
    _STATUS_CODE_MAP,
    APIConnectionError,
    APIError,
    APITimeoutError,
    InternalServerError,
)

# Keys that the REST API already expects in snake_case
_SNAKE_CASE_API_KEYS = frozenset({"callback_url", "animated_url", "job_id", "poll_url"})


def _snake_to_camel(key: str) -> str:
    """Convert a snake_case key to camelCase, unless the API expects snake_case."""
    if key in _SNAKE_CASE_API_KEYS:
        return key
    parts = key.split("_")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def _build_json_body(params: dict[str, Any]) -> dict[str, Any]:
    """Convert snake_case param dict to camelCase JSON body, dropping None values."""
    return {_snake_to_camel(k): v for k, v in params.items() if v is not None}


def _build_headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
    }


def _resolve_api_key(api_key: str | None) -> str:
    """Resolve API key from argument or environment variable."""
    key = api_key or os.environ.get("PRESENTATIONS_AI_API_KEY")
    if not key:
        from presentations_ai._exceptions import AuthenticationError

        raise AuthenticationError(
            "API key is required",
            status_code=401,
            code="API_UNAUTHORIZED",
            remediation=(
                "Set PRESENTATIONS_AI_API_KEY environment variable "
                "or pass api_key to the constructor."
            ),
        )
    return key


def _resolve_base_url(base_url: str | None) -> str:
    """Resolve base URL from argument or environment variable."""
    url = base_url or os.environ.get("PRESENTATIONS_AI_BASE_URL") or DEFAULT_BASE_URL
    return url.rstrip("/")


def _map_http_error(status: int, body_text: str) -> APIError:
    """Map an HTTP error status to the appropriate exception."""
    # Try to parse the error body
    parsed_body: dict[str, object] | None = None
    error_message: str
    try:
        parsed_body = json.loads(body_text)
        if isinstance(parsed_body, dict):
            error_message = str(
                parsed_body.get("error", f"API returned HTTP {status}")
            )
        else:
            error_message = body_text or f"API returned HTTP {status}"
    except (json.JSONDecodeError, AttributeError):
        error_message = body_text or f"API returned HTTP {status}"

    exc_class = _STATUS_CODE_MAP.get(status)
    if exc_class is None:
        exc_class = InternalServerError if status >= 500 else APIError

    code = _ERROR_CODES.get(status, "API_SERVER_ERROR")
    remediation = _ERROR_REMEDIATIONS.get(
        status,
        "An unexpected server error occurred. Contact support@presentations.ai.",
    )

    return exc_class(
        error_message,
        status_code=status,
        code=code,
        remediation=remediation,
        body=parsed_body,
    )


def _calculate_retry_delay(
    attempt: int,
    base_delay_ms: int = DEFAULT_BASE_DELAY_MS,
    max_delay_ms: int = DEFAULT_MAX_DELAY_MS,
) -> float:
    """Calculate retry delay in seconds with exponential backoff + jitter."""
    delay_ms = base_delay_ms * math.pow(2, attempt) + random.random() * 1000
    delay_ms = min(delay_ms, max_delay_ms)
    return delay_ms / 1000.0


def _should_retry(error: Exception) -> bool:
    """Determine if an error is retryable."""
    if isinstance(error, APIError):
        return error.status_code in RETRYABLE_STATUS_CODES
    return bool(isinstance(error, APITimeoutError | APIConnectionError))


# ─── Sync Retry Wrapper ──────────────────────────────────────


def _request_with_retry(
    client: httpx.Client,
    method: str,
    url: str,
    *,
    max_retries: int = DEFAULT_MAX_RETRIES,
    timeout_ms: int = DEFAULT_TIMEOUT_MS,
    headers: dict[str, str] | None = None,
    json_body: dict[str, Any] | None = None,
    files: dict[str, Any] | None = None,
    data: dict[str, str] | None = None,
) -> httpx.Response:
    """Make an HTTP request with retry logic."""
    last_error: Exception = RuntimeError("No attempts executed")
    timeout_s = timeout_ms / 1000.0

    for attempt in range(max_retries + 1):
        try:
            kwargs: dict[str, Any] = {"headers": headers, "timeout": timeout_s}
            if json_body is not None:
                kwargs["json"] = json_body
            if files is not None:
                kwargs["files"] = files
            if data is not None:
                kwargs["data"] = data

            response = client.request(method, url, **kwargs)

            if response.is_success:
                return response

            error = _map_http_error(response.status_code, response.text)
            if attempt < max_retries and _should_retry(error):
                time.sleep(_calculate_retry_delay(attempt))
                continue
            raise error

        except httpx.TimeoutException as e:
            last_error = APITimeoutError(
                f"Request to {url} timed out after {timeout_ms}ms",
                code="API_TIMEOUT",
                remediation=(
                    "Use callback_url for async processing or increase timeout. "
                    "Long-running jobs can be polled via check_job_status."
                ),
            )
            if attempt < max_retries:
                time.sleep(_calculate_retry_delay(attempt))
                continue
            raise last_error from e

        except httpx.ConnectError as e:
            last_error = APIConnectionError(
                f"Could not connect to {url}: {e}",
                code="API_SERVER_ERROR",
                remediation="Check your network connection and try again.",
                cause=e,
            )
            if attempt < max_retries:
                time.sleep(_calculate_retry_delay(attempt))
                continue
            raise last_error from e

        except (APIError, APITimeoutError, APIConnectionError):
            raise

        except httpx.HTTPError as e:
            last_error = APIConnectionError(
                f"HTTP error: {e}",
                code="API_SERVER_ERROR",
                remediation="An unexpected error occurred. Try again.",
                cause=e,
            )
            raise last_error from e

    raise last_error


# ─── Async Retry Wrapper ─────────────────────────────────────


async def _async_request_with_retry(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    *,
    max_retries: int = DEFAULT_MAX_RETRIES,
    timeout_ms: int = DEFAULT_TIMEOUT_MS,
    headers: dict[str, str] | None = None,
    json_body: dict[str, Any] | None = None,
    files: dict[str, Any] | None = None,
    data: dict[str, str] | None = None,
) -> httpx.Response:
    """Make an async HTTP request with retry logic."""
    import asyncio

    last_error: Exception = RuntimeError("No attempts executed")
    timeout_s = timeout_ms / 1000.0

    for attempt in range(max_retries + 1):
        try:
            kwargs: dict[str, Any] = {"headers": headers, "timeout": timeout_s}
            if json_body is not None:
                kwargs["json"] = json_body
            if files is not None:
                kwargs["files"] = files
            if data is not None:
                kwargs["data"] = data

            response = await client.request(method, url, **kwargs)

            if response.is_success:
                return response

            error = _map_http_error(response.status_code, response.text)
            if attempt < max_retries and _should_retry(error):
                await asyncio.sleep(_calculate_retry_delay(attempt))
                continue
            raise error

        except httpx.TimeoutException as e:
            last_error = APITimeoutError(
                f"Request to {url} timed out after {timeout_ms}ms",
                code="API_TIMEOUT",
                remediation=(
                    "Use callback_url for async processing or increase timeout. "
                    "Long-running jobs can be polled via check_job_status."
                ),
            )
            if attempt < max_retries:
                await asyncio.sleep(_calculate_retry_delay(attempt))
                continue
            raise last_error from e

        except httpx.ConnectError as e:
            last_error = APIConnectionError(
                f"Could not connect to {url}: {e}",
                code="API_SERVER_ERROR",
                remediation="Check your network connection and try again.",
                cause=e,
            )
            if attempt < max_retries:
                await asyncio.sleep(_calculate_retry_delay(attempt))
                continue
            raise last_error from e

        except (APIError, APITimeoutError, APIConnectionError):
            raise

        except httpx.HTTPError as e:
            last_error = APIConnectionError(
                f"HTTP error: {e}",
                code="API_SERVER_ERROR",
                remediation="An unexpected error occurred. Try again.",
                cause=e,
            )
            raise last_error from e

    raise last_error
