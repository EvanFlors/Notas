## The Anatomy of a Tool Schema
Your agent has access to twenty tools, but it keeps calling the wrong ones. When asked to check test coverage, it calls the security scanner. When asked to post a comment, it calls the linter. The tools work perfectly in isolation—the problem is the agent cannot figure out which to use.

The issue is almost always schema quality. Tool schemas are not just technical specifications; they are the instructions that guide model behavior. Vague descriptions, confusing parameter names, and missing context lead to unreliable tool selection.

In this lesson, you will learn how to craft schemas that enable accurate tool selection, reduce parameter errors, and make your agent's capabilities discoverable.

By the end, you will understand that schema design is not an afterthought but a core skill for building reliable agents.

Schema Components
A tool schema is the contract between your agent and its capabilities. It tells the language model what a function does, what inputs it accepts, and what constraints apply. Well-designed schemas enable reliable tool use; poorly designed ones lead to confusion, errors, and frustrated debugging.

Every tool schema has three essential components: a name, a description, and a parameter specification. Each component serves a distinct purpose in helping the model make good decisions.

The name should be clear, action-oriented, and follow consistent conventions. For a code review agent, names like get_pr_details, analyze_code_security, and post_review_comment immediately convey purpose. Avoid vague names like process_data or do_action that force the model to rely entirely on descriptions.

Naming conventions matter for consistency. Choose a style and stick with it: snake_case or camelCase, verb-first or noun-first. A code review agent might use verb_noun format: get_pr_details, check_test_coverage, add_pr_comment. Consistency helps the model recognize patterns and select appropriate tools.

The description is the most important part of the schema. The model decides whether to use a tool based almost entirely on its description. A good description explains:

What the function does in concrete terms
When the function should be used (and when it should not)
What the function returns
Any important context or constraints
Compare these descriptions for a security scanning tool:

Poor: "Scans code for issues"

Good: "Analyzes source code files for security vulnerabilities including SQL injection, XSS, and authentication flaws. Use this after retrieving PR details to identify security issues that should block merge. Returns a list of vulnerabilities with severity, line numbers, and remediation suggestions. Only scans files included in the PR diff."

The good description tells the model exactly what the tool does, when to use it in the workflow, what it returns, and what its scope is. This specificity guides correct usage.

The parameter specification defines what inputs the function accepts. Each parameter needs a type, description, and indication of whether it is required. Optional parameters should have sensible defaults documented.

```json
{
"name": "analyze_code_security",
"description": "Analyzes source code files for security vulnerabilities...",
"parameters": {
  "type": "object",
  "properties": {
    "pr_number": {
      "type": "integer",
      "description": "The pull request number to analyze"
    },
    "file_paths": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Specific files to scan. If omitted, scans all changed files in the PR"
    },
    "severity_threshold": {
      "type": "string",
      "enum": ["low", "medium", "high", "critical"],
      "description": "Minimum severity to report. Default: 'medium'"
    },
    "categories": {
      "type": "array",
      "items": {"type": "string", "enum": ["injection", "auth", "crypto", "xss", "config"]},
      "description": "Vulnerability categories to check. Default: all categories"
    }
  },
  "required": ["pr_number"]
}
}
```

This schema provides clear types, helpful descriptions for each parameter, enumerates valid values where applicable, and distinguishes required from optional parameters.

![The three essential components of a tool schema](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson02-schema-anatomy.svg)

Writing Effective Descriptions
Descriptions are where most schema quality issues arise. The model cannot read your code or understand your system architecture—it only knows what the description tells it. Invest time in writing descriptions that leave no ambiguity.

Be specific about purpose. Instead of "Gets PR information," write "Retrieves metadata for a pull request including title, author, branch names, approval status, CI check results, and list of changed files. Use this as the first step when reviewing a PR to understand its scope."

Explain the context of use. When should this tool be called? What should happen before and after? "Call this after get_pr_details to analyze security in the changed files. The results should be included in the review summary."

Describe the output format. What does the function return? "Returns a JSON object with 'vulnerabilities' array containing objects with 'severity', 'file', 'line', 'type', and 'description' fields. Returns empty array if no issues found."

Note limitations and constraints. What can the tool not do? "Only analyzes Python and JavaScript files. Maximum 50 files per scan. Large files over 10,000 lines are truncated."

Include examples when helpful. For complex parameters, show example values: "file_paths accepts glob patterns like 'src/*.py' or specific paths like 'auth/handler.py'"

Here is a complete example of a well-documented tool:

