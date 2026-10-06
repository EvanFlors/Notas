## When Plausible Code Is Wrong

Imagine you ask an AI assistant to add a new API endpoint using your company's internal framework. It generates code that looks perfect: clean structure, proper error handling, comprehensive tests. The code compiles, the tests pass, and you merge it. A week later, production breaks because the assistant used an API method that was deprecated six months ago. The code looked correct, but it was wrong.

This is why hallucinations are a production risk. Hallucinations in code are not just wrong answers. They are broken APIs, incorrect assumptions, and subtle misconfigurations. When AI generates code that looks plausible but uses nonexistent functions, the result is wasted time and potential incidents.

In this lesson, you will learn how to reduce hallucinations in AI-generated code by grounding models in authoritative sources, validating outputs before merge, and enforcing verification gates. You will understand why hallucinations happen, how to detect them, and how to prevent them through workflow design.

By the end, you will have a practical framework for hallucination-resistant engineering that catches incorrect code before it reaches production, even when it looks correct.

Why Hallucinations Are a Production Risk
The risk increases in fast-moving codebases, where APIs change quickly. AI tools trained on older examples may produce outdated patterns. Without verification, these errors slip into production. When codebases evolve quickly, AI tools see outdated information, and they generate code based on that outdated information.

Consider what happens without verification. An AI assistant generates code using a deprecated API. The code looks correct because it follows old patterns. It compiles because the old API still exists but is deprecated. It works in tests because tests use the old API. But in production, the new API is required, and the code fails. With verification, the deprecated API is caught before merge.

The Most Common Hallucination Patterns
In AI-assisted development, hallucinations usually show up as:

Calling functions that do not exist: the assistant invents API methods that look plausible but do not exist.

Using deprecated libraries or outdated arguments: the assistant uses old patterns that no longer work.

Inventing configuration keys: the assistant creates config options that are not supported.

Assuming defaults that are not true: the assistant assumes behavior that does not match reality.

These are predictable, which means they are preventable. When patterns are predictable, they can be caught. When patterns are unpredictable, they slip through.

The Core Principle: Trust, Then Verify
AI can propose. Your workflow must verify. This is not about distrust. It is about understanding that language models are probabilistic and cannot guarantee correctness. They generate plausible code, not necessarily correct code.

Verification should be automated wherever possible. If verification requires manual steps, it will be skipped under time pressure. This is why compilation, static checks, and tests are so important: they make verification automatic. When verification is automatic, it is consistent. When verification is manual, it is inconsistent.

Using Citations and References in Prompts
For complex changes, require the assistant to cite the source it used. This forces grounding and gives reviewers a trail to follow. A simple rule is: if the output depends on an API or configuration, it must reference the authoritative documentation or schema.

Consider what happens with citations. An AI assistant generates code using an API. It cites the documentation it used. Reviewers can verify that the documentation is current and that the code matches it. Without citations, reviewers cannot verify sources, and hallucinations slip through.

Hallucinations in Configuration and Infrastructure
Hallucinations are not limited to code. They often appear in:

Deployment configuration: incorrect settings that look plausible but do not work.

Infrastructure templates: invalid resource configurations that cause deployment failures.

Monitoring and alerting rules: incorrect queries that produce false alerts or miss real issues.

These artifacts are harder to test and can create silent failures. Treat them with the same verification discipline as code. When infrastructure is verified, failures are prevented. When infrastructure is not verified, failures happen silently.

A Practical Example: Wrong API Version
Consider a tool that generates code using an API version that was deprecated last quarter. The code may compile, but it will fail in production. If your workflow pulls the current version of the API docs and runs a contract test, this mistake is caught immediately.

The code looks correct. It uses the right patterns. But it uses the wrong version. Without verification, this code ships. With verification, this code is caught. When verification is in place, mistakes are prevented. When verification is missing, mistakes ship.


Before diving into grounding and verification gates, consider how hallucination resistance is a workflow: grounding, verification, and explicit failure handling work together to prevent incorrect code from reaching production.

Grounding with Authoritative Sources
The simplest way to reduce hallucinations is to ground the model in the correct documentation:

Retrieve the exact API docs for the current version: ensure the model sees current information.

Include only the relevant sections: reduce noise and focus on what matters.

Treat external docs as untrusted unless they are official: verify that sources are authoritative.

This reduces guesswork and improves output correctness. When models are grounded in authoritative sources, they produce correct code. When models are not grounded, they guess, and guesses are often wrong.

Retrieval Hygiene
Grounding only works if the retrieved sources are correct. Use a curated list of documentation sources and keep them updated. If a documentation page is outdated, the model will faithfully reproduce the outdated behavior.

In practice, teams store a versioned documentation snapshot or generate API references from code. This ensures the tool sees the current truth, not a stale wiki page. When sources are current, outputs are correct. When sources are stale, outputs are incorrect.

Verification Gates That Catch Hallucinations
The most effective gates are:

Compilation or type checks: catch nonexistent symbols. If a function does not exist, compilation fails.

Unit tests: verify expected behavior. If behavior is wrong, tests fail.

Static analysis: catch deprecated or unsafe APIs. If APIs are deprecated, analysis flags them.

These checks provide objective evidence and prevent "plausible" code from shipping. When checks are automatic, hallucinations are caught. When checks are manual, hallucinations slip through.

Golden Tests for Known Behaviors
Golden tests capture expected outputs for a set of known inputs. They are especially useful when AI outputs are involved because they detect subtle changes that still pass basic tests. Use golden tests sparingly for critical flows where behavior must not drift.

Consider what happens with golden tests. An AI assistant generates code that produces output. A golden test compares the output to expected output. If the output differs, the test fails. This catches subtle changes that basic tests miss. When golden tests are in place, behavior drift is detected. When golden tests are missing, behavior drift is not detected.

Schema-Driven Verification
When possible, use schemas to validate outputs. API schemas, configuration schemas, and type definitions can all serve as validation targets. This reduces the burden on manual review and prevents hallucinated fields or parameters from slipping into production.

Consider what happens with schema validation. An AI assistant generates code that calls an API. A schema validator checks that the code matches the API schema. If the code uses fields that do not exist, validation fails. This prevents hallucinations from shipping. When schemas are validated, hallucinations are caught. When schemas are not validated, hallucinations slip through.

Here is an example schema validation system:

schema-validation-system.py
```python
#!/usr/bin/env python3
"""
Schema validation system for AI-generated code.
Validates API calls, configuration, and outputs against schemas.
"""

import json
import ast
from typing import Dict, List, Optional, Any
from dataclasses import dataclass

@dataclass
class ValidationError:
  """A schema validation error."""
  field: str
  message: str
  expected: Any
  actual: Any

class SchemaValidator:
  """Validates code against schemas."""

  def __init__(self, schema: Dict):
      self.schema = schema

  def validate_api_call(self, code: str, api_name: str) -> List[ValidationError]:
      """Validate an API call against its schema."""
      errors = []

      # Parse code to extract API call
      tree = ast.parse(code)
      api_calls = self._extract_api_calls(tree, api_name)

      # Get schema for this API
      api_schema = self.schema.get("apis", {}).get(api_name)
      if not api_schema:
          errors.append(ValidationError(
              field="api",
              message=f"API {api_name} not found in schema",
              expected=None,
              actual=api_name
          ))
          return errors

      # Validate each API call
      for call in api_calls:
          call_errors = self._validate_call_against_schema(call, api_schema)
          errors.extend(call_errors)

      return errors

  def _extract_api_calls(self, tree: ast.AST, api_name: str) -> List[ast.Call]:
      """Extract API calls from AST."""
      calls = []

      for node in ast.walk(tree):
          if isinstance(node, ast.Call):
              if isinstance(node.func, ast.Attribute):
                  if node.func.attr == api_name:
                      calls.append(node)
              elif isinstance(node.func, ast.Name):
                  if node.func.id == api_name:
                      calls.append(node)

      return calls

  def _validate_call_against_schema(
      self,
      call: ast.Call,
      schema: Dict
  ) -> List[ValidationError]:
      """Validate a single API call against schema."""
      errors = []

      # Extract arguments
      args = {}
      for i, arg in enumerate(call.args):
          if isinstance(arg, ast.keyword):
              args[arg.arg] = self._extract_value(arg.value)
          elif i < len(schema.get("parameters", [])):
              param_name = schema["parameters"][i]["name"]
              args[param_name] = self._extract_value(arg)

      # Validate required parameters
      required_params = schema.get("required", [])
      for param in required_params:
          if param not in args:
              errors.append(ValidationError(
                  field=param,
                  message=f"Required parameter {param} is missing",
                  expected="present",
                  actual="missing"
              ))

      # Validate parameter types
      param_schemas = schema.get("parameters", {})
      for param_name, param_value in args.items():
          if param_name in param_schemas:
              param_schema = param_schemas[param_name]
              expected_type = param_schema.get("type")
              actual_type = type(param_value).__name__

              if not self._type_matches(expected_type, actual_type):
                  errors.append(ValidationError(
                      field=param_name,
                      message=f"Type mismatch for {param_name}",
                      expected=expected_type,
                      actual=actual_type
                  ))

      return errors

  def _extract_value(self, node: ast.AST) -> Any:
      """Extract value from AST node."""
      if isinstance(node, ast.Constant):
          return node.value
      elif isinstance(node, ast.Str):  # Python < 3.8
          return node.s
      elif isinstance(node, ast.Num):  # Python < 3.8
          return node.n
      else:
          return None

  def _type_matches(self, expected: str, actual: str) -> bool:
      """Check if types match."""
      type_mapping = {
          "string": ["str"],
          "integer": ["int"],
          "number": ["int", "float"],
          "boolean": ["bool"],
          "array": ["list"],
          "object": ["dict"]
      }

      expected_types = type_mapping.get(expected, [expected])
      return actual.lower() in [t.lower() for t in expected_types]

  def validate_config(self, config: Dict, config_schema: Dict) -> List[ValidationError]:
      """Validate configuration against schema."""
      errors = []

      # Validate required fields
      required_fields = config_schema.get("required", [])
      for field in required_fields:
          if field not in config:
              errors.append(ValidationError(
                  field=field,
                  message=f"Required field {field} is missing",
                  expected="present",
                  actual="missing"
              ))

      # Validate field types
      properties = config_schema.get("properties", {})
      for field, value in config.items():
          if field in properties:
              field_schema = properties[field]
              expected_type = field_schema.get("type")
              actual_type = type(value).__name__

              if not self._type_matches(expected_type, actual_type):
                  errors.append(ValidationError(
                      field=field,
                      message=f"Type mismatch for {field}",
                      expected=expected_type,
                      actual=actual_type
                  ))

      return errors
```

Here is an example API schema definition:

api-schema.json
```json
{
"apis": {
  "create_user": {
    "description": "Create a new user",
    "parameters": {
      "email": {
        "type": "string",
        "required": true,
        "format": "email"
      },
      "name": {
        "type": "string",
        "required": true
      },
      "role": {
        "type": "string",
        "required": false,
        "enum": ["admin", "user", "guest"]
      }
    },
    "required": ["email", "name"]
  },
  "get_user": {
    "description": "Get user by ID",
    "parameters": {
      "user_id": {
        "type": "integer",
        "required": true
      }
    },
    "required": ["user_id"]
  }
},
"config_schemas": {
  "database": {
    "type": "object",
    "properties": {
      "host": {
        "type": "string",
        "required": true
      },
      "port": {
        "type": "integer",
        "required": false,
        "default": 5432
      },
      "ssl": {
        "type": "boolean",
        "required": false,
        "default": true
      }
    },
    "required": ["host"]
  }
}
}
```

Fail Fast with Explicit Errors
When a verification step fails, the workflow should stop and report a clear error. This makes the correction path obvious: fix the usage, update the docs, or adjust the prompt. Silent failures are the enemy of reliability.

Consider what happens with silent failures. A verification step fails, but the workflow continues. The error is logged but not surfaced. Developers do not see the error, so they do not fix it. The incorrect code ships. With explicit errors, failures are visible, and corrections are made. When errors are explicit, failures are fixed. When errors are silent, failures persist.

Tool-Assisted Verification
Some teams use small tools to validate outputs before they are merged, such as schema validators or API contract validators. These tools are lightweight and can be invoked automatically as part of an AI workflow. They shift verification from "manual check" to "deterministic gate."

When tools validate outputs, verification is automatic. When tools are not used, verification is manual. The goal is to make verification automatic so that it is consistent and reliable.

Testing Against Real Environments
For critical paths, test against a staging environment with realistic data. This catches errors that unit tests miss, such as incorrect assumptions about permissions or data shapes. It also provides confidence that the AI-generated change behaves correctly in production-like conditions.

Consider what happens with staging tests. An AI assistant generates code that works in unit tests. But staging tests reveal that the code assumes permissions it does not have. The code fails in staging, preventing a production failure. When staging tests are run, production failures are prevented. When staging tests are skipped, production failures happen.

Use Contract Tests for APIs
If your service exposes APIs, contract tests are a strong hallucination defense. They ensure the AI-generated code respects expected request and response shapes. Contract tests are especially useful when multiple teams share an API and documentation tends to lag.

When contract tests are in place, API hallucinations are caught. When contract tests are missing, API hallucinations slip through. The goal is to make contract tests automatic so that API correctness is verified consistently.


Summary: Hallucination Resistance Is Engineering Discipline
Hallucinations are a predictable failure mode. You reduce them by grounding the model in authoritative sources and enforcing verification gates before merge. The workflow matters more than the model. When workflows are well-designed, hallucinations are prevented. When workflows are poorly designed, hallucinations slip through.

Reducing Hallucinations Over Time
You can reduce hallucinations by:

Keeping internal documentation current: ensure retrieval sources are up to date.

Adding retrieval sources for newly introduced APIs: when APIs change, update sources.

Updating prompt templates with common pitfalls: learn from mistakes and prevent repeats.

This creates a feedback loop where the tool gets better as the codebase evolves. When feedback loops are in place, systems improve. When feedback loops are missing, systems degrade.

Aligning Documentation with Code Changes
Hallucination risk increases when documentation lags behind code. If you update an API, update the docs in the same PR. This keeps retrieval sources current and reduces mismatch. When documentation is aligned with code, hallucinations are reduced. When documentation lags, hallucinations increase.

Building a Hallucination Feedback Loop
When you catch a hallucination, add a regression test or update the prompt template to avoid the pattern. Over time, these updates create a corpus of "known pitfalls" that the tool avoids, reducing repeated mistakes.

When feedback loops are in place, mistakes are learned from. When feedback loops are missing, mistakes repeat. The goal is to make every hallucination a learning opportunity.

Managing Hallucination Debt
Hallucination debt accumulates when teams accept small inaccuracies "just to get it working." Over time, this creates brittle systems. The fix is to treat hallucination fixes as part of the definition of done, not as optional follow-ups.

When fixes are required, debt is managed. When fixes are optional, debt accumulates. The goal is to make fixes mandatory so that debt does not accumulate.

Trade-offs and Practical Limits
No team can verify everything. Focus verification on high-impact surfaces and keep low-risk tasks lightweight. The goal is not perfect correctness. The goal is predictable, reviewable changes that do not surprise production.

When verification is focused, it is manageable. When verification is comprehensive, it is overwhelming. The goal is to verify what matters most, not everything.

Common Pitfalls and Solutions
Pitfall: trusting generated code without verification. Solution: enforce compilation and tests for every AI-assisted change. When verification is required, hallucinations are caught. When verification is optional, hallucinations slip through.

Pitfall: using outdated docs. Solution: pin documentation versions and keep them updated in your retrieval sources. When docs are current, hallucinations are reduced. When docs are outdated, hallucinations increase.

Pitfall: allowing silent failures. Solution: fail fast and surface errors clearly. When errors are explicit, failures are fixed. When errors are silent, failures persist.

Pitfall: no grounding. Solution: ground models in authoritative sources. When models are grounded, hallucinations are reduced. When models are not grounded, hallucinations increase.

Pitfall: no feedback loop. Solution: learn from hallucinations and update prompts and tests. When feedback loops are in place, systems improve. When feedback loops are missing, systems degrade.

Key concepts to remember
Ground in current docs—hallucinations decrease when the model sees authoritative sources
Verify before merge—compilation, tests, and static analysis are mandatory
Fail fast—clear errors reduce wasted time and risk
Workflow beats model—process is your strongest control
Build feedback loops—learn from hallucinations and improve over time
Focus verification—verify high-impact surfaces, keep low-risk tasks lightweight
Align documentation—keep docs current with code changes