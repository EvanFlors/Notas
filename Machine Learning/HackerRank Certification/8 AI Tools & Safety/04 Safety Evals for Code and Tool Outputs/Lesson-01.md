## When Working Code Is Still Insecure

Imagine you ask an AI assistant to add a new API endpoint for user profiles. It generates code that works perfectly: clean structure, proper error handling, comprehensive tests. You review it, merge it, and deploy. A week later, a security scan reveals that the endpoint accepts user input without validation and logs request bodies that contain passwords. The code works, but it is insecure.

This is why AI-generated code needs dedicated security evals. AI assistants can generate working code quickly, but they also generate insecure code quickly. The failure modes are predictable: missing validation, unsafe parsing, weak authentication, or dependency choices that introduce vulnerabilities.

In this lesson, you will learn how to build security-focused evaluation gates for AI-generated code, how to encode security invariants as automated checks, and how to create security regression packs that prevent repeat mistakes. You will understand why traditional testing is not enough, how to layer security checks, and how to balance protection with developer velocity.

By the end, you will have a practical security evaluation framework that catches unsafe patterns before they reach production, even when code looks correct.

Why AI-Generated Code Needs Dedicated Security Evals
Traditional security reviews catch some of this, but AI increases volume and changes the distribution of errors. If you rely only on manual review, unsafe patterns will slip through. When code volume increases, manual review becomes impractical. When error patterns change, manual review misses new issues.

Security evals are the solution. They make unsafe patterns visible and prevent them from being merged. When evals are automated, they scale with code volume. When evals are targeted, they catch the patterns that matter most.

Consider what happens without security evals. An AI assistant generates code that works but is insecure. Manual reviewers focus on functionality, not security. The code is merged, and vulnerabilities ship to production. With security evals, unsafe patterns are caught automatically, preventing vulnerabilities from shipping.

Security Invariants for AI-Assisted Code
Most teams already have implicit security invariants. The problem is that they are not enforced consistently. Examples:

All external inputs must be validated: user input, API responses, and file contents should be validated before use.

Access to sensitive data must go through an authorization layer: direct database access should be blocked, and authorization should be checked.

Secrets must never be logged: passwords, API keys, and tokens should never appear in logs.

Unsafe dynamic execution must be blocked: eval, exec, and shell execution should be restricted.

Turning these invariants into explicit checks is the fastest way to make AI-generated code safer. When invariants are explicit, they can be enforced. When invariants are implicit, they are forgotten.

Security invariants should be written down in the same place as repo rules. If a developer can see them, the assistant can be instructed to follow them. If the assistant can follow them, the evals can enforce them. This alignment reduces friction and makes security feel like part of normal development.

The Most Common AI Security Regressions
In practice, the top categories are:

Input validation failures: missing schema checks, weak type validation. AI assistants might generate code that accepts input without validating it.

Authorization bypasses: direct access to resources without policy checks. AI assistants might generate code that accesses data without checking permissions.

Unsafe deserialization: permissive parsers or dynamic evaluation. AI assistants might generate code that deserializes data unsafely.

Sensitive logging: printing user data, tokens, or secrets. AI assistants might add logging for debugging and accidentally log sensitive data.

Dependency risk: adding unvetted libraries for convenience. AI assistants might add dependencies without considering security implications.

These errors are often subtle. AI-generated code can look correct while still violating a security invariant. The code compiles, tests pass, but security is broken.

Example: An Authentication Regression That Looks Correct
An assistant might add a new endpoint and reuse an internal helper, but forget to call the authorization check. The endpoint works and tests pass because tests do not include access control. A security eval that ensures every route in a protected namespace uses auth middleware would catch this.

Consider what happens without the eval. The code looks correct. It uses the right patterns. It has tests. But it is missing authorization. Manual reviewers might miss this because they focus on functionality. With the eval, the missing authorization is caught automatically.

Why "Just Run Tests" Is Not Enough
Most test suites are not designed to detect security regressions. They verify behavior, not threat resistance. Security evals are complementary: they look for patterns and risky behaviors that functional tests do not cover.