```json
{
"name": "check_test_coverage",
"description": "Calculates test coverage for files changed in a pull request. Use this to verify that new or modified code has adequate test coverage before approving a PR. Returns coverage percentage per file and identifies untested functions. Requires the repository to have a configured test suite. Coverage below 80% should be flagged for review.",
"parameters": {
  "type": "object",
  "properties": {
    "pr_number": {
      "type": "integer",
      "description": "The pull request number to check coverage for"
    },
    "coverage_threshold": {
      "type": "number",
      "description": "Minimum acceptable coverage percentage (0-100). Default: 80. Files below this threshold are flagged."
    },
    "include_existing": {
      "type": "boolean",
      "description": "Whether to include coverage for unchanged lines in modified files. Default: false (only checks new/changed lines)"
    }
  },
  "required": ["pr_number"]
}
}
```

This description tells the model everything it needs to use the tool correctly: what it does, when to use it, what it returns, prerequisites, and how to interpret results.

Parameter Design Patterns
How you structure parameters affects both usability and reliability. Several patterns help you design parameters that work well with LLM function calling.

Use enums for constrained values. When a parameter has a fixed set of valid values, enumerate them. This prevents the model from inventing invalid options and provides clear guidance on available choices.

```json
{
"merge_method": {
  "type": "string",
  "enum": ["merge", "squash", "rebase"],
  "description": "How to merge the PR. 'squash' combines commits, 'rebase' maintains linear history"
}
}
```

Provide sensible defaults. Optional parameters should have defaults that work for common cases. Document the default in the description so the model knows what happens when it omits the parameter.


```json
{
"severity_threshold": {
  "type": "string",
  "enum": ["low", "medium", "high", "critical"],
  "description": "Minimum severity to report. Default: 'medium'. Use 'low' for thorough audits, 'critical' for quick checks"
}
}
```

Use objects for complex inputs. When you need structured data, use nested objects rather than multiple flat parameters or encoded strings.

```json
{
"review_config": {
  "type": "object",
  "properties": {
    "check_security": {"type": "boolean"},
    "check_style": {"type": "boolean"},
    "check_coverage": {"type": "boolean"},
    "min_coverage": {"type": "number"}
  },
  "description": "Configuration for what aspects to review"
}
}
```

Use arrays for multiple items. When the model needs to specify multiple values, use arrays with item schemas.

```json
{
"file_paths": {
  "type": "array",
  "items": {"type": "string"},
  "description": "List of file paths to analyze, e.g., ['src/auth.py', 'src/handlers/*.py']"
}
}
```

Avoid ambiguous types. If a parameter could reasonably be multiple types, pick one and document it clearly. "pr_number" should be an integer, not a string that might contain "PR-1247" or "#1247" or just "1247".

Keep required parameters minimal. Only mark parameters as required if the function truly cannot operate without them. More optional parameters with good defaults means the model can call the function with less information while still getting useful results.

![Parameter design patterns for reliable function calling](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson02-param-patterns.svg)

Schema Composition and Reuse
As you build more tools for your code review agent, you will notice common patterns. Similar parameters appear across multiple tools: pr_number, file_paths, severity levels. Schema composition helps you maintain consistency and reduce duplication.

Define common parameter patterns. Create templates for frequently used parameters:

```python
PR_NUMBER_PARAM = {
  "type": "integer",
  "description": "The pull request number"
}

FILE_PATHS_PARAM = {
  "type": "array",
  "items": {"type": "string"},
  "description": "File paths to operate on. Supports glob patterns like 'src/*.py'"
}

SEVERITY_PARAM = {
  "type": "string",
  "enum": ["low", "medium", "high", "critical"],
  "description": "Severity level threshold"
}
```

Then compose schemas using these building blocks:

```python
def create_tool_schema(name, description, params, required):
  return {
      "name": name,
      "description": description,
      "parameters": {
          "type": "object",
          "properties": params,
          "required": required
      }
  }

security_scan_schema = create_tool_schema(
  name="analyze_code_security",
  description="Scans code for security vulnerabilities...",
  params={
      "pr_number": PR_NUMBER_PARAM,
      "file_paths": FILE_PATHS_PARAM,
      "severity_threshold": SEVERITY_PARAM
  },
  required=["pr_number"]
)
```

Maintain a schema registry. As your tool count grows, centralize schema definitions. This makes it easy to update common patterns, ensures consistency, and provides a single source of truth for available tools.

```python
class ToolRegistry:
  def __init__(self):
      self.tools = {}

  def register(self, schema):
      self.tools[schema["name"]] = schema

  def get_schemas_for_task(self, task_type):
      # Return relevant tools based on task
      if task_type == "security_review":
          return [self.tools["get_pr_details"],
                  self.tools["analyze_code_security"],
                  self.tools["post_review_comment"]]
      # ... other task types

  def all_schemas(self):
      return list(self.tools.values())
```

Version your schemas. When you modify a tool's parameters, existing agents might break. Consider versioning strategies: ```analyze_code_security_v2``` alongside the original, or tracking schema versions in metadata.

Testing and Validating Schemas
Schemas require testing just like code. A schema that looks correct might cause unexpected model behavior in practice. Several testing strategies help ensure schema quality.

Validate schema syntax. Use JSON Schema validators to catch structural errors before runtime. Invalid schemas cause hard-to-debug failures.

```python
import jsonschema

def validate_tool_schema(schema):
  # Validate the schema structure itself
  meta_schema = {
      "type": "object",
      "required": ["name", "description", "parameters"],
      "properties": {
          "name": {"type": "string"},
          "description": {"type": "string"},
          "parameters": {"type": "object"}
      }
  }
  jsonschema.validate(schema, meta_schema)

  # Validate parameter schema is valid JSON Schema
  jsonschema.Draft7Validator.check_schema(schema["parameters"])
```

Test model comprehension. Give the model scenarios and check if it selects the right tool with correct parameters. Create test cases for each tool:

```python
def test_security_scan_selection():
  response = call_model_with_tools(
      message="Check PR 1247 for SQL injection vulnerabilities",
      tools=[security_scan_schema, coverage_schema, comment_schema]
  )

  assert response.tool_name == "analyze_code_security"
  assert response.arguments["pr_number"] == 1247
  assert "injection" in response.arguments.get("categories", [])
```

Test edge cases. What happens with ambiguous requests? Missing information? Conflicting instructions?

```python
def test_ambiguous_request():
  # Model should ask for clarification or use defaults, not hallucinate
  response = call_model_with_tools(
      message="Review the latest PR",  # No PR number specified
      tools=[get_pr_details_schema]
  )

  # Model should either ask for PR number or not call the function
  assert response.tool_name is None or "which PR" in response.content.lower()
```

Test description clarity. If the model consistently misuses a tool, the description likely needs improvement. Track tool selection accuracy and iterate on descriptions for problematic tools.

Validate at runtime. Even with good schemas, validate actual arguments before execution:

```python
def execute_tool(tool_name, arguments, schemas):
  schema = schemas[tool_name]

  # Validate arguments against parameter schema
  try:
      jsonschema.validate(arguments, schema["parameters"])
  except jsonschema.ValidationError as e:
      return {"error": f"Invalid arguments: {e.message}"}

  # Execute the actual function
  return tool_implementations[tool_name](**arguments)
```

Common Schema Mistakes
Learning from common mistakes helps you avoid them in your own schemas.

Vague descriptions lead to misuse. "Handles PR operations" tells the model nothing. Be specific about what the function does, when to use it, and what it returns.

Missing context causes selection errors. If you have both ```get_pr_comments``` and ```get_review_comments```, explain the difference. "Review comments are feedback on code changes; PR comments are general discussion on the pull request."

Overly complex parameters confuse the model. If a parameter requires extensive explanation, consider splitting the function or simplifying the interface. A function with 15 parameters is harder to use correctly than three focused functions.

Inconsistent naming creates confusion. If one function uses ```pr_number``` and another uses ```pull_request_id``` for the same concept, the model might not recognize they are equivalent.

Missing enums for constrained values let the model invent invalid options. If only "merge", "squash", and "rebase" are valid, enumerate them rather than accepting any string.

Undocumented defaults leave the model guessing. If ```severity_threshold``` defaults to "medium", say so explicitly. The model cannot read your implementation.

No return value documentation makes it hard for the model to use results. If the function returns structured data, describe the format so the model knows how to interpret and use it.

Investing in schema quality pays dividends in agent reliability. Well-designed schemas reduce debugging time, improve model accuracy, and make your agent system more maintainable.

Summary
Tool schemas are contracts that define how agents interact with functions. Effective schemas have clear names, detailed descriptions, and well-typed parameters. The description is most critical—it determines whether the model uses the tool correctly.

Parameter design should use enums for constrained values, provide sensible defaults, and keep required parameters minimal. Schema composition and registries help maintain consistency as your tool count grows.

Testing schemas includes syntax validation, model comprehension testing, edge case handling, and runtime argument validation. Common mistakes include vague descriptions, missing context, overly complex parameters, and inconsistent naming.

Key Takeaways:

Descriptions are the most important part of schemas—they guide model behavior more than names or types
Be specific about what functions do, when to use them, what they return, and their limitations
Use enums for constrained values and document defaults for optional parameters
Compose schemas from common building blocks for consistency across tools
Test that models select correct tools and provide valid parameters for various scenarios
Validate arguments at runtime even with well-designed schemas