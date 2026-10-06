## From Internal Tools to MCP Servers
You have an internal security scanner that does amazing work. It catches vulnerabilities your team would miss, but it returns data in a proprietary format, requires custom authentication, and has quirky error codes. Every time someone wants to use it with a new agent, they spend days figuring out the integration details.

Building an MCP server wraps this complexity behind a clean, standardized interface that any MCP client can use. The server becomes a translator: it speaks your tool's language internally while presenting a consistent MCP interface externally.

In this lesson, you will build MCP servers that expose tools, resources, and prompts. You will learn the patterns that make servers production-ready, from input validation to error handling.

By the end, you will have hands-on experience creating servers that your code review agent can connect to.

Server Structure and Setup
The MCP SDK provides libraries that handle protocol details, letting you focus on your server's actual functionality. For Python, the mcp package provides server primitives that manage connections, message routing, and capability negotiation.

A basic server starts with initialization and capability declaration:

```python
from mcp.server import Server
from mcp.types import Tool, TextContent
import json

# Create server instance with a descriptive name
server = Server("github-code-review")

# List the tools this server provides
@server.list_tools()
async def list_tools():
  return [
      Tool(
          name="get_pr_details",
          description="Retrieves pull request information including files and status",
          inputSchema={
              "type": "object",
              "properties": {
                  "owner": {"type": "string", "description": "Repository owner"},
                  "repo": {"type": "string", "description": "Repository name"},
                  "pr_number": {"type": "integer", "description": "PR number"}
              },
              "required": ["owner", "repo", "pr_number"]
          }
      )
  ]
```

The ```@server.list_tools()``` decorator tells MCP clients what capabilities this server offers. When a client connects, it calls this function to discover available tools. The schema definition follows JSON Schema format, which LLMs already understand from function calling.

Implementing Tool Handlers
Tools do the actual work. When a client invokes a tool, the server's handler receives the tool name and arguments, performs the operation, and returns structured results.

```python
@server.call_tool()
async def call_tool(name: str, arguments: dict):
  """Route tool calls to appropriate handlers"""
  if name == "get_pr_details":
      return await get_pr_details(**arguments)
  elif name == "post_comment":
      return await post_comment(**arguments)
  else:
      return [TextContent(type="text",
                         text=json.dumps({"error": f"Unknown tool: {name}"}))]

async def get_pr_details(owner: str, repo: str, pr_number: int):
  """Fetch pull request details from GitHub"""
  repo_obj = github_client.get_repo(f"{owner}/{repo}")
  pr = repo_obj.get_pull(pr_number)

  result = {
      "number": pr.number,
      "title": pr.title,
      "author": pr.user.login,
      "files": [f.filename for f in pr.get_files()]
  }
  return [TextContent(type="text", text=json.dumps(result))]
```

The handler pattern is straightforward: check the tool name, call the appropriate function, and wrap results in ```TextContent```. This pattern scales cleanly as you add more tools.

Implementing Resources
Resources provide read-only data access. For code review, resources might expose PR diffs, file contents, or review history. Unlike tools (which perform actions), resources give agents direct access to data they can read and reference throughout a conversation.

```python
from mcp.types import Resource

@server.list_resources()
async def list_resources():
  return [
      Resource(
          uri="github://company/backend-api/pulls/1247",
          name="PR #1247: Add OAuth support",
          description="Pull request details and metadata",
          mimeType="application/json"
      ),
      Resource(
          uri="github://company/backend-api/pulls/1247/diff",
          name="PR #1247 Diff",
          description="Complete diff for all changed files",
          mimeType="text/x-diff"
      )
  ]

@server.read_resource()
async def read_resource(uri: str):
  """Fetch resource content based on URI"""
  parsed = parse_github_uri(uri)

  repo = github_client.get_repo(f"{parsed['owner']}/{parsed['repo']}")
  pr = repo.get_pull(parsed["pr_number"])

  if parsed["type"] == "pr":
      content = {
          "number": pr.number,
          "title": pr.title,
          "body": pr.body,
          "author": pr.user.login
      }
      return [TextContent(uri=uri, mimeType="application/json",
                         text=json.dumps(content))]

  elif parsed["type"] == "diff":
      diff = get_pr_diff(pr)
      return [TextContent(uri=uri, mimeType="text/x-diff", text=diff)]

```

Resource URIs should follow a consistent scheme that is easy to parse. The ```github://owner/repo/pulls/123``` pattern clearly identifies the resource type and location.

Implementing Prompts
Prompts provide reusable interaction templates for common workflows. For code review, prompts might guide security reviews, coverage checks, or style audits.