Consider what happens with functional tests only. Tests verify that code works correctly. They do not verify that code is secure. An endpoint might work correctly but still be vulnerable to injection attacks. Security evals catch these vulnerabilities that functional tests miss.

A Concrete Example: Unsafe Parsing
Imagine an assistant adds a JSON parsing helper that uses a permissive deserializer. The code works in tests, but it allows arbitrary object execution. A security eval that flags unsafe deserialization would catch this even though functional tests pass.

The code looks correct. It parses JSON. It handles errors. But it is insecure. Functional tests do not catch this because they test functionality, not security. Security evals catch this because they test for unsafe patterns.

Security Reviews Versus Security Evals
Manual security review is valuable for complex logic and nuanced risk. Security evals are valuable for consistency and scale. A good workflow uses both:

Evals catch known patterns automatically: they scale with code volume and catch common mistakes.

Reviews inspect high-risk changes and approve exceptions: they handle complex cases that evals cannot catch.

This separation avoids reviewer fatigue and makes security a predictable part of the pipeline. When evals catch common issues, reviewers can focus on complex cases. When evals are missing, reviewers are overwhelmed.


Before diving into layered evaluation strategies, consider how security evals turn predictable AI failure modes into deterministic checks that prevent unsafe patterns from reaching production.

A Layered Security Evaluation Strategy
A practical security eval stack includes:

Static analysis: detect dangerous APIs and insecure patterns. This catches issues before code runs.

Dependency scanning: flag vulnerable or unapproved packages. This prevents known vulnerabilities from being introduced.

Secrets scanning: detect accidental leakage in diffs and logs. This prevents secrets from being committed.

Policy checks: enforce repo-specific security rules. This ensures code follows team security standards.

These checks are fast and can run on every PR. They do not replace human review, but they reduce the surface area that humans must inspect. When checks are layered, protection is comprehensive. When checks are single-layered, protection is incomplete.

Severity-Based Gating
Not every finding should block a merge. A practical system uses severity:

Critical: block merge. These are issues that must be fixed before merging.

High: block unless explicitly approved. These are serious issues that need review.

Medium: require a ticket or follow-up. These are issues that should be fixed but do not block merging.

Low: log for future cleanup. These are issues that can be addressed later.

This keeps the pipeline usable while still enforcing the most important protections. When gating is severity-based, critical issues are blocked while minor issues are tracked. When gating is binary, either everything blocks or nothing blocks, neither of which is ideal.

Security Regression Packs
Just as you have functional regression packs, you should have security regression packs. Examples:

A test that ensures auth middleware is always applied: this prevents authorization bypasses.

A test that fails if user input reaches database calls without validation: this prevents injection attacks.

A test that fails if logging includes sensitive fields: this prevents data leakage.

Security regression tests should focus on your actual incidents, not generic examples. When tests reflect real incidents, they prevent repeat mistakes. When tests are generic, they might miss real issues.

Policy-as-Code for Security
Security rules should be machine-readable. For example:

Deny new network calls outside approved domains: prevent external data exfiltration.

Deny direct database access without a data access helper: enforce authorization layers.

Deny writes to protected directories: prevent accidental modifications.

Policy-as-code turns security into a deterministic gate rather than a manual checklist. When policies are code, they are enforceable. When policies are documents, they are suggestions.

Building a Security Regression Pack in Practice
A simple process works:

List the top five security incidents or near misses: these are the mistakes your team has actually made.

Translate each into a test that fails when the pattern reappears: encode lessons learned into tests.

Run these tests on every AI-assisted PR: prevent repeat mistakes.

These tests become a guardrail for the exact failures your team has experienced. When tests reflect real incidents, they are high-value. When tests are generic, they are low-value.

Here is an example security regression test:

