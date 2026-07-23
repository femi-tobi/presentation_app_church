"""Pydantic models for async job-related API responses."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict


class AsyncJobResponse(BaseModel):
    """Response when a presentation creation is queued as an async job."""

    model_config = ConfigDict(extra="ignore")

    job_id: str
    status: Literal["queued"]


class JobStatusResponse(BaseModel):
    """Response from polling an async job's status.

    Server contract (api-mcp/routes/restroutes.js:48-76):

    - Success: ``{status: 0, url, animated_url}`` or ``{status: 0, docid, docurl}``
    - Failed: ``{status: 1, error}``
    - In progress: ``{status: 1, message: "Document is being processed"}``
    """

    model_config = ConfigDict(extra="ignore")

    status: int
    message: str | None = None
    error: str | None = None
    poll_url: str | None = None
    url: str | None = None
    docid: int | None = None
    docurl: str | None = None
    animated_url: str | None = None


class ApiErrorResponse(BaseModel):
    """Error response from the API."""

    model_config = ConfigDict(extra="ignore")

    status: Literal[1]
    error: str
