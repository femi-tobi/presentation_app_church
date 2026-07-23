"""Pydantic models for presentation-related API responses.

The server returns three different shapes depending on the request — see
api-mcp/util/doccreation.js around `createPresentationFromSlides` (line 2491+) and the
route handlers' immediatePollUrl / 5-minute fallback branches:

- For exportType `ppt`/`pptx`/`pdf`/`image`: ``{status, url, animated_url}``
- For exportType `render` / `share`: ``{status, docid, docurl}``
- When ``immediate_poll_url=True`` or sync timeout: ``{status: 1, pollUrl}``
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class PresentationResponse(BaseModel):
    """Response from creating a presentation. Uses optional fields to cover all shapes.

    To check which shape was returned, look at which fields are populated:

    - ``url`` set → exported file (ppt/pptx/pdf/image)
    - ``docid`` and ``docurl`` set → render or share
    - ``poll_url`` set → request fired async, use poll_until_complete()
    """

    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    status: int
    url: str | None = None
    animated_url: str | None = None
    docid: int | None = None
    docurl: str | None = None
    poll_url: str | None = None


class ContentDocumentResponse(BaseModel):
    """Response from POST /api/v1/content/document."""

    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    status: int
    message: str | None = None
    msg: str | None = None
    docurl: str | None = None
    docid: int | None = None
    url: str | None = None
    animated_url: str | None = None
    insertid: int | None = None


class SlideUpdateResponse(BaseModel):
    """Response from POST /api/v1/document/slide.

    Server returns ``{status, msg, insertid, docurl}`` — see
    api-mcp/mcp/handlers/tools.js:596 and the docs.
    """

    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    status: int
    msg: str | None = None
    message: str | None = None
    insertid: str | None = None
    docurl: str | None = None


class RefreshPresentationResponse(BaseModel):
    """Response from POST /api/v1/document/refresh."""

    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    status: int
    message: str | None = None
    docId: int | None = None  # noqa: N815 - server returns this exact casing
    meta_id: str | None = None


class AuthenticateResponse(BaseModel):
    """Response from GET /api/v1/authenticate."""

    model_config = ConfigDict(extra="ignore")

    status: int
    message: str
