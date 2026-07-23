"""Presentations.AI SDK type definitions."""

from presentations_ai.types.common import (
    ContentDocumentExportType,
    CreateFromContentParams,
    CreateFromFileParams,
    CreateFromRawContentParams,
    CreateFromTopicParams,
    CreateSingleSlideParams,
    ExportType,
    InstructionMode,
    RefreshPresentationParams,
    SlideContent,
    SlideUpdate,
    SlideUpdateAction,
    UpdateSlidesParams,
)
from presentations_ai.types.jobs import (
    ApiErrorResponse,
    AsyncJobResponse,
    JobStatusResponse,
)
from presentations_ai.types.presentations import (
    AuthenticateResponse,
    ContentDocumentResponse,
    PresentationResponse,
    RefreshPresentationResponse,
    SlideUpdateResponse,
)

__all__ = [
    # Literal types
    "ExportType",
    "ContentDocumentExportType",
    "InstructionMode",
    "SlideUpdateAction",
    # Slide types
    "SlideContent",
    "SlideUpdate",
    # Request params
    "CreateFromTopicParams",
    "CreateFromFileParams",
    "CreateSingleSlideParams",
    "CreateFromContentParams",
    "CreateFromRawContentParams",
    "UpdateSlidesParams",
    "RefreshPresentationParams",
    # Response models
    "PresentationResponse",
    "ContentDocumentResponse",
    "SlideUpdateResponse",
    "RefreshPresentationResponse",
    "AuthenticateResponse",
    "AsyncJobResponse",
    "JobStatusResponse",
    "ApiErrorResponse",
]
