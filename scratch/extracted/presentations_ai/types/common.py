"""Common types shared across the Presentations.AI SDK."""

from __future__ import annotations

from typing import Literal, TypedDict

from typing_extensions import Required

# ─── Enum-like Literal Types ─────────────────────────────────

ExportType = Literal["ppt", "pptx", "pdf", "image", "render", "share"]

# /api/v1/content/document does not transform exportType — it expects the raw internal
# names (api-mcp/routes/restroutes.js:864). Use this for that endpoint.
ContentDocumentExportType = Literal[
    "render", "exportToPpt", "exportToPdf", "exportToImage", "share"
]

InstructionMode = Literal["enhance", "preserve", "summarize", "instruction"]

# ─── Structured Slide Types (used in request bodies) ─────────


class SlideContent(TypedDict):
    """A slide for /api/v1/content/document.

    Server expects `{title, section}` (validated strictly by the MCP schema for the same
    function: api-mcp/mcp/schemas/tool-schemas.js:6-15).
    """

    title: str
    section: str


SlideUpdateAction = Literal["update", "add", "delete"]


class SlideUpdate(TypedDict):
    """An update operation for /api/v1/document/slide."""

    action: Required[SlideUpdateAction]
    slide_content: Required[str]
    index: Required[int]


# ─── Request Parameter Types (TypedDict) ─────────────────────


class CreateFromTopicParams(TypedDict, total=False):
    topic: Required[str]
    export_type: Required[ExportType]
    slide_count: int
    language: str
    domain: str
    target_audience: str
    tone: str
    callback_url: str
    immediate_poll_url: bool


class CreateFromFileParams(TypedDict, total=False):
    file: Required[bytes]
    file_name: Required[str]
    export_type: Required[ExportType]
    topic: str
    slide_count: int
    language: str
    domain: str
    instruction: InstructionMode
    instructions: str
    target_audience: str
    tone: str
    callback_url: str
    immediate_poll_url: bool


# /api/v1/topic/singleslide does not accept `export_type` or `slide_count`
# (api-mcp/routes/restroutes.js:488-554).
class CreateSingleSlideParams(TypedDict, total=False):
    topic: Required[str]
    language: str
    domain: str
    target_audience: str
    tone: str
    callback_url: str
    immediate_poll_url: bool


class CreateFromContentParams(TypedDict, total=False):
    name: Required[str]
    slides: Required[list[SlideContent]]
    type: str
    domain: str
    export_type: ContentDocumentExportType


class CreateFromRawContentParams(TypedDict, total=False):
    content: Required[str]
    export_type: Required[ExportType]
    topic: str
    slide_count: int
    language: str
    domain: str
    instruction: InstructionMode
    instructions: str
    target_audience: str
    tone: str
    callback_url: str
    immediate_poll_url: bool


class UpdateSlidesParams(TypedDict):
    doc_id: int
    slides: list[SlideUpdate]


class RefreshPresentationParams(TypedDict, total=False):
    docid: Required[str]
    file: bytes
    file_name: str
