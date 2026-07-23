"""Agent runtime — Claude + MCP connector for Presentations.AI.

Requires: pip install presentations-ai[agent]
"""

from presentations_ai.agent._system_prompt import AGENT_SYSTEM_PROMPT
from presentations_ai.agent.async_runtime import AsyncAgentRuntime
from presentations_ai.agent.runtime import AgentRuntime
from presentations_ai.agent.types import (
    AgentConfig,
    AgentMessage,
    AgentResponse,
    AgentToolCall,
    AgentUsage,
)

__all__ = [
    "AgentRuntime",
    "AsyncAgentRuntime",
    "AGENT_SYSTEM_PROMPT",
    "AgentConfig",
    "AgentMessage",
    "AgentResponse",
    "AgentToolCall",
    "AgentUsage",
]