```python
from mcp.types import Prompt, PromptArgument, GetPromptResult, PromptMessage

@server.list_prompts()
async def list_prompts():
  return [
      Prompt(
          name="security_review",
          description="Comprehensive security-focused code review",
          arguments=[
              PromptArgument(name="owner", required=True),
              PromptArgument(name="repo", required=True),
              PromptArgument(name="pr_number", required=True)
          ]
      )
  ]

@server.get_prompt()
async def get_prompt(name: str, arguments: dict):
  if name == "security_review":
      pr = await get_pr_details(**arguments)

      prompt_text = f"""Perform a security review of PR #{arguments['pr_number']}.

**Review Focus:**
1. Input validation and sanitization
2. Authentication and authorization checks
3. SQL injection vulnerabilities
4. Cross-site scripting (XSS) risks
5. Sensitive data exposure

Use the available tools to analyze the code and report findings."""

      return GetPromptResult(
          messages=[PromptMessage(
              role="user",
              content=TextContent(type="text", text=prompt_text)
          )]
      )
Prompts help agents use tools effectively by providing structured guidance. Clients request prompts and feed the resulting messages to their LLM, ensuring consistent behavior for common tasks.

Error Handling
Robust servers handle errors gracefully, providing useful feedback to clients. MCP clients rely on clear error messages to recover from failures or inform users what went wrong.

python
@server.call_tool()
async def call_tool(name: str, arguments: dict):
  # Validate required parameters
  if "pr_number" in arguments:
      pr_number = arguments["pr_number"]
      if not isinstance(pr_number, int) or pr_number < 1:
          return [TextContent(type="text", text=json.dumps({
              "error": "validation_error",
              "message": "pr_number must be a positive integer"
          }))]

  try:
      return await execute_tool(name, arguments)
  except RateLimitError as e:
      return [TextContent(type="text", text=json.dumps({
          "error": "rate_limit",
          "message": "GitHub API rate limit exceeded",
          "retry_after": e.reset_time
      }))]
  except NotFoundError as e:
      return [TextContent(type="text", text=json.dumps({
          "error": "not_found",
          "message": str(e),
          "suggestion": "Verify the repository and PR number exist"
      }))]
  except Exception as e:
      return [TextContent(type="text", text=json.dumps({
          "error": "internal_error",
          "message": str(e)
      }))]
```

Structured error responses help clients understand and handle failures. Include error types, human-readable messages, and suggestions for recovery when possible.

Running the Server
Servers connect to transports that handle the actual communication. For local development, stdio is simplest—the client spawns the server as a subprocess.

```python
import asyncio
from mcp.server.stdio import stdio_server

async def main():
  async with stdio_server() as (read_stream, write_stream):
      await server.run(
          read_stream,
          write_stream,
          server.create_initialization_options()
      )

if __name__ == "__main__":
  asyncio.run(main())
```

For remote deployment, use HTTP with Server-Sent Events:

```python
from mcp.server.sse import SseServerTransport
from starlette.applications import Starlette
from starlette.routing import Route

sse = SseServerTransport("/messages")

async def handle_sse(request):
  async with sse.connect_sse(request.scope, request.receive, request._send) as streams:
      await server.run(streams[0], streams[1],
                      server.create_initialization_options())

app = Starlette(routes=[
  Route("/sse", endpoint=handle_sse),
  sse.get_message_route()
])

# Run with: uvicorn server:app --host 0.0.0.0 --port 8080
```

Common Pitfalls and Solutions
Not validating inputs: Always validate parameters before calling external APIs. Invalid inputs should return clear error messages, not crash the server.

Missing error context: Generic error messages make debugging difficult. Include the operation that failed, relevant parameters, and recovery suggestions in error responses.

Blocking operations: MCP servers are async. Do not use blocking calls that freeze the server while waiting for API responses. Use async libraries for HTTP requests and database operations.

Hardcoding configuration: Credentials and settings should come from environment variables or configuration files, not hardcoded in the server. This makes deployment flexible and secure.

Summary
Building MCP servers involves implementing tool handlers, resources, and prompts that expose your capabilities through the standardized protocol. The MCP SDK handles protocol details while you focus on functionality.

Servers expose tools through decorated handlers that process arguments and return structured results. Resources provide read-only data access through URI-based addressing. Prompts offer reusable workflow templates that guide agent interactions.

Key Takeaways:

Use the MCP SDK to handle protocol details while you implement business logic
Tools are decorated handlers that validate input and return TextContent results
Resources use URI schemes for consistent addressing and efficient data access
Prompts provide workflow templates that guide agent interactions
Structured error responses help clients handle failures gracefully
Choose transport based on deployment: stdio for local, HTTP/SSE for remote
