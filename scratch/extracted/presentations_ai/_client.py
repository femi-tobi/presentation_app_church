"""Synchronous client for the Presentations.AI REST API."""

from __future__ import annotations

import json  # noqa: F401 -- used by the disabled create_from_content method below
from collections.abc import Callable
from typing import Any, TypeVar

import httpx

from presentations_ai._base_client import (
    _build_headers,
    _build_json_body,
    _request_with_retry,
    _resolve_api_key,
    _resolve_base_url,
)
from presentations_ai._constants import DEFAULT_MAX_RETRIES, DEFAULT_TIMEOUT_MS
from presentations_ai._exceptions import BadRequestError
from presentations_ai.types.common import (
    ContentDocumentExportType,  # noqa: F401 -- used by the disabled create_from_content method
    ExportType,
    InstructionMode,
    SlideContent,  # noqa: F401 -- used by the disabled create_from_content method
)
from presentations_ai.types.jobs import AsyncJobResponse, JobStatusResponse
from presentations_ai.types.presentations import (
    AuthenticateResponse,
    ContentDocumentResponse,
    PresentationResponse,
    RefreshPresentationResponse,
    SlideUpdateResponse,
)


class PresentationsAI:
    """Synchronous client for the Presentations.AI REST API.

    Usage:
        client = PresentationsAI(api_key="pai_...")
        result = client.create_from_topic(topic="Q4 Strategy", export_type="pptx")
    """

    def __init__(
        self,
        api_key: str | None = None,
        *,
        base_url: str | None = None,
        timeout_ms: int = DEFAULT_TIMEOUT_MS,
        max_retries: int = DEFAULT_MAX_RETRIES,
    ) -> None:
        self._api_key = _resolve_api_key(api_key)
        self._base_url = _resolve_base_url(base_url)
        self._timeout_ms = timeout_ms
        self._max_retries = max_retries
        self._client = httpx.Client(base_url=self._base_url)

    def close(self) -> None:
        """Close the underlying HTTP client."""
        self._client.close()

    def __enter__(self) -> PresentationsAI:
        return self

    def __exit__(self, *args: object) -> None:
        self.close()

    # ─── Deck Creation ───────────────────────────────────────

    def create_from_topic(
        self,
        *,
        topic: str,
        export_type: ExportType,
        slide_count: int | None = None,
        language: str | None = None,
        domain: str | None = None,
        target_audience: str | None = None,
        tone: str | None = None,
        callback_url: str | None = None,
        immediate_poll_url: bool | None = None,
    ) -> PresentationResponse | AsyncJobResponse:
        """Create a presentation from a topic description.

        POST /api/v1/topic/document
        """
        self._validate_topic(topic)
        self._validate_slide_count(slide_count)

        body = _build_json_body({
            "topic": topic,
            "export_type": export_type,
            "slide_count": slide_count,
            "language": language,
            "domain": domain,
            "target_audience": target_audience,
            "tone": tone,
            "callback_url": callback_url,
            "immediate_poll_url": immediate_poll_url,
        })
        return self._post_json("/api/v1/topic/document", body, _presentation_or_job)

    def create_from_file(
        self,
        *,
        file: bytes,
        file_name: str,
        export_type: ExportType,
        topic: str | None = None,
        slide_count: int | None = None,
        language: str | None = None,
        domain: str | None = None,
        instruction: InstructionMode | None = None,
        instructions: str | None = None,
        target_audience: str | None = None,
        tone: str | None = None,
        callback_url: str | None = None,
        immediate_poll_url: bool | None = None,
    ) -> PresentationResponse | AsyncJobResponse:
        """Create a presentation from an uploaded file (max 25MB).

        POST /api/v1/document/file (multipart/form-data).

        The wire field is ``instruction`` (api-mcp/routes/restroutes.js:965), with allowed
        values enhance/preserve/summarize/instruction. ``instructions`` (plural) carries
        custom directions when ``instruction='instruction'``.
        """
        self._validate_slide_count(slide_count)

        data: dict[str, str] = {"exportType": export_type}
        if topic is not None:
            data["topic"] = topic
        if slide_count is not None:
            data["slideCount"] = str(slide_count)
        if language is not None:
            data["language"] = language
        if domain is not None:
            data["domain"] = domain
        if instruction is not None:
            data["instruction"] = instruction
        if instructions is not None:
            data["instructions"] = instructions
        if target_audience is not None:
            data["targetAudience"] = target_audience
        if tone is not None:
            data["tone"] = tone
        if callback_url is not None:
            data["callback_url"] = callback_url
        if immediate_poll_url:
            data["immediatePollUrl"] = "true"

        files = {"file": (file_name, file, "application/octet-stream")}
        return self._post_form("/api/v1/document/file", data, files, _presentation_or_job)

    def create_single_slide(
        self,
        *,
        topic: str,
        language: str | None = None,
        domain: str | None = None,
        target_audience: str | None = None,
        tone: str | None = None,
        callback_url: str | None = None,
        immediate_poll_url: bool | None = None,
    ) -> PresentationResponse | AsyncJobResponse:
        """Create a single-slide presentation (always returns an image).

        POST /api/v1/topic/singleslide.

        The server does not accept ``export_type`` or ``slide_count`` for this endpoint
        (api-mcp/routes/restroutes.js:488-554).
        """
        self._validate_topic(topic)

        body = _build_json_body({
            "topic": topic,
            "language": language,
            "domain": domain,
            "target_audience": target_audience,
            "tone": tone,
            "callback_url": callback_url,
            "immediate_poll_url": immediate_poll_url,
        })
        return self._post_json("/api/v1/topic/singleslide", body, _presentation_or_job)

    # Disabled — ``create_from_content`` (MCP tool ``create_document_from_content``)
    # is currently inactive. It overlaps with ``create_from_raw_content`` and only
    # returned a private editor URL with no exportType / share. Re-enable once a
    # clearly distinct use case is reintroduced.
    '''
    def create_from_content(
        self,
        *,
        name: str,
        slides: list[SlideContent],
        type: str | None = None,
        domain: str | None = None,
        export_type: ContentDocumentExportType | None = None,
    ) -> ContentDocumentResponse:
        """Create a presentation from structured slide content.

        POST /api/v1/content/document.

        Each slide must use the ``{title, section}`` shape — the server's
        createPresentationFromSlides function expects ``section`` (validated by the
        matching MCP schema in api-mcp/mcp/schemas/tool-schemas.js).
        """
        body: dict[str, Any] = {
            "name": name,
            "slides": json.dumps(slides),
            "type": type or "ideatodeck",
        }
        if domain is not None:
            body["domain"] = domain
        if export_type is not None:
            # Endpoint passes through without transform — needs raw internal values
            # (render / exportToPpt / exportToPdf / exportToImage / share).
            body["exportType"] = export_type

        return self._post_json("/api/v1/content/document", body, _parse_content_document)
    '''

    def create_from_raw_content(
        self,
        *,
        content: str,
        export_type: ExportType,
        topic: str | None = None,
        slide_count: int | None = None,
        language: str | None = None,
        domain: str | None = None,
        instruction: InstructionMode | None = None,
        instructions: str | None = None,
        target_audience: str | None = None,
        tone: str | None = None,
        callback_url: str | None = None,
        immediate_poll_url: bool | None = None,
    ) -> PresentationResponse | AsyncJobResponse:
        """Create a presentation from raw text content.

        POST /api/v1/document/content.

        Wire field is ``instruction`` (api-mcp/routes/restroutes.js:1315).
        """
        if not content or not content.strip():
            raise BadRequestError(
                "content must be a non-empty string",
                status_code=400,
                code="API_VALIDATION_FAILED",
                remediation="Provide the raw text content to transform into a presentation.",
            )
        self._validate_slide_count(slide_count)

        body = _build_json_body({
            "content": content,
            "export_type": export_type,
            "topic": topic,
            "slide_count": slide_count,
            "language": language,
            "domain": domain,
            "instruction": instruction,
            "instructions": instructions,
            "target_audience": target_audience,
            "tone": tone,
            "callback_url": callback_url,
            "immediate_poll_url": immediate_poll_url,
        })
        return self._post_json("/api/v1/document/content", body, _presentation_or_job)

    # Disabled — slide updates are temporarily unavailable while the underlying
    # flow is validated end-to-end. The slides argument shape (action / index /
    # slideContent) is being tightened. Re-enable once the structured-array
    # schema lands and the full update flow has been tested against the REST API.
    '''
    def update_slides(
        self,
        *,
        doc_id: int,
        slides: list[SlideUpdate],
    ) -> SlideUpdateResponse:
        """Update slides in an existing presentation.

        POST /api/v1/document/slide

        Note: slides are JSON-stringified in the request body (matching Node.js behavior).
        """
        body: dict[str, Any] = {
            "docId": doc_id,
            "slides": json.dumps(slides),
        }
        return self._post_json("/api/v1/document/slide", body, _parse_slide_update)
    '''

    # ─── Authentication & Refresh ────────────────────────────

    def authenticate(self) -> AuthenticateResponse:
        """Verify the API key is valid.

        GET /api/v1/authenticate
        """
        response = _request_with_retry(
            self._client,
            "GET",
            "/api/v1/authenticate",
            max_retries=self._max_retries,
            timeout_ms=self._timeout_ms,
            headers=_build_headers(self._api_key),
        )
        return AuthenticateResponse.model_validate(response.json())

    # Disabled — the full refresh flow (with and without a replacement file)
    # has not been validated end-to-end yet. Re-enable after functional testing
    # confirms correct behavior across both REST and MCP paths.
    '''
    def refresh_presentation(
        self,
        *,
        docid: str,
        file: bytes | None = None,
        file_name: str | None = None,
    ) -> RefreshPresentationResponse:
        """Regenerate an existing presentation, optionally with a new source file.

        POST /api/v1/document/refresh.

        The wire field is lowercase ``docid`` (api-mcp/routes/restroutes.js:1728).
        File limit: 25MB.
        """
        if not docid or not docid.strip():
            raise BadRequestError(
                "docid must be a non-empty string",
                status_code=400,
                code="API_VALIDATION_FAILED",
                remediation="Pass the document ID of the presentation to regenerate.",
            )

        if file is not None:
            data = {"docid": docid}
            files = {"file": (file_name or "source", file, "application/octet-stream")}
            return self._post_form(
                "/api/v1/document/refresh", data, files, _parse_refresh_presentation
            )
        return self._post_json(
            "/api/v1/document/refresh", {"docid": docid}, _parse_refresh_presentation
        )
    '''

    # ─── Job Polling ─────────────────────────────────────────

    def check_job_status(self, job_id: str) -> JobStatusResponse:
        """Check the status of an async job.

        GET /api/v1/polljob/{job_id}
        """
        response = _request_with_retry(
            self._client,
            "GET",
            f"/api/v1/polljob/{job_id}",
            max_retries=self._max_retries,
            timeout_ms=self._timeout_ms,
            headers=_build_headers(self._api_key),
        )
        return JobStatusResponse.model_validate(response.json())

    # ─── Input Validation ────────────────────────────────────

    @staticmethod
    def _validate_topic(topic: str) -> None:
        if not topic or not topic.strip():
            raise BadRequestError(
                "topic must be a non-empty string",
                status_code=400,
                code="API_VALIDATION_FAILED",
                remediation="Provide a presentation topic (1-500 characters).",
            )

    @staticmethod
    def _validate_slide_count(slide_count: int | None) -> None:
        if slide_count is not None and (
            not isinstance(slide_count, int)  # type: ignore[reportUnnecessaryIsInstance]
            or slide_count < 1
            or slide_count > 50
        ):
            raise BadRequestError(
                f"slide_count must be an integer between 1 and 50, got {slide_count}",
                status_code=400,
                code="API_VALIDATION_FAILED",
                remediation="Set slide_count to a whole number between 1 and 50, or omit it.",
            )

    # ─── HTTP Helpers ────────────────────────────────────────

    def _post_json(
        self,
        path: str,
        body: dict[str, Any],
        parser: _Parser[T],
    ) -> T:
        response = _request_with_retry(
            self._client,
            "POST",
            path,
            max_retries=self._max_retries,
            timeout_ms=self._timeout_ms,
            headers={**_build_headers(self._api_key), "Content-Type": "application/json"},
            json_body=body,
        )
        return parser(response.json())

    def _post_form(
        self,
        path: str,
        data: dict[str, str],
        files: dict[str, Any],
        parser: _Parser[T],
    ) -> T:
        response = _request_with_retry(
            self._client,
            "POST",
            path,
            max_retries=self._max_retries,
            timeout_ms=self._timeout_ms,
            headers=_build_headers(self._api_key),
            files=files,
            data=data,
        )
        return parser(response.json())


# ─── Response Parsers ────────────────────────────────────────

T = TypeVar("T")
_Parser = Callable[[dict[str, Any]], T]


def _presentation_or_job(data: dict[str, Any]) -> PresentationResponse | AsyncJobResponse:
    """Parse response as either a presentation or an async job."""
    if "job_id" in data:
        return AsyncJobResponse.model_validate(data)
    return PresentationResponse.model_validate(data)


def _parse_content_document(data: dict[str, Any]) -> ContentDocumentResponse:
    return ContentDocumentResponse.model_validate(data)


def _parse_slide_update(data: dict[str, Any]) -> SlideUpdateResponse:
    return SlideUpdateResponse.model_validate(data)


def _parse_refresh_presentation(data: dict[str, Any]) -> RefreshPresentationResponse:
    return RefreshPresentationResponse.model_validate(data)