security-regression-test.py
```python
#!/usr/bin/env python3
"""
Security regression tests for AI-generated code.
Tests reflect real incidents to prevent repeat mistakes.
"""

import ast
import re
from typing import List, Dict

class SecurityRegressionTest:
  """Tests for security regressions in AI-generated code."""

  def test_auth_middleware_always_applied(self, code: str) -> bool:
      """
      Test: Auth middleware must be applied to all protected routes.
      Incident: AI generated endpoint without auth middleware.
      """
      # Parse code to find route definitions
      tree = ast.parse(code)

      protected_routes = []
      routes_with_auth = []

      for node in ast.walk(tree):
          # Look for route decorators
          if isinstance(node, ast.FunctionDef):
              decorators = [d.id if isinstance(d, ast.Name) else None
                          for d in node.decorator_list]

              # Check if route is in protected namespace
              if any('route' in str(d).lower() for d in decorators):
                  if '/api/protected/' in str(node):
                      protected_routes.append(node.name)

                      # Check if auth middleware is applied
                      if any('auth' in str(d).lower() or 'require_auth' in str(d).lower()
                             for d in decorators):
                          routes_with_auth.append(node.name)

      # All protected routes must have auth
      missing_auth = set(protected_routes) - set(routes_with_auth)
      if missing_auth:
          raise AssertionError(
              f"Protected routes missing auth middleware: {missing_auth}"
          )

      return True

  def test_user_input_validated(self, code: str) -> bool:
      """
      Test: User input must be validated before database calls.
      Incident: AI generated code that passed user input directly to DB.
      """
      tree = ast.parse(code)

      # Find database calls
      db_calls = []
      input_sources = []

      for node in ast.walk(tree):
          # Find database query calls
          if isinstance(node, ast.Call):
              if isinstance(node.func, ast.Attribute):
                  if 'query' in node.func.attr.lower() or 'execute' in node.func.attr.lower():
                      db_calls.append(node)

          # Find user input sources
          if isinstance(node, ast.Name):
              if node.id in ['request', 'input', 'user_input', 'params']:
                  input_sources.append(node)

      # Check if input is validated before DB calls
      # This is simplified - real implementation would track data flow
      if db_calls and input_sources:
          # Check for validation patterns
          validation_patterns = [
              r'validate',
              r'schema',
              r'check',
              r'verify'
          ]

          code_str = ast.unparse(tree)
          has_validation = any(re.search(pattern, code_str, re.IGNORECASE)
                            for pattern in validation_patterns)

          if not has_validation:
              raise AssertionError(
                  "User input used in database calls without validation"
              )

      return True

  def test_no_secrets_in_logs(self, code: str) -> bool:
      """
      Test: Secrets must never be logged.
      Incident: AI added logging that included API keys.
      """
      # Find logging calls
      tree = ast.parse(code)

      secret_patterns = [
          r'api[_-]?key',
          r'password',
          r'secret',
          r'token',
          r'credential'
      ]

      for node in ast.walk(tree):
          if isinstance(node, ast.Call):
              # Check if it's a logging call
              if isinstance(node.func, ast.Attribute):
                  if 'log' in node.func.attr.lower():
                      # Check arguments for secrets
                      for arg in node.args:
                          arg_str = ast.unparse(arg)
                          for pattern in secret_patterns:
                              if re.search(pattern, arg_str, re.IGNORECASE):
                                  raise AssertionError(
                                      f"Potential secret in log: {arg_str[:50]}"
                                  )

      return True
```

Here is an example security eval configuration:

security-evals.yaml
```yaml
# Security Evaluation Configuration

security_evals:
# Static analysis
static_analysis:
  enabled: true
  tools:
    - bandit  # Python security linter
    - semgrep  # Pattern-based security scanner
  severity_gating:
    critical: block_merge
    high: require_approval
    medium: warn_only
    low: log_only

# Dependency scanning
dependency_scanning:
  enabled: true
  tools:
    - safety  # Python dependency vulnerability scanner
    - npm audit  # Node.js dependency scanner
  action_on_vulnerability: block_merge

# Secrets scanning
secrets_scanning:
  enabled: true
  tools:
    - detect-secrets
    - trufflehog
  patterns:
    - api_key
    - password
    - secret
    - token
  action: block_merge

# Policy checks
policy_checks:
  enabled: true
  rules:
    - name: no_direct_db_access
      pattern: "db\\.query|db\\.execute"
      action: require_approval
    - name: no_eval_or_exec
      pattern: "eval\\(|exec\\("
      action: block_merge

# Regression tests
regression_tests:
  enabled: true
  test_files:
    - tests/security/test_auth_middleware.py
    - tests/security/test_input_validation.py
    - tests/security/test_secrets_logging.py
```

