"""Polling utilities for async job completion."""

from __future__ import annotations

import asyncio
import time
from collections.abc import Callable
from typing import TYPE_CHECKING

from presentations_ai._exceptions import AgentError, APITimeoutError
from presentations_ai.types.jobs import JobStatusResponse

if TYPE_CHECKING:
    from presentations_ai._async_client import AsyncPresentationsAI
    from presentations_ai._client import PresentationsAI

DEFAULT_INTERVAL_MS = 5_000
DEFAULT_MAX_ATTEMPTS = 60
DEFAULT_BACKOFF_MULTIPLIER = 1.2
MAX_INTERVAL_MS = 30_000


def poll_until_complete(
    client: PresentationsAI,
    job_id: str,
    *,
    interval_ms: int = DEFAULT_INTERVAL_MS,
    max_attempts: int = DEFAULT_MAX_ATTEMPTS,
    backoff_multiplier: float = DEFAULT_BACKOFF_MULTIPLIER,
    on_progress: Callable[[JobStatusResponse], None] | None = None,
) -> JobStatusResponse:
    """Poll check_job_status() until the job completes, fails, or times out.

    Success: response.status == 0
    Error: response.status == 1 AND message != "Document is being processed"
    Timeout: max_attempts exceeded
    """
    current_interval = interval_ms

    for _attempt in range(max_attempts):
        response = client.check_job_status(job_id)

        if on_progress is not None:
            on_progress(response)

        if response.status == 0:
            return response

        # Server contract (api-mcp/routes/restroutes.js:54-66): status:1 with `error` → failed,
        # status:1 without `error` → still processing.
        if response.status == 1 and response.error:
            raise AgentError(
                response.error,
                code="MCP_TOOL_EXECUTION_FAILED",
                remediation="The presentation generation job failed. Try creating a new one.",
            )

        time.sleep(current_interval / 1000.0)
        current_interval = min(
            current_interval * backoff_multiplier,
            MAX_INTERVAL_MS,
        )

    raise APITimeoutError(
        f"Job {job_id} did not complete within {max_attempts} poll attempts",
        code="JOB_POLL_TIMEOUT",
        remediation=(
            "The job is taking longer than expected. "
            "Use check_job_status to manually check later."
        ),
    )


async def async_poll_until_complete(
    client: AsyncPresentationsAI,
    job_id: str,
    *,
    interval_ms: int = DEFAULT_INTERVAL_MS,
    max_attempts: int = DEFAULT_MAX_ATTEMPTS,
    backoff_multiplier: float = DEFAULT_BACKOFF_MULTIPLIER,
    on_progress: Callable[[JobStatusResponse], None] | None = None,
) -> JobStatusResponse:
    """Async version of poll_until_complete."""
    current_interval = interval_ms

    for _attempt in range(max_attempts):
        response = await client.check_job_status(job_id)

        if on_progress is not None:
            on_progress(response)

        if response.status == 0:
            return response

        # Server contract (api-mcp/routes/restroutes.js:54-66): status:1 with `error` → failed,
        # status:1 without `error` → still processing.
        if response.status == 1 and response.error:
            raise AgentError(
                response.error,
                code="MCP_TOOL_EXECUTION_FAILED",
                remediation="The presentation generation job failed. Try creating a new one.",
            )

        await asyncio.sleep(current_interval / 1000.0)
        current_interval = min(
            current_interval * backoff_multiplier,
            MAX_INTERVAL_MS,
        )

    raise APITimeoutError(
        f"Job {job_id} did not complete within {max_attempts} poll attempts",
        code="JOB_POLL_TIMEOUT",
        remediation=(
            "The job is taking longer than expected. "
            "Use check_job_status to manually check later."
        ),
    )
