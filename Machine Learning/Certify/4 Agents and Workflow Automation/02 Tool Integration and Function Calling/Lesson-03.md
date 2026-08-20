## The Execution Layer
Your schemas are perfect. The model selects the right tools with accurate parameters. But when ```analyze_code_security(pr_number=1247)``` executes, it returns a 50,000-line JSON blob that overflows the context window. Or it takes 30 seconds because it hits GitHub's rate limit. Or it fails silently and returns null.

The execution layer is where schemas meet reality. This layer must handle real-world complexity: API quirks, rate limits, error conditions, large responses, and concurrent operations. Getting it right is the difference between a demo that works and a production system that is reliable.

In this lesson, you will learn how to build execution layers that integrate with external services, format results for model consumption, and handle the complexity of real-world APIs.

By the end, you will have patterns for building execution layers that bridge LLM reasoning and real-world actions reliably.

Execution Layer Fundamentals
The execution layer is where function calls become real actions. When the model outputs ```analyze_code_security(pr_number=1247)```, your execution layer must parse that request, invoke actual code, interact with external systems, and return results the model can use. This layer bridges LLM reasoning and real-world effects.

A basic execution layer has three responsibilities: routing function calls to implementations, executing those implementations safely, and formatting results for the model. Here is a minimal implementation for a code review agent:

```python
class ToolExecutor:
  def __init__(self):
      self.implementations = {
          "get_pr_details": self._get_pr_details,
          "analyze_code_security": self._analyze_code_security,
          "check_test_coverage": self._check_test_coverage,
          "post_review_comment": self._post_review_comment
      }

  def execute(self, function_name, arguments):
      if function_name not in self.implementations:
          return {"error": f"Unknown function: {function_name}"}

      implementation = self.implementations[function_name]
      result = implementation(**arguments)
      return result

  def _get_pr_details(self, pr_number):
      # Call GitHub API
      response = github_client.get_pull_request(pr_number)
      return {
          "title": response.title,
          "author": response.user.login,
          "files_changed": [f.filename for f in response.get_files()],
          "status": response.state,
          "approvals": len([r for r in response.get_reviews() if r.state == "APPROVED"])
      }

  def _analyze_code_security(self, pr_number, file_paths=None, severity_threshold="medium"):
      # Get PR diff and run security scanner
      diff = github_client.get_pr_diff(pr_number)
      files_to_scan = file_paths or extract_files_from_diff(diff)

      vulnerabilities = security_scanner.scan(files_to_scan, min_severity=severity_threshold)
      return {
          "vulnerabilities": vulnerabilities,
          "files_scanned": len(files_to_scan),
          "scan_time": security_scanner.last_scan_duration
      }
```

This structure separates concerns: the executor handles routing and formatting while individual implementations contain business logic. This separation makes testing easier and keeps the execution layer maintainable.

![The execution layer: routing calls to real-world actions](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson03-execution-flow.svg)

Integrating with External APIs
Code review agents interact with multiple external systems: GitHub for PR data, security scanners for vulnerability detection, CI systems for test results. Each integration requires careful implementation to handle authentication, rate limits, and API quirks.

GitHub API integration is central to code review. You need to fetch PR details, diffs, comments, and CI status. Use the official client libraries when available:

```python
from github import Github

class GitHubIntegration:
  def __init__(self, token):
      self.client = Github(token)

  def get_pr_details(self, repo_name, pr_number):
      repo = self.client.get_repo(repo_name)
      pr = repo.get_pull(pr_number)

      return {
          "number": pr.number,
          "title": pr.title,
          "body": pr.body,
          "author": pr.user.login,
          "base_branch": pr.base.ref,
          "head_branch": pr.head.ref,
          "state": pr.state,
          "mergeable": pr.mergeable,
          "changed_files": pr.changed_files,
          "additions": pr.additions,
          "deletions": pr.deletions,
          "files": [
              {"path": f.filename, "status": f.status, "changes": f.changes}
              for f in pr.get_files()
          ],
          "reviews": [
              {"user": r.user.login, "state": r.state}
              for r in pr.get_reviews()
          ]
      }

  def get_file_content(self, repo_name, path, ref):
      repo = self.client.get_repo(repo_name)
      content = repo.get_contents(path, ref=ref)
      return content.decoded_content.decode('utf-8')

  def post_review_comment(self, repo_name, pr_number, body, commit_id=None, path=None, line=None):
      repo = self.client.get_repo(repo_name)
      pr = repo.get_pull(pr_number)

      if path and line:
          # Inline comment on specific line
          pr.create_review_comment(body=body, commit_id=commit_id, path=path, line=line)
      else:
          # General PR comment
          pr.create_issue_comment(body=body)

      return {"success": True, "comment_type": "inline" if path else "general"}
```

Security scanner integration varies by tool. Some scanners run locally, others are SaaS APIs. Design your integration to abstract these differences:

```python
class SecurityScanner:
  def __init__(self, scanner_type="semgrep"):
      self.scanner_type = scanner_type
      self.last_scan_duration = 0

  def scan(self, file_paths, min_severity="medium"):
      start_time = time.time()

      if self.scanner_type == "semgrep":
          results = self._run_semgrep(file_paths)
      elif self.scanner_type == "snyk":
          results = self._call_snyk_api(file_paths)
      else:
          raise ValueError(f"Unknown scanner: {self.scanner_type}")

      self.last_scan_duration = time.time() - start_time

      # Filter by severity
      severity_order = ["low", "medium", "high", "critical"]
      min_index = severity_order.index(min_severity)
      filtered = [r for r in results if severity_order.index(r["severity"]) >= min_index]

      return filtered

  def _run_semgrep(self, file_paths):
      import subprocess
      result = subprocess.run(
          ["semgrep", "--json", "--config=auto"] + file_paths,
          capture_output=True, text=True
      )
      findings = json.loads(result.stdout)

      return [
          {
              "type": f["check_id"],
              "severity": self._map_semgrep_severity(f["extra"]["severity"]),
              "file": f["path"],
              "line": f["start"]["line"],
              "message": f["extra"]["message"],
              "fix": f["extra"].get("fix")
          }
          for f in findings.get("results", [])
      ]
```

Rate limiting is essential for external API calls. GitHub has rate limits, security scanners have quotas. Implement limiting to prevent failures:

```python
from ratelimit import limits, sleep_and_retry

class RateLimitedGitHub:
  def __init__(self, token):
      self.client = Github(token)

  @sleep_and_retry
  @limits(calls=30, period=60)  # 30 calls per minute
  def api_call(self, method, *args, **kwargs):
      return method(*args, **kwargs)

  def get_pr_details(self, repo_name, pr_number):
      repo = self.api_call(self.client.get_repo, repo_name)
      pr = self.api_call(repo.get_pull, pr_number)
      return self._format_pr(pr)
```

Result Formatting and Context Management
Function results must be formatted so the model can understand and use them. Raw API responses are often too verbose, poorly structured, or contain irrelevant data. Your execution layer should transform results into model-friendly formats.

Keep results concise. Models have context limits. A full GitHub PR response might be thousands of tokens, but the model only needs key information:

```python
def format_pr_for_model(pr_response):
  # Full response might be 5000+ tokens
  # Formatted response is ~200 tokens
  return {
      "pr_number": pr_response["number"],
      "title": pr_response["title"],
      "author": pr_response["author"],
      "status": pr_response["state"],
      "files_changed": len(pr_response["files"]),
      "file_list": [f["path"] for f in pr_response["files"][:20]],  # Limit file list
      "has_approvals": pr_response["approvals"] > 0,
      "ci_status": pr_response.get("ci_status", "unknown")
  }
```

Structure results consistently. All tool results should follow a predictable format. The model learns patterns from consistent structure:

```python
def format_tool_result(success, data=None, error=None):
  result = {"success": success}

  if success:
      result["data"] = data
  else:
      result["error"] = error
      result["suggested_action"] = suggest_recovery(error)

  return result

# All tools use the same format
def _analyze_code_security(self, pr_number, **kwargs):
  try:
      vulnerabilities = self.scanner.scan(...)
      return format_tool_result(
          success=True,
          data={
              "vulnerabilities": vulnerabilities,
              "summary": f"Found {len(vulnerabilities)} issues",
              "highest_severity": max(v["severity"] for v in vulnerabilities) if vulnerabilities else None
          }
      )
  except ScannerError as e:
      return format_tool_result(
          success=False,
          error=str(e)
      )
```

Include actionable summaries. Help the model understand results without processing every detail:

```python
def format_security_scan_result(vulnerabilities):
  if not vulnerabilities:
      return {
          "success": True,
          "data": {
              "vulnerabilities": [],
              "summary": "No security issues found",
              "recommendation": "Security scan passed. Proceed with other checks."
          }
      }

  severity_counts = Counter(v["severity"] for v in vulnerabilities)
  critical_files = set(v["file"] for v in vulnerabilities if v["severity"] == "critical")

  return {
      "success": True,
      "data": {
          "vulnerabilities": vulnerabilities,
          "summary": f"Found {len(vulnerabilities)} issues: {dict(severity_counts)}",
          "critical_files": list(critical_files),
          "recommendation": "Critical issues found. Request changes before approving."
              if severity_counts.get("critical", 0) > 0
              else "Review medium/high issues with author."
      }
  }
```

Handle large results gracefully. When results exceed reasonable size, summarize or paginate:

```python
def format_large_diff(diff_content, max_lines=500):
  lines = diff_content.split('\n')

  if len(lines) <= max_lines:
      return {"diff": diff_content, "truncated": False}

  # Return summary with option to fetch more
  return {
      "diff": '\n'.join(lines[:max_lines]),
      "truncated": True,
      "total_lines": len(lines),
      "summary": f"Diff truncated. Showing first {max_lines} of {len(lines)} lines.",
      "hint": "Use get_file_diff with specific file_path for detailed view"
  }
```

Execution Context and State
Tool execution often needs context beyond the immediate arguments. Which repository are we reviewing? What is the current user's permission level? What tools have already been called? Managing this context is essential for coherent agent behavior.

Execution context provides ambient information that tools need:

```python
@dataclass
class ExecutionContext:
  repo_name: str
  user_id: str
  permissions: List[str]
  session_id: str
  tool_call_history: List[dict]
  token_budget: int

class ContextAwareExecutor:
  def __init__(self, context: ExecutionContext):
      self.context = context
      self.implementations = \{...\}

  def execute(self, function_name, arguments):
      # Inject context into execution
      result = self.implementations[function_name](
          context=self.context,
          **arguments
      )

      # Track tool call
      self.context.tool_call_history.append({
          "function": function_name,
          "arguments": arguments,
          "result_summary": summarize_result(result),
          "timestamp": datetime.now()
      })

      return result
```

Permission checking ensures tools only execute authorized actions:

```python
def _post_review_comment(self, context, pr_number, body, **kwargs):
  # Check permission before execution
  if "write_comments" not in context.permissions:
      return format_tool_result(
          success=False,
          error="Permission denied: cannot post comments",
          suggested_action="Request comment permission or summarize findings for manual posting"
      )

  # Execute with context
  return self.github.post_review_comment(
      repo_name=context.repo_name,
      pr_number=pr_number,
      body=body,
      **kwargs
  )
```

Tool call history prevents redundant calls and enables smarter execution:

```python
def _get_pr_details(self, context, pr_number):
  # Check if we already fetched this PR
  for call in context.tool_call_history:
      if call["function"] == "get_pr_details" and call["arguments"]["pr_number"] == pr_number:
          return format_tool_result(
              success=True,
              data=call["cached_result"],
              note="Returned cached result from earlier call"
          )

  # Fetch fresh data
  result = self.github.get_pr_details(context.repo_name, pr_number)
  return format_tool_result(success=True, data=result)
```

Your code review agent's execution layer calls the GitHub API frequently. The API has rate limits of 5,000 requests per hour. What is the most important consideration when implementing rate limit handling?

Async and Parallel Execution
Production agents often benefit from async execution. Waiting for one API call to complete before starting the next wastes time. Async execution lets you run independent operations concurrently.

Async tool implementations enable concurrent execution:

```python
import asyncio
import aiohttp

class AsyncToolExecutor:
  async def execute(self, function_name, arguments):
      implementation = self.implementations[function_name]
      return await implementation(**arguments)

  async def execute_parallel(self, tool_calls):
      """Execute multiple independent tool calls concurrently."""
      tasks = [
          self.execute(call["function"], call["arguments"])
          for call in tool_calls
      ]
      return await asyncio.gather(*tasks, return_exceptions=True)

  async def _analyze_code_security(self, pr_number, **kwargs):
      async with aiohttp.ClientSession() as session:
          # Async API calls
          diff = await self._fetch_diff(session, pr_number)
          vulnerabilities = await self._run_async_scan(diff, **kwargs)
          return format_tool_result(success=True, data=vulnerabilities)
```

Parallel tool calling is supported by some LLM providers. When the model returns multiple tool calls, execute them simultaneously:

```python
async def handle_model_response(response):
  tool_calls = response.tool_calls

  if not tool_calls:
      return response.content

  # Execute all tool calls in parallel
  results = await executor.execute_parallel([
      {"function": tc.function.name, "arguments": json.loads(tc.function.arguments)}
      for tc in tool_calls
  ])

  # Format results for model
  tool_results = [
      {"tool_call_id": tc.id, "result": result}
      for tc, result in zip(tool_calls, results)
  ]

  # Continue conversation with results
  return await call_model_with_results(tool_results)
```

Dependency-aware execution handles cases where some calls depend on others:

```python
async def execute_with_dependencies(tool_calls, dependencies):
  """
  Execute tool calls respecting dependencies.
  dependencies: dict mapping tool_call_id to list of prerequisite ids
  """
  completed = {}
  pending = list(tool_calls)

  while pending:
      # Find calls with satisfied dependencies
      ready = [
          call for call in pending
          if all(dep in completed for dep in dependencies.get(call["id"], []))
      ]

      if not ready:
          raise Exception("Circular dependency or missing prerequisite")

      # Execute ready calls in parallel
      results = await asyncio.gather(*[
          executor.execute(call["function"], call["arguments"])
          for call in ready
      ])

      # Record completions
      for call, result in zip(ready, results):
          completed[call["id"]] = result
          pending.remove(call)

  return completed
```

Testing the Execution Layer
Thorough testing ensures your execution layer behaves correctly under various conditions. Test both individual tools and the execution infrastructure.

Unit test implementations with mocked external services:

```python
class TestSecurityScanTool:
  def setup_method(self):
      self.executor = ToolExecutor()
      self.mock_scanner = Mock()
      self.executor.scanner = self.mock_scanner

  def test_scan_returns_vulnerabilities(self):
      self.mock_scanner.scan.return_value = [
          {"severity": "high", "type": "sql_injection", "file": "auth.py", "line": 42}
      ]

      result = self.executor.execute("analyze_code_security", {"pr_number": 1247})

      assert result["success"] == True
      assert len(result["data"]["vulnerabilities"]) == 1
      assert result["data"]["vulnerabilities"][0]["type"] == "sql_injection"

  def test_scan_handles_empty_results(self):
      self.mock_scanner.scan.return_value = []

      result = self.executor.execute("analyze_code_security", {"pr_number": 1247})

      assert result["success"] == True
      assert result["data"]["summary"] == "No security issues found"
```

Integration tests verify real external service interaction:

```python
@pytest.mark.integration
class TestGitHubIntegration:
  def test_fetch_real_pr(self):
      # Use a known test repository
      executor = ToolExecutor(github_token=os.environ["GITHUB_TOKEN"])

      result = executor.execute("get_pr_details", {
          "pr_number": 1  # Known test PR
      })

      assert result["success"] == True
      assert "title" in result["data"]
      assert "files" in result["data"]
```

Test error scenarios to ensure graceful handling:

```python
def test_api_timeout_handling(self):
  self.mock_github.get_pr_details.side_effect = TimeoutError("API timeout")

  result = self.executor.execute("get_pr_details", {"pr_number": 1247})

  assert result["success"] == False
  assert "timeout" in result["error"].lower()
  assert "suggested_action" in result

def test_rate_limit_handling(self):
  self.mock_github.get_pr_details.side_effect = RateLimitError("Rate limit exceeded")

  result = self.executor.execute("get_pr_details", {"pr_number": 1247})

  assert result["success"] == False
  assert "rate limit" in result["error"].lower()
```

Robust Error Handling
Errors in agent systems are decision points. When a tool fails, the agent must decide what to do next. Agent-oriented error handling provides information the agent can reason about—not just "Connection refused" but structured context about what failed, why, and what alternatives exist.

Structured error responses give agents recovery options:

```python
def create_error_response(error_type, message, context=None, recovery_options=None):
  return {
      "success": False,
      "error": {
          "type": error_type,  # rate_limit, timeout, not_found, permission_denied
          "message": message,
          "retryable": error_type in ["rate_limit", "timeout", "service_unavailable"],
          "context": context or {},
          "recovery_options": recovery_options or []
      }
  }
```

Retry with exponential backoff handles transient failures:

```python
async def with_retry(operation, max_attempts=3, base_delay=1):
  for attempt in range(max_attempts):
      try:
          return await operation()
      except (TimeoutError, RateLimitError) as e:
          if attempt < max_attempts - 1:
              delay = base_delay * (2 ** attempt)
              await asyncio.sleep(delay)
  return create_error_response("service_unavailable", "Operation failed after retries")
```

Graceful degradation provides partial value when full functionality is unavailable. If the primary security scanner fails, try a backup. If that fails, use basic pattern matching. Return partial results with notes about limitations rather than complete failures.

Circuit breakers prevent cascading failures by stopping calls to repeatedly failing services. When a service fails five times, the circuit opens and subsequent calls fail immediately for a recovery period, protecting both the agent and the failing service.

Summary
The execution layer transforms function calls into real actions by routing calls to implementations, interacting with external APIs, and formatting results for the model. Careful integration with services like GitHub and security scanners requires handling authentication, rate limits, and comprehensive error cases.

Result formatting should be concise, consistent, and actionable. Include summaries that help the model understand results without processing every detail. Handle large results through truncation or pagination.

Execution context provides ambient information like repository name, permissions, and call history. This context enables permission checking, caching, and smarter execution decisions. Async execution improves performance by running independent operations concurrently.

Robust error handling provides structured responses that help agents decide how to recover. Retry strategies use exponential backoff for transient failures. Graceful degradation offers fallbacks when primary tools fail. Circuit breakers prevent cascading failures from overwhelming services.

Testing the execution layer requires unit tests with mocked services, integration tests against real APIs, and error scenario testing. Thorough testing ensures reliable behavior in production.

Key Takeaways:

The execution layer routes function calls to implementations and formats results for the model
External API integration requires careful handling of authentication, rate limits, and errors
Format results to be concise, consistent, and include actionable summaries
Execution context provides ambient information for permission checking and caching
Async execution enables parallel tool calls for better performance
Structure error responses with type, context, and recovery options for agent reasoning
Implement retry logic, graceful degradation, and circuit breakers for resilience
Test both individual tools and the execution infrastructure thoroughly