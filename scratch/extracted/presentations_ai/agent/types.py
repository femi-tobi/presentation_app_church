"""Type definitions for the Agent runtime."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class AgentConfig:
    """Configuration for the Agent runtime."""

    anthropic_api_key: str
    mcp_server_url: str = "https://api.presentations.ai/mcp"
    model: str = "claude-sonnet-4-5-20250929"
    max_tokens: int = 4096
    max_continuations: int = 5
    system_prompt: str | None = None


@dataclass
class AgentToolCall:
    """A single MCP tool call made during a agent conversation turn."""

    tool_name: str
    server_name: str
    input: dict[str, Any]
    result: str = ""
    is_error: bool = False


@dataclass
class AgentResponse:
    """Response from a agent chat() call."""

    text: str
    tool_calls: list[AgentToolCall]
    stop_reason: str
    usage: AgentUsage
    presentation_url: str | None = None
    document_id: int | None = None
    animated_url: str | None = None
    job_id: str | None = None


@dataclass
class AgentUsage:
    """Token usage for a agent conversation turn."""

    input_tokens: int = 0
    output_tokens: int = 0


@dataclass
class AgentMessage:
    """A message in a agent conversation history."""

    role: str  # "user" or "assistant"
    content: str
