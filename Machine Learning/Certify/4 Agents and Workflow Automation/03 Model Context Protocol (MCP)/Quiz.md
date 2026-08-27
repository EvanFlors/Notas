## Quiz: Model Context Protocol (MCP)
Model Context Protocol (MCP)
Your team has built custom integrations for GitHub, security scanners, and coverage services for your code review agent. Each integration took weeks to build and maintain. Now you need to add GitLab support, switch security scanners, and share tools with other teams. You want to standardize on MCP to eliminate duplicate integration work and enable tool interoperability across different agents and systems.


What problem does the Model Context Protocol (MCP) solve in agent development?

MCP makes agents faster by reducing API call latency

MCP provides a universal protocol for connecting agents to tools and data sources, eliminating the need for custom integrations for each tool

MCP replaces language models with more efficient reasoning engines

MCP simplifies prompt engineering for agents
In the MCP architecture, what is the role of an MCP server versus an MCP client?

Servers consume capabilities and clients expose them

Servers expose capabilities (tools and resources) to agents, while clients connect to servers and make those capabilities available to agents

Servers and clients are interchangeable terms for the same component

Servers handle LLM reasoning and clients execute tools
Correct Answer!
Servers implement the MCP protocol to expose tools/resources. Clients connect to servers and present capabilities to agents.

What is the difference between MCP tools and MCP resources?

Tools are read-only and resources are write-only

Tools are functions the agent can invoke to perform actions, while resources are data sources the agent can read and reference

Tools are provided by clients and resources are provided by servers

There is no difference; tools and resources are the same concept
Correct Answer!
Tools are executable functions (like get_pr_details). Resources are data the agent can access (like PR diff content).

When building an MCP server, what does a tool handler function need to return?

A raw Python dictionary with the result data

A list of TextContent objects containing the structured result, typically JSON-serialized

A string directly containing the result

Nothing; tool handlers modify global state instead of returning values
Correct Answer!
MCP tool handlers return TextContent objects (often with JSON-serialized data) that follow the protocol format.

Why does an MCP client manager pattern help when connecting to multiple specialized servers?

It reduces the number of API calls needed by batching requests

It aggregates capabilities from multiple servers and presents a unified interface, allowing agents to use tools from different servers without knowing which server provides each tool

It automatically retries failed tool calls across different servers

It caches tool results to improve performance
Correct Answer!
Client managers connect to multiple servers, discover their tools, and route calls appropriately, giving agents a unified interface.

When you switch from a custom GitHub integration to a GitHub MCP server, what is the main benefit for your agent code?

The agent code becomes faster because MCP is more efficient than custom integrations

The agent code doesn't need to change; it can use the same MCP client interface to connect to any MCP-compatible server, making it easy to swap tools or add new capabilities

The agent code becomes simpler because MCP eliminates the need for error handling

The agent code can now use multiple language models simultaneously
Correct Answer!
MCP standardization means agents use the same client interface regardless of which server provides tools, enabling easy tool swapping.

How does an MCP client discover what tools and resources are available from a server?

The client reads a configuration file that lists all available tools

The client queries the server using MCP protocol methods (like list_tools) to dynamically discover capabilities at connection time

The client must manually register each tool it wants to use before connecting

The server pushes a list of tools to the client when it starts
Correct Answer!
MCP clients use protocol methods to query servers for available tools and resources, enabling dynamic discovery without hardcoded lists.