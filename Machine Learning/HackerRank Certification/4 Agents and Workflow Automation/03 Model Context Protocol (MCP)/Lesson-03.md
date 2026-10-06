## Connecting Agents to MCP Servers
Your code review agent needs to connect to three MCP servers: GitHub for repository access, a security scanner for vulnerability detection, and a coverage service for test metrics. Each server has different capabilities, different connection requirements, and different failure modes. Your client must manage all of them seamlessly.

MCP clients are the glue between your agent and the MCP ecosystem. They connect to servers, discover capabilities, handle failures, and present a unified interface to your agent's reasoning loop. Getting this right is essential for production MCP integration.

In this lesson, you will build MCP clients that connect to multiple servers, handle tool discovery and invocation, and manage the complexity of real-world deployments.

By the end, you will have patterns for building robust MCP clients that your agents can rely on.

Building the Client Foundation
MCP clients establish connections to servers and make their capabilities available to your agent. The MCP SDK provides client libraries that handle protocol details; your job is to manage server connections and translate between MCP tools and your agent's function-calling interface.

```python
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

class MCPClientManager:
  def __init__(self):
      self.sessions = {}  # Server name -> session
      self.tools = {}     # Tool name -> {server, tool}

  async def connect_server(self, name: str, command: list[str], env: dict = None):
      """Connect to an MCP server via stdio"""
      server_params = StdioServerParameters(
          command=command[0], args=command[1:], env=env
      )
      read, write = await stdio_client(server_params)
      session = ClientSession(read, write)
      await session.initialize()

      self.sessions[name] = session
      await self._discover_capabilities(name, session)
      return session
```

The client manager maintains connections to multiple servers and aggregates their capabilities. When a tool is called, the manager routes the request to the appropriate server automatically.

Connecting to Multiple Servers
Real agents typically need capabilities from several specialized servers. The client manager pattern makes this straightforward:

```python
async def setup_code_review_client():
  manager = MCPClientManager()

  # Connect to GitHub server
  await manager.connect_server(
      name="github",
      command=["python", "github_mcp_server.py"],
      env={"GITHUB_TOKEN": os.environ["GITHUB_TOKEN"]}
  )

  # Connect to security scanner
  await manager.connect_server(
      name="security",
      command=["python", "security_mcp_server.py"]
  )

  # Connect to coverage service
  await manager.connect_server(
      name="coverage",
      command=["python", "coverage_mcp_server.py"]
  )

  # All tools from all servers are now available
  print(f"Available tools: {list(manager.tools.keys())}")
  # Output: ['get_pr_details', 'post_comment', 'scan_security', 'get_coverage']

  return manager
```

This pattern gives your agent access to capabilities from multiple specialized servers through a unified interface. The agent does not need to know which server provides which tool.

Tool Discovery and Invocation
Once connected, clients discover available tools and invoke them when needed. Discovery happens at startup; invocation happens during agent execution.

Tool discovery maps server tools to LLM function-calling format:

```python
def get_tools_for_llm(self) -> list[dict]:
  """Convert MCP tools to LLM function-calling format"""
  llm_tools = []

  for tool_name, tool_info in self.tools.items():
      tool = tool_info["tool"]
      llm_tools.append({
          "type": "function",
          "function": {
              "name": tool.name,
              "description": tool.description,
              "parameters": tool.inputSchema
          }
      })

  return llm_tools
```

Tool invocation routes calls to the correct server:

```python
async def call_tool(self, tool_name: str, arguments: dict) -> dict:
  """Invoke a tool on the appropriate server"""
  if tool_name not in self.tools:
      return {"error": f"Unknown tool: {tool_name}"}

  tool_info = self.tools[tool_name]
  server_name = tool_info["server"]
  session = self.sessions[server_name]

  try:
      result = await session.call_tool(tool_name, arguments)
      return {
          "success": True,
          "result": self._extract_text(result.content)
      }
  except Exception as e:
      return {"success": False, "error": str(e), "server": server_name}
```

Integrating with the Agent Loop
The agent uses discovered tools in its reasoning loop, executing tool calls through the MCP client:

```python
class MCPCodeReviewAgent:
  def __init__(self, llm_client, mcp_manager):
      self.llm = llm_client
      self.mcp = mcp_manager

  async def review_pr(self, owner: str, repo: str, pr_number: int):
      messages = [
          {"role": "system", "content": self._system_prompt()},
          {"role": "user", "content": f"Review PR #{pr_number} in {owner}/{repo}"}
      ]
      tools = self.mcp.get_tools_for_llm()

      for iteration in range(15):
          response = await self.llm.chat(messages=messages, tools=tools)

          if response.tool_calls:
              for call in response.tool_calls:
                  result = await self.mcp.call_tool(
                      call.function.name, json.loads(call.function.arguments)
                  )
                  messages.append({"role": "tool", "tool_call_id": call.id,
                                  "content": json.dumps(result)})
          else:
              return response.content
```

The agent discovers tools at startup, presents them to the LLM, and routes tool calls to the appropriate MCP server. Adding new capabilities means connecting to additional servers—no code changes required.

Error Handling and Resilience
Production clients must handle server failures, network issues, and protocol errors gracefully.

Timeouts prevent hanging on slow servers:

```python
import asyncio

async def call_tool_with_timeout(self, tool_name: str, arguments: dict,
                                timeout_seconds: int = 30) -> dict:
  try:
      result = await asyncio.wait_for(
          self.call_tool(tool_name, arguments),
          timeout=timeout_seconds
      )
      return result
  except asyncio.TimeoutError:
      return {
          "success": False,
          "error": f"Tool call timed out after {timeout_seconds}s"
      }
```

Reconnection handles server crashes:

```python
async def call_tool_resilient(self, tool_name: str, arguments: dict) -> dict:
  """Call tool with automatic reconnection on failure"""
  tool_info = self.tools.get(tool_name)
  if not tool_info:
      return {"error": f"Unknown tool: {tool_name}"}

  server_name = tool_info["server"]

  for attempt in range(3):  # Retry up to 3 times
      try:
          return await self.call_tool(tool_name, arguments)
      except ConnectionError:
          if attempt < 2:
              await self._reconnect_server(server_name)
          else:
              return {"error": f"Server {server_name} unavailable"}
```

Common Pitfalls and Solutions
Not handling tool discovery failures: If a server fails during capability discovery, your agent might have no tools. Always have fallback behavior for degraded operation.

Ignoring server-specific errors: Different servers return different error formats. Normalize error responses so your agent can handle them consistently.

Blocking the event loop: MCP clients are async. Use asyncio.gather for parallel tool calls when possible, and never use blocking operations that freeze the client.

Not tracking which server provides which tool: When errors occur, you need to know which server failed. Always maintain the server-to-tool mapping.

Summary
MCP clients connect to servers, discover capabilities, and integrate those capabilities into agent workflows. The client manager pattern aggregates tools from multiple servers, presenting a unified interface to your agent.

Tool discovery translates MCP tools to LLM function-calling format. Tool invocation routes calls to the appropriate server. Error handling through timeouts, reconnection, and graceful degradation ensures production reliability.

Key Takeaways:

Clients connect to multiple servers and aggregate their capabilities into a unified interface
Tool discovery translates MCP tools to LLM function-calling format for seamless integration
The agent does not need to know which server provides which tool—the client handles routing
Timeouts and reconnection logic ensure resilience when servers fail
Use asyncio.gather for parallel tool calls when operations are independent