Security Evals for Tool Outputs
AI tools often generate non-code outputs, such as deployment scripts or configuration changes. These are equally risky. Add evals for:

Infrastructure changes: least privilege, no open ports. Infrastructure code can introduce vulnerabilities.

Configuration defaults: secure values, no debug flags. Configuration can expose systems.

Build scripts: no unsafe shell patterns. Build scripts can execute arbitrary code.

If the tool can change it, it should be evaluated. When only code is evaluated, infrastructure and configuration vulnerabilities slip through. When all outputs are evaluated, protection is comprehensive.

Managing False Positives
Security evals will sometimes flag safe code. If the developer experience becomes too noisy, the checks will be ignored. Use two techniques to reduce noise:

Suppress known safe patterns with explicit allowlists: document why patterns are safe and allow them.

Distinguish between blocking failures and informational warnings: only block critical issues, warn about others.

The goal is to keep the signal high so developers trust the system. When false positives are low, developers trust evals. When false positives are high, developers ignore evals.


Summary: Treat Security as a First-Class Eval
AI increases the volume of code changes and amplifies predictable security mistakes. Security evals make those mistakes visible and prevent them from shipping. The best approach is layered checks plus a small set of security regression tests that reflect your real incidents.

Security evals should be automatic, fast, and targeted. They should catch common mistakes without blocking legitimate work. When evals are well-designed, they improve security without slowing development.

Building Security Evals into Daily Development
Security evals work best when they are invisible to developers. That means:

Run them automatically in CI: developers do not need to remember to run them.

Provide clear, actionable failure messages: developers can fix issues quickly.

Link to guidance on how to fix failures: developers know what to do.

When the feedback is fast and clear, developers treat security checks as part of normal development rather than as a separate security process. When feedback is slow or unclear, developers ignore security checks.

Measuring Security Eval Effectiveness
Track a few simple metrics:

Number of security eval failures per week: are evals catching issues?

Time to fix security eval failures: are issues being fixed quickly?

Number of security incidents that bypassed the evals: are evals effective?

These metrics tell you whether the evals are helping or just adding noise. If incidents still occur, update the regression pack. If failures are too frequent, reduce false positives. When metrics are tracked, evals improve. When metrics are ignored, evals degrade.

Ownership and Maintenance
Security evals need owners. Assign an owner to the policy rules and another to regression packs. When a new incident occurs, it should automatically become a new regression test. This keeps the system aligned with real risk and prevents repeated failures.

When ownership is clear, evals are maintained. When ownership is unclear, evals drift. The goal is to make ownership explicit so that evals stay current and effective.

Common Pitfalls and Solutions
Pitfall: relying only on linting. Solution: add security-specific checks and regression tests. Linting catches style issues, not security issues. Security evals catch security issues.

Pitfall: scanning only code, not configs. Solution: include infrastructure and configuration outputs in security evals. When only code is scanned, infrastructure vulnerabilities slip through.

Pitfall: ignoring dependency changes. Solution: enforce dependency approvals and vulnerability scanning. Dependencies can introduce vulnerabilities, so they need security review.

Pitfall: no regression packs. Solution: build regression packs from real incidents. When regression packs reflect real incidents, they prevent repeat mistakes.

Pitfall: too many false positives. Solution: tune patterns and use allowlists. When false positives are high, developers ignore evals. When false positives are low, developers trust evals.

Key concepts to remember
AI amplifies security regressions—you need deterministic security checks
Layer the evals—static analysis, dependency scans, secrets scans, and policy checks
Regression packs should be security-aware—encode real incident patterns
Evaluate non-code outputs—configs and scripts can be just as risky
Manage false positives—keep signal high so developers trust the system
Measure effectiveness—track failures, fix times, and bypassed incidents
Maintain ownership—assign owners to keep evals current and effective