## Putting It All Together
You have learned the individual pieces: function calling mechanics, schema design, execution layers, and error handling. Now it is time to see how they combine into a working system. Theory without application is incomplete—this lesson bridges the gap.

We will build a complete code review agent that analyzes pull requests, identifies security vulnerabilities and code quality issues, and provides actionable feedback. This is not a toy example; it demonstrates production patterns you can adapt for your own agents.

In this lesson, you will see how schemas, execution, and error handling work together in a real system and understand the trade-offs involved in production agent design.

By the end, you will have a blueprint for building your own tool-using agents.

Designing the Complete System
Throughout this submodule, you have learned about function calling, tool schemas, execution layers, and error handling. Now we will synthesize these concepts by building a complete code review agent. This agent will analyze pull requests, identify security vulnerabilities and code quality issues, and provide actionable feedback to developers.

The code review agent demonstrates how all the pieces work together: well-designed schemas enable reliable tool selection, the execution layer handles external API interactions, and robust error handling ensures the agent can recover from failures. Building this agent end-to-end shows how theory translates to practice.

![Complete code review agent: schemas, execution, and orchestration working together](https://hrcdn.net/ai-engineering/module-4/dark/tool-integration-lesson04-architecture.svg)

Our agent will have five core capabilities: fetching PR details, analyzing code for security issues, checking test coverage, running style checks, and posting review comments. Each capability requires a tool with proper schema, implementation, and error handling.

Designing the Tool Set
Start by defining the tools the agent needs. Each tool serves a specific purpose in the review workflow, and the schemas must clearly communicate that purpose to the model.

PR Details Tool - The foundation for any review:

```python
get_pr_details_schema = {
  "name": "get_pr_details",
  "description": "Retrieves comprehensive information about a pull request including title, author, changed files, approval status, and CI results. Always call this first when starting a review to understand the scope and context of the changes.",
  "parameters": {
      "type": "object",
      "properties": {
          "pr_number": {
              "type": "integer",
              "description": "The pull request number to fetch details for"
          }
      },
      "required": ["pr_number"]
  }
}
```

Security Analysis Tool - Identifies vulnerabilities:

```python
analyze_security_schema = {
  "name": "analyze_code_security",
  "description": "Scans code files for security vulnerabilities including SQL injection, XSS, authentication flaws, and insecure cryptography. Use after getting PR details to analyze changed files. Returns vulnerabilities with severity, location, and remediation suggestions. Focus on files in security-sensitive areas like authentication, payment, and data handling.",
  "parameters": {
      "type": "object",
      "properties": {
          "pr_number": {
              "type": "integer",
              "description": "The PR to analyze"
          },
          "file_paths": {
              "type": "array",
              "items": {"type": "string"},
              "description": "Specific files to scan. If omitted, scans all changed files"
          },
          "severity_threshold": {
              "type": "string",
              "enum": ["low", "medium", "high", "critical"],
              "description": "Minimum severity to report. Default: medium"
          }
      },
      "required": ["pr_number"]
  }
}
```

Test Coverage Tool - Ensures adequate testing:

```python
check_coverage_schema = {
  "name": "check_test_coverage",
  "description": "Calculates test coverage for files changed in the PR. Returns coverage percentage per file and identifies untested functions. Coverage below 80% should be flagged. Use this to verify new code has adequate test coverage before approving.",
  "parameters": {
      "type": "object",
      "properties": {
          "pr_number": {
              "type": "integer",
              "description": "The PR to check coverage for"
          },
          "coverage_threshold": {
              "type": "number",
              "description": "Minimum acceptable coverage percentage. Default: 80"
          }
      },
      "required": ["pr_number"]
  }
}
```

Style Check Tool - Enforces coding standards:

```python
check_style_schema = {
  "name": "check_code_style",
  "description": "Runs linter and style checks on changed files. Returns style violations organized by severity. Minor style issues should be noted but not block merge. Major issues (like missing type hints in public APIs) should be addressed.",
  "parameters": {
      "type": "object",
      "properties": {
          "pr_number": {
              "type": "integer",
              "description": "The PR to check"
          },
          "strict_mode": {
              "type": "boolean",
              "description": "If true, reports all violations. If false, only significant issues. Default: false"
          }
      },
      "required": ["pr_number"]
  }
}
```

Review Comment Tool - Posts feedback:

```python
post_comment_schema = {
  "name": "post_review_comment",
  "description": "Posts a review comment on the pull request. Use for summarizing findings at the end of review. For inline comments on specific code, include path and line number. Comments should be constructive and include specific suggestions for improvement.",
  "parameters": {
      "type": "object",
      "properties": {
          "pr_number": {
              "type": "integer",
              "description": "The PR to comment on"
          },
          "body": {
              "type": "string",
              "description": "The comment content in markdown format"
          },
          "path": {
              "type": "string",
              "description": "File path for inline comment. Omit for general PR comment"
          },
          "line": {
              "type": "integer",
              "description": "Line number for inline comment. Required if path is provided"
          },
          "review_action": {
              "type": "string",
              "enum": ["approve", "request_changes", "comment"],
              "description": "Review decision. Use 'request_changes' for blocking issues, 'approve' when all checks pass, 'comment' for observations only"
          }
      },
      "required": ["pr_number", "body"]
  }
}
```

These schemas work together as a coherent tool set. The descriptions explain when to use each tool and how they relate to the review workflow.

Building the Execution Layer
With schemas defined, implement the execution layer that makes these tools functional. The executor routes tool calls, validates inputs, handles external APIs, and formats results consistently.

Key execution patterns:

```python
class CodeReviewExecutor:
  def __init__(self, github_token, repo_name):
      self.github = GitHubClient(github_token)
      self.tools = {
          "get_pr_details": self._get_pr_details,
          "analyze_code_security": self._analyze_security,
          # ... other tools
      }

  async def execute(self, function_name, arguments):
      # Validate, execute, handle errors
      validation_errors = self._validate(function_name, arguments)
      if validation_errors:
          return {"success": False, "error_type": "validation_error", "errors": validation_errors}

      try:
          return await self.tools[function_name](**arguments)
      except Exception as e:
          return self._handle_error(e, function_name, arguments)
```

Each tool method follows a consistent pattern: fetch data from external services, format results with summaries and recommendations, and return structured responses that help the agent make decisions. The executor handles validation, error recovery, and result formatting uniformly across all tools.

Orchestrating the Agent
The agent orchestrates tools through the LLM's reasoning. It presents available tools, lets the model decide which to call, executes them, and incorporates results into the conversation.

Agent loop pattern:

```python
class CodeReviewAgent:
  async def review_pr(self, pr_number, review_focus=None):
      messages = [
          {"role": "system", "content": self._build_system_prompt(review_focus)},
          {"role": "user", "content": f"Please review pull request #{pr_number}"}
      ]

      for iteration in range(self.max_iterations):
          response = await self.llm.chat(messages=messages, tools=self.schemas)

          if response.tool_calls:
              # Execute tools and add results to conversation
              tool_results = await self._execute_tools(response.tool_calls)
              messages.append({"role": "assistant", "tool_calls": response.tool_calls})
              messages.extend(tool_results)
          else:
              # Agent provided final review
              return {"success": True, "review": response.content}
```

The system prompt guides the agent through the review workflow: get PR details first, then analyze security, check coverage, run style checks, and finally post findings. The LLM decides the exact sequence based on what it discovers.

Handling Real-World Complexity
Production agents face edge cases that require careful handling. Large PRs need batching—process files in chunks and stop early if critical issues are found. Flaky services require caching and fallbacks—use cached data when APIs fail, with clear notes about data freshness. Context limits need management—summarize old tool results when approaching token limits.

The key is graceful degradation: provide partial value when full functionality is unavailable, always communicate limitations clearly, and design error responses that help the agent decide how to proceed.

Complete Example Flow
A typical review flows through these steps:

Agent calls ```get_pr_details(1247)``` to understand scope
Agent calls ```analyze_code_security(1247)``` and finds a SQL injection vulnerability
Agent calls ```check_test_coverage(1247)``` and discovers coverage is 72%, below threshold
Agent calls ```check_code_style(1247)``` and notes 3 minor style issues
Agent calls ```post_review_comment(1247, review_action="request_changes")``` with a comprehensive summary

The agent orchestrates these calls based on what it discovers, not a predetermined sequence. Well-designed schemas guide tool selection, robust execution handles failures, and structured results enable informed decisions.

Summary
Building a code review agent brings together all the concepts from this submodule. Well-designed schemas communicate tool purposes clearly to the model. The execution layer handles external APIs with proper error management and result formatting. The agent orchestrates tools through the LLM's reasoning capabilities.

Production considerations include handling large PRs through batching, managing flaky services with caching and fallbacks, and preventing context overflow through summarization. The complete system demonstrates how function calling enables sophisticated agent behavior while maintaining reliability and control.

Key Takeaways:

Design tool schemas as a coherent set that work together for the review workflow
Implement execution with consistent patterns for validation, error handling, and result formatting
Use the LLM to orchestrate tool calls rather than hardcoding sequences
Handle production complexity: large PRs, flaky services, context limits
Provide actionable recommendations in tool results to guide agent decisions
Build resilience through caching, batching, and graceful degradation