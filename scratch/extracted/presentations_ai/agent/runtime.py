"""Synchronous Agent runtime — Claude + MCP connector for presentation workflows."""

from __future__ import annotations

import re
from typing import Any

from presentations_ai._exceptions import AgentError, AuthenticationError
from presentations_ai.agent._system_prompt import AGENT_SYSTEM_PROMPT
from presentations_ai.agent.types import (
    AgentConfig,
    AgentMessage,
    AgentResponse,
    AgentToolCall,
    AgentUsage,
)

MCP_CONNECTOR_VERSION = "mcp-client-2025-11-20"


class AgentRuntime:
    """Synchronous Agent runtime that uses Claude + MCP to create presentations.

    Usage:
        agent = AgentRuntime(anthropic_api_key="sk-ant-...")
        response = agent.chat(
            "Create a 12-slide investor pitch deck",
            presentations_api_key="pai_...",
        )
        print(response.presentation_url)
    """

    def __init__(
        self,
        *,
        anthropic_api_key: str,
        mcp_server_url: str = "https://api.presentations.ai/mcp",
        model: str = "claude-sonnet-4-5-20250929",
        max_tokens: int = 4096,
        max_continuations: int = 5,
        system_prompt: str | None = None,
    ) -> None:
        if not anthropic_api_key:
            raise AuthenticationError(
                "anthropic_api_key is required",
                status_code=401,
                code="API_UNAUTHORIZED",
                remediation="Pass a valid Anthropic API key via the anthropic_api_key parameter.",
            )

        try:
            import anthropic
        except ImportError as exc:
            raise ImportError(
                "The 'anthropic' package is required for AgentRuntime. "
                "Install it with: pip install presentations-ai[agent]"
            ) from exc

        self._client = anthropic.Anthropic(api_key=anthropic_api_key)
        self._config = AgentConfig(
            anthropic_api_key=anthropic_api_key,
            mcp_server_url=mcp_server_url,
            model=model,
            max_tokens=max_tokens,
            max_continuations=max_continuations,
            system_prompt=system_prompt,
        )

    def chat(
        self,
        user_message: str,
        presentations_api_key: str,
        conversation_history: list[AgentMessage] | None = None,
    ) -> AgentResponse:
        """Send a message to the agent and get a response with presentation results.

        Args:
            user_message: The user's natural language request.
            presentations_api_key: Presentations.AI API key for MCP server auth.
            conversation_history: Optional prior messages for multi-turn conversations.
        """
        if not user_message or not user_message.strip():
            raise AgentError(
                "user_message must be a non-empty string",
                code="MCP_INVALID_INPUT",
                remediation="Pass a presentation request as the first argument to chat().",
            )

        if not presentations_api_key:
            raise AuthenticationError(
                "presentations_api_key is required for MCP server authentication",
                status_code=401,
                code="API_UNAUTHORIZED",
                remediation=(
                    "Pass a valid Presentations.AI API key (pai_xxx) "
                    "as the second argument."
                ),
            )

        # Build MCP server and toolset configuration
        mcp_server = {
            "type": "url",
            "url": self._config.mcp_server_url,
            "name": "presentations-ai",
            "authorization_token": presentations_api_key,
        }
        mcp_toolset = {
            "type": "mcp_toolset",
            "mcp_server_name": "presentations-ai",
        }

        # Build messages array
        messages: list[dict[str, Any]] = []
        if conversation_history:
            for m in conversation_history:
                messages.append({"role": m.role, "content": m.content})
        messages.append({"role": "user", "content": user_message})

        system_prompt = self._config.system_prompt or AGENT_SYSTEM_PROMPT

        # Track accumulated results across continuations
        all_tool_calls: list[AgentToolCall] = []
        total_input_tokens = 0
        total_output_tokens = 0
        final_text = ""
        stop_reason = ""

        # Continuation loop for pause_turn handling
        for _i in range(self._config.max_continuations + 1):
            try:
                raw_response = self._client.beta.messages.create(  # pyright: ignore[reportArgumentType]
                    model=self._config.model,
                    max_tokens=self._config.max_tokens,
                    system=system_prompt,
                    messages=messages,  # type: ignore[arg-type]
                    mcp_servers=[mcp_server],  # type: ignore[arg-type]
                    tools=[mcp_toolset],  # type: ignore[arg-type]
                    betas=[MCP_CONNECTOR_VERSION],
                )
            except Exception as e:
                raise AgentError(
                    f"Anthropic API call failed: {e}",
                    code="MCP_TOOL_EXECUTION_FAILED",
                    remediation=(
                        "Check your Anthropic API key and network connectivity. "
                        "The MCP server may also be unavailable."
                    ),
                ) from e

            # Extract from response (cast since MCP types aren't in SDK typings yet)
            response: Any = raw_response
            usage = getattr(response, "usage", None)
            total_input_tokens += getattr(usage, "input_tokens", 0)
            total_output_tokens += getattr(usage, "output_tokens", 0)
            stop_reason = getattr(response, "stop_reason", "") or ""

            # Process content blocks
            content_blocks = getattr(response, "content", [])
            for block in content_blocks:
                block_type = getattr(block, "type", "")

                if block_type == "text":
                    final_text += getattr(block, "text", "")

                elif block_type == "mcp_tool_use":
                    all_tool_calls.append(AgentToolCall(
                        tool_name=getattr(block, "name", ""),
                        server_name=getattr(block, "server_name", ""),
                        input=getattr(block, "input", {}),
                    ))

                elif block_type == "mcp_tool_result":
                    is_error = getattr(block, "is_error", False)
                    result_content = getattr(block, "content", [])
                    result_text = "\n".join(
                        getattr(c, "text", "")
                        for c in result_content
                        if getattr(c, "type", "") == "text"
                    )

                    # Match result to the last unfilled tool call
                    for tc in all_tool_calls:
                        if tc.result == "" and tc.tool_name:
                            tc.result = result_text
                            tc.is_error = is_error
                            break

            # If not pause_turn, we're done
            if stop_reason != "pause_turn":
                break

            # Continue: append assistant response to messages
            messages.append({
                "role": "assistant",
                "content": content_blocks,
            })

        # Extract presentation details from tool results
        extracted = _extract_presentation_details(all_tool_calls)

        return AgentResponse(
            text=final_text,
            tool_calls=all_tool_calls,
            stop_reason=stop_reason,
            usage=AgentUsage(
                input_tokens=total_input_tokens,
                output_tokens=total_output_tokens,
            ),
            **extracted,
        )


def _extract_presentation_details(
    tool_calls: list[AgentToolCall],
) -> dict[str, Any]:
    """Extract presentation URLs, IDs, and job IDs from tool call results."""
    for call in tool_calls:
        if call.is_error:
            continue
        result = call.result

        url_match = re.search(
            r"\*\*(?:Access|Document URL):\*\*\s*(https?://[^\s\n]+)", result
        )
        doc_id_match = re.search(r"\*\*Document ID:\*\*\s*(\d+)", result)
        animated_match = re.search(
            r"\*\*Animated(?: URL)?:\*\*\s*(https?://[^\s\n]+)", result
        )
        job_id_match = re.search(r"\*\*Job ID:\*\*\s*(\S+)", result)

        if url_match or doc_id_match or job_id_match:
            return {
                "presentation_url": url_match[1] if url_match else None,
                "document_id": int(doc_id_match[1]) if doc_id_match else None,
                "animated_url": animated_match[1] if animated_match else None,
                "job_id": job_id_match[1] if job_id_match else None,
            }

    return {}
