## Designing Agent Tools
Your code review agent works brilliantly in demos—until you deploy it. In production, it starts calling ```check_security_scan``` with invalid file paths, hammering the GitHub API so fast it hits rate limits, and occasionally trying to merge PRs without proper authorization. The agent's reasoning is sound; its tools are the problem.

Tools are the hands and eyes of an agent. A brilliant reasoning engine with poorly designed tools is like a skilled surgeon with dull instruments—the expertise is there, but the execution fails. This lesson focuses on building tools that agents can use reliably, safely, and efficiently.

In this lesson, you will learn how to design tools at the right abstraction level, implement them with production-quality patterns, and test them for both technical correctness and agent usability.

By the end, you will have a toolkit of patterns for building agent tools that work reliably in production.

Finding the Right Abstraction Level
An agent without tools is just a chatbot. Tools are what enable agents to actually do things—query databases, call APIs, run scripts, send messages, update records. The tools you provide define your agent's capabilities, and how you design those tools determines whether the agent can reliably accomplish its goals.

A tool is a function the agent can call. Each tool has a name, description, parameter schema, and implementation. When the agent decides to use a tool, it specifies the tool name and parameters. Your execution layer validates the parameters, runs the function, and returns the result to the agent.

The art of tool design is choosing the right level of abstraction. If tools are too low-level, the agent must chain many small actions to accomplish anything, increasing complexity and failure probability. If tools are too high-level, they lack flexibility and cannot handle edge cases. Finding the balance requires understanding your use case.

Consider an agent that helps with GitHub pull request management. You could provide low-level tools: ```github_api_call(endpoint, method, body)```. This is maximally flexible—the agent can make any GitHub API call. But it must understand the GitHub API structure, construct proper request bodies, and handle pagination. This is complex and error-prone.

Or you could provide high-level tools: ```merge_pr_if_approved(pr_number)```. This is simple and reliable. But what if you need to merge with specific options, or check approval status without merging, or add labels based on approval comments? The high-level tool cannot handle these variations.

The practical approach is mid-level tools that match common operations: ```get_pr_details(pr_number)```, ```get_pr_approvals(pr_number)```, ```add_pr_label(pr_number, label)```, ```merge_pr(pr_number, method)```. These map to meaningful actions in the domain while remaining composable. The agent can combine them to handle diverse scenarios without dealing with raw API complexity.

Good tool design also means clear descriptions. The agent chooses tools based on natural language descriptions, so precision matters. Instead of "Gets PR data," write "Returns pull request details including title, description, author, status, and approval count. Use this to check the current state of a PR before taking actions." The description explains what the tool does, what it returns, and when to use it.

Parameter schemas enforce correct usage. Use type hints, required/optional markers, and constraints: ```merge_pr(pr_number: int, method: Literal["merge", "squash", "rebase"] = "merge")```. This prevents the agent from passing invalid data and makes the tool's interface self-documenting.

![Tool abstraction levels: finding the right balance between flexibility and simplicity](https://hrcdn.net/ai-engineering/module-4/light/agent-fundamentals-lesson03-abstraction-levels.svg)

Action Spaces and Capabilities
The set of available tools defines the agent's action space—the universe of possible actions it can take. Designing this action space is strategic: too few tools and the agent cannot accomplish goals; too many tools and the agent gets confused about which to use.

Scoping capabilities means providing exactly the tools needed for the agent's purpose. A deployment agent needs tools for checking server status, running deployment scripts, and sending notifications. It does not need tools for querying analytics databases or managing user accounts. Focused action spaces reduce confusion and improve reliability.

However, scoping too narrowly creates brittleness. If your deployment agent encounters an unexpected error, can it investigate? If it needs to roll back, does it have the tools? Think through not just the happy path but also error recovery and edge cases when defining capabilities.

Composability is designing tools that work well together. The agent should be able to chain tools naturally to accomplish complex tasks. If you have ```get_server_list()``` that returns server IDs and ```check_server_health(server_id)``` that checks one server, the agent can easily check all servers by iterating the results. But if ```get_server_list()``` returns JSON and ```check_server_health()``` expects XML, the agent must handle format conversion, adding complexity.

Design tools with consistent interfaces: use the same data formats, follow similar naming patterns, and return structured results. This makes tool composition intuitive.

Granularity control means providing tools at different levels of abstraction when appropriate. You might offer both ```send_email(to, subject, body)``` for full control and ```send_notification_email(user_id, notification_type)``` that uses templates. The agent can choose the right tool based on whether it needs customization or simplicity.

Read vs write separation is a safety principle. Tools that only read data (query databases, fetch API data, read files) are low-risk. Tools that modify state (update records, delete files, trigger deployments) are high-risk. Design your action space to clearly distinguish these. You might allow an agent unlimited read access but require human approval for write operations.

Consider an agent performing code review. Its action space might include:

Read tools: ```get_pr_details(pr_number)```, ```get_file_diff(pr_number, file)```, ```check_test_coverage(files)```, ```analyze_code_security(files)```

Low-risk write tools: ```add_pr_comment(pr_number, comment)```, ```add_pr_label(pr_number, label)```, ```request_changes(pr_number, feedback)```

High-risk write tools: ```approve_pr(pr_number)```, ```merge_pr(pr_number, method)```, ```close_pr(pr_number)```

![Action space design: balancing read and write tools for safety and flexibility](https://hrcdn.net/ai-engineering/module-4/light/agent-fundamentals-lesson03-action-space.svg)

The agent can freely use read and low-risk write tools. High-risk write tools require confirmation or are completely blocked. This action space design balances capability with safety.

Tool Implementation Patterns
How you implement tools affects reliability, performance, and debuggability. Several patterns help you build robust tool systems.

Validation layers check tool inputs before execution. An agent might pass parameters that are technically valid but contextually wrong—deleting a server that is currently serving traffic, sending an email with no recipients, or querying a non-existent database. Your tool implementation should validate not just types but also business logic constraints.

```python
def merge_pr(pr_number: int, method: str = "merge") -> dict:
  # Validation layer
  pr = get_pr(pr_number)
  if not pr:
      return {"error": "Pull request not found"}

  if pr["target_branch"] == "main" and not pr["has_approvals"]:
      return {"error": "Cannot merge to main without at least one approval"}

  if pr["ci_status"] != "passing":
      return {"error": "Cannot merge: CI checks are failing"}

  # Actual implementation
  result = github_api.merge_pr(pr_number, method)
  return {"success": True, "pr_number": pr_number, "merge_commit": result["sha"]}
```

Validation prevents errors and provides helpful feedback to the agent. Instead of a cryptic API error, the agent receives a clear explanation of why the action failed, helping it adjust its approach.

Idempotency means a tool can be called multiple times safely. If the agent calls ```add_pr_label(pr_number=1247, label="needs-review")``` twice, the second call should recognize the label already exists rather than creating a duplicate or failing. Idempotency prevents accidental duplication and makes agent behavior more predictable.

Error handling in tools is different from error handling in traditional code. You do not want to raise exceptions that crash the agent. Instead, return structured error information that the agent can reason about:

```python
{
  "success": False,
  "error_type": "permission_denied",
  "error_message": "Cannot access production database",
  "suggested_action": "Request access from admin or use read-replica instead"
}
```

This error format gives the agent enough information to decide what to do next. Maybe it should try a different approach, ask the user for help, or escalate to a human operator.

Rate limiting and cost controls prevent runaway execution. An agent stuck in a loop might call an expensive API hundreds of times. Tool implementations should track usage and stop after reasonable limits:

```python
class RateLimitedTool:
  def __init__(self, max_calls=10, cost_per_call=0.01):
      self.calls = 0
      self.max_calls = max_calls
      self.total_cost = 0
      self.cost_per_call = cost_per_call

  def execute(self, params):
      if self.calls >= self.max_calls:
          return {"error": "Rate limit exceeded"}

      if self.total_cost >= MAX_BUDGET:
          return {"error": "Cost budget exceeded"}

      self.calls += 1
      self.total_cost += self.cost_per_call

      return actual_tool_execution(params)
```

These protections prevent production incidents caused by agent misbehavior.

Tool Documentation and Discoverability
The agent's only interface to tools is their descriptions. If a tool is poorly documented, the agent will not know when or how to use it. Effective tool documentation is essential for agent performance.

Description quality determines whether the agent selects the right tool. A description should explain what the tool does, when to use it, what parameters it requires, and what it returns. Compare these descriptions:

Poor: "Reviews code changes"

Good: "Analyzes code changes in a pull request for security vulnerabilities, style violations, and potential bugs. Use this after getting PR details to perform automated code review. Requires pr_number and optionally specific files to focus on. Returns list of issues with severity, line numbers, and suggested fixes."

The good description provides context, use cases, parameter expectations, and return value information. This helps the agent make informed decisions.

Examples in descriptions significantly improve tool usage. Instead of explaining abstractly, show concrete examples:

```text
Tool: analyze_code_security
Description: Scans code files for security vulnerabilities and common attack patterns.

Parameters:
- files: List of file paths to analyze (e.g., ["auth.py", "api/handlers.py"])
- severity_threshold: Minimum severity to report (e.g., "low", "medium", "high")
- categories: Optional vulnerability categories to focus on (e.g., ["injection", "auth", "crypto"])

Example usage:
- Full security scan: files=["src/auth.py"], severity_threshold="low"
- Focus on injection risks: files=["api/handlers.py"], categories=["injection"]
- High severity only: files=["payment.py"], severity_threshold="high"

Returns: List of vulnerabilities with severity, line number, description, and remediation.
```

Examples ground abstract descriptions in concrete usage patterns that the agent can pattern-match against.

Parameter documentation should explain not just types but also valid ranges, common values, and interdependencies:

```text
Parameters:
- merge_method (str): How to merge the PR. Options: "merge", "squash", "rebase".
Use "squash" to combine commits into one clean commit.
Use "rebase" to maintain linear history without merge commits.
Warning: "rebase" rewrites history and should not be used on shared branches.

- delete_branch (bool): Whether to delete the source branch after merge.
Default: true for feature branches, false for release branches.
Check repository settings before using false.
```

This level of detail helps the agent make appropriate choices without trial and error.

Tool categorization helps when you have many tools. Group related tools and indicate categories in descriptions:

```text
[Code Analysis Tools]
- get_file_diff: Get the diff for a specific file in a PR
- analyze_code_security: Scan for security vulnerabilities
- check_code_complexity: Measure cyclomatic complexity and maintainability

[Review Action Tools]
- add_pr_comment: Add an inline or general comment to a PR
- request_changes: Request changes before the PR can be merged
- approve_pr: Approve a PR (requires human confirmation)

[Repository Tools]
- check_test_coverage: Get test coverage for changed files
- run_linter: Check code style compliance
- get_ci_status: Get the status of CI/CD checks
```

Categories help the agent understand the tool landscape and narrow down relevant options.

Tool Versioning and Evolution
As your agent system evolves, you will need to add, modify, or remove tools. Managing this evolution without breaking existing agent behavior requires careful planning.

Adding new tools is generally safe. New capabilities do not affect existing logic. However, new tools can confuse the agent if they overlap with existing ones. If you have deploy_to_production() and add deploy_with_validation(), the agent might not know which to prefer. When adding tools, ensure they have distinct use cases or deprecate overlapping tools.

Modifying tool interfaces is risky. If you change parameter names, types, or behavior, agent prompts that reference the old interface will break. Strategies for safe modification:

Versioning: Create tool_v2() alongside tool_v1(), migrate gradually
Backward compatibility: Support old parameter formats while encouraging new ones
Deprecation warnings: Return warnings when old patterns are used, prompting prompt updates
Removing tools should be gradual. Mark tools as deprecated, provide alternatives in descriptions, and monitor usage before removing. A deprecated tool might return:

```python
{
  "deprecated": True,
  "message": "This tool is deprecated. Use 'new_tool()' instead.",
  "result": actual_result  # Still works, but warns
}
```

This gives you time to update prompts before removal.

Tool capability discovery helps agents adapt to evolving tool sets. Instead of hardcoding available tools in prompts, you can dynamically list them:

```python
def get_available_tools():
  return [
      {
          "name": tool.name,
          "description": tool.description,
          "parameters": tool.parameters,
          "category": tool.category
      }
      for tool in active_tools
  ]
```

The agent's prompt includes current available tools, so adding or removing tools automatically updates what the agent knows. This makes the system more maintainable but requires the agent to handle variable tool sets.

Tool Security and Sandboxing
Tools execute in your production environment with access to real systems. Security is not optional. Agents can be prompted to do harmful things, can make mistakes, or can be exploited by malicious inputs. Your tool implementation must assume the agent might behave badly.

Permission systems enforce what each agent can do. An agent instance should have an associated permission set that tools check before executing:

```python
def delete_user(agent_context, user_id):
  if "user_deletion" not in agent_context.permissions:
      return {"error": "Permission denied: user_deletion required"}

  if user_id == agent_context.user_id:
      return {"error": "Cannot delete your own account"}

  # Execute deletion
```

This prevents privilege escalation and limits blast radius from agent errors.

Input sanitization protects against injection attacks. If a tool constructs SQL queries, shell commands, or API calls from agent-provided parameters, validate and sanitize inputs:

```python
def query_database(agent_context, table_name, filters):
  # Validate table name against whitelist
  if table_name not in ALLOWED_TABLES:
      return {"error": f"Table {table_name} not accessible"}

  # Use parameterized queries, never string concatenation
  query = "SELECT * FROM ? WHERE ?"
  result = db.execute(query, (table_name, filters))
  return {"data": result}
```

Never trust agent-provided input, even if the agent has been carefully prompted to behave correctly.

Audit logging records every tool call with parameters, results, and context. This provides accountability and helps investigate issues:

```python
def log_tool_execution(tool_name, params, result, agent_context):
  audit_log.write({
      "timestamp": now(),
      "agent_id": agent_context.agent_id,
      "user_id": agent_context.user_id,
      "tool": tool_name,
      "parameters": params,
      "result_summary": summarize(result),
      "success": result.get("success", False)
  })
```

Audit logs are essential for compliance, debugging, and understanding agent behavior in production.

Sandboxing isolates tool execution from critical systems. High-risk tools should run in restricted environments where failures cannot affect production. You might execute code-running tools in Docker containers, limit file system access, or use separate AWS accounts for agent-controlled resources.

Testing and Validating Tools
Tools are code, and code needs testing. But testing agent tools differs from testing traditional functions because you must verify both technical correctness and agent usability.

Unit testing verifies technical correctness. Each tool should have tests covering normal operation, edge cases, error conditions, and validation logic:

```python
def test_analyze_code_security():
  # Normal case - finds vulnerabilities
  result = analyze_code_security(files=["auth.py"])
  assert result["success"] == True
  assert "vulnerabilities" in result

  # Invalid file path
  result = analyze_code_security(files=["nonexistent.py"])
  assert result["success"] == False
  assert "not found" in result["error_message"].lower()

  # Empty file list
  result = analyze_code_security(files=[])
  assert result["success"] == False
  assert "at least one file" in result["error_message"].lower()
```

Unit tests ensure tools behave correctly in isolation.

Integration testing verifies tools work with real external systems. Does query_database() actually connect to the database? Does send_email() successfully deliver messages? Integration tests catch issues that unit tests with mocks miss.

Agent usability testing evaluates whether agents can successfully use tools. This requires running agent scenarios and checking if the agent selects appropriate tools, provides valid parameters, and handles results correctly:

```python
def test_agent_can_review_pr():
  agent = create_test_agent(tools=[get_pr_details, analyze_code_security, add_pr_comment])
  result = agent.run("Review PR #1247 for security issues")

  # Check that agent used correct tools
  assert "get_pr_details" in result.tool_calls
  assert result.tool_calls["get_pr_details"]["pr_number"] == 1247

  # Check that agent performed security analysis
  assert "analyze_code_security" in result.tool_calls

  # Check final response
  assert "review" in result.response.lower()
```

This end-to-end testing reveals problems with tool descriptions, parameter schemas, or return value formats that confuse agents.

Error message quality testing checks that error messages help agents recover. Introduce failures and verify the agent receives actionable error information:

```python
def test_review_failure_handling():
  # Simulate a test coverage check failure
  mock_check_test_coverage.return_value = {
      "success": False,
      "error_type": "coverage_below_threshold",
      "error_message": "Test coverage is 45%, minimum required is 80%",
      "suggested_action": "Request author to add more tests before approval"
  }

  agent = create_test_agent(tools=[analyze_code_security, check_test_coverage, request_changes])
  result = agent.run("Review PR #1247")

  # Agent should recognize the coverage issue and request changes
  assert "request_changes" in result.tool_calls
```

If agents frequently fail to handle errors properly, the error messages need improvement.

Tool Performance and Optimization
Tool execution speed affects agent performance. If each tool call takes 10 seconds and the agent makes 20 calls, the total runtime is over 3 minutes. Users expect faster responses, so tool optimization matters.

Caching reduces redundant work. If an agent calls ```get_pr_details(pr_number=1247)``` three times in one session, cache the result:

```python
class CachedTool:
  def __init__(self, tool_func, ttl_seconds=60):
      self.func = tool_func
      self.cache = {}
      self.ttl = ttl_seconds

  def execute(self, params):
      cache_key = hash_params(params)

      if cache_key in self.cache:
          cached_result, timestamp = self.cache[cache_key]
          if time.now() - timestamp < self.ttl:
              return cached_result

      result = self.func(params)
      self.cache[cache_key] = (result, time.now())
      return result
```

Caching is safe for read-only tools and dramatically reduces latency for repeated queries.

Parallel execution runs independent tools simultaneously. If the agent needs to check three servers, execute all three checks in parallel rather than sequentially:

```python
async def execute_tools_parallel(tool_calls):
  tasks = [execute_tool(call["tool"], call["params"]) for call in tool_calls]
  results = await asyncio.gather(*tasks)
  return results
```

This requires async tool implementations but can reduce runtime significantly.

Lazy loading defers expensive operations until needed. Instead of returning full code analysis, return summaries with options to fetch details:

```python
def analyze_code_security(files, severity_threshold="medium"):
  vulnerabilities = scan_for_vulnerabilities(files)

  return {
      "total_issues": len(vulnerabilities),
      "high_severity": [v for v in vulnerabilities if v["severity"] == "high"][:3],
      "summary": summarize_vulnerability_types(vulnerabilities),
      "fetch_all_token": generate_token(vulnerabilities)  # For fetching full results
  }
```

The agent can decide whether it needs full results or if the summary suffices.

Tool latency budgets set maximum execution times. If a tool takes too long, timeout and return a partial result:

```python
def execute_with_timeout(tool, params, timeout_seconds=5):
  try:
      result = run_with_timeout(tool, params, timeout_seconds)
      return result
  except TimeoutError:
      return {
          "success": False,
          "error": "Tool execution exceeded timeout",
          "partial_result": get_partial_result_if_available()
      }
```
This prevents one slow tool from blocking the entire agent.

Summary
Tools define what agents can do. Effective tool design requires choosing the right abstraction level, writing clear descriptions, and providing appropriate capabilities. The action space—the set of available tools—should be scoped to the agent's purpose while remaining composable and flexible.

Tool implementation patterns like validation layers, idempotency, structured error handling, and rate limiting make tools reliable and safe. Documentation quality determines whether agents can effectively use tools, with good descriptions explaining what, when, and how along with concrete examples.

Tool evolution requires versioning strategies, backward compatibility, and graceful deprecation. Security measures including permission systems, input sanitization, audit logging, and sandboxing protect against agent errors and malicious behavior.

Testing tools requires unit tests for correctness, integration tests for external systems, agent usability tests for end-to-end scenarios, and error message quality tests for recovery behavior. Performance optimization through caching, parallel execution, lazy loading, and timeout controls keeps agents responsive.

Key Takeaways:

Tools should be mid-level abstractions that balance flexibility with simplicity and match domain operations
Action spaces should be scoped to agent purpose while supporting error recovery and edge cases
Tool descriptions with clear explanations and examples determine agent selection and usage quality
Implementation patterns like validation, idempotency, and structured errors make tools reliable
Security measures including permissions, input sanitization, and audit logging are essential for production tools
Test tools for technical correctness, agent usability, and error handling effectiveness
Optimize tool performance through caching, parallel execution, and latency controls