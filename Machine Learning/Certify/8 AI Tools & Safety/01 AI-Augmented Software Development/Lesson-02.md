## When Every Developer Prompts Differently
Imagine you join a new team that uses AI coding assistants. On your first day, you ask the assistant to add a new API endpoint. It generates clean code with tests and proper error handling. Perfect. A week later, a teammate asks for the same thing, but the assistant generates code without tests, adds an unnecessary dependency, and refactors unrelated error handling. Both requests were similar, but the outputs are completely different.

This inconsistency is the problem with ad-hoc prompting. In small experiments, you can paste a prompt into a chat window and get good results. In a real codebase with multiple developers, that approach breaks down quickly. Different developers use different tools, different models, and different habits. People join and leave. Requirements evolve. Without a shared instruction layer, AI-assisted development becomes inconsistent and difficult to review.

In this lesson, you will learn how to build a stable instruction hierarchy that keeps AI outputs consistent across developers, tasks, and time. You will understand why repo rules matter more than individual prompt craft, and how to encode team conventions so that AI assistants do not repeatedly rediscover your standards.

By the end, you will have a framework for creating repo rules that scale across teams and evolve with your codebase without breaking developer flow.

Why "Prompting" Is Not Enough in a Real Codebase
The inconsistency shows up in predictable ways. One developer asks an assistant to "add a new endpoint," and the assistant writes a thin controller and no tests. Another developer asks the same thing, but the assistant adds a dependency, refactors unrelated code, and rewrites error handling. Both diffs may pass unit tests, but reviewers now have to learn a new set of conventions for every PR. Over time, the codebase becomes a patchwork of styles and implicit assumptions.

This happens because AI assistants do not have memory of your team's conventions unless you explicitly encode them. Each prompt is a fresh start. Without shared rules, every developer must rediscover what "good code" means for your team, and they often get it wrong.

This is why modern teams treat AI instructions like any other engineering interface: versioned, documented, and testable. Instead of relying on individual prompt craft, you define stable repo-level rules that shape behavior across tasks.

The goal is not to micromanage the assistant. The goal is to encode "how we build software here" so the assistant does not repeatedly rediscover your conventions, and so the team can change those conventions intentionally.

An Instruction Hierarchy You Can Reason About
In practice, AI tooling usually has multiple instruction channels. The names differ by product, but the structure is similar:

Global rules: safety and non-negotiables that apply everywhere. These are universal constraints like "never log secrets" or "always validate input."

Repo rules: conventions specific to this codebase. These encode team standards like "use dependency injection" or "all endpoints must have tests."

Task instructions: what to do for a particular change request. These are specific to the current task like "add error handling to this endpoint."

Local context: files, diffs, logs, and other inputs. These provide situational information.

You get reliability when this hierarchy is explicit. A reviewer should be able to answer: "Which rules constrained this change?" and "Where do I update those rules?" Without explicit hierarchy, rules conflict and produce inconsistent output.

If rules conflict, the assistant will usually pick whatever is most recent or most specific. That makes conflicts dangerous because they produce inconsistent output across tools. The fix is to document precedence: for example, "repo rules override task instructions when they disagree about safety," and "task instructions override examples in documentation."

Consider what happens without explicit hierarchy. A developer writes a task instruction that says "add logging for debugging." But repo rules say "never log user data." Without clear precedence, the assistant might follow the task instruction and violate the repo rule, or it might follow the repo rule and ignore the task instruction. Neither outcome is predictable.

What Belongs in Repo Rules
Repo rules should be stable, high-signal constraints that prevent recurring failure modes. They encode the invariants that keep your codebase safe and maintainable.

Examples of good repo rules:

Style and structure: formatting, naming conventions, layering rules. These ensure consistency across the codebase.

Testing requirements: when to add tests and what patterns to use. These ensure quality and prevent regressions.

Error handling conventions: retries, timeouts, logging, and metrics. These ensure reliability and observability.

Security constraints: never log secrets, never bypass authorization helpers. These prevent security vulnerabilities.

Performance constraints: avoid N+1 queries, avoid loading entire datasets. These prevent performance issues.

Allowed tools and safe defaults: which scripts are safe to run, which are not. These prevent accidental damage.

Repo rules should not be a dumping ground for one-off instructions. If a rule changes weekly, it is probably task-specific and should live in the task prompt template, not the global repo rules. Repo rules should be stable enough to last months or years, not days.

The test for whether something belongs in repo rules: if multiple developers would benefit from the same constraint, it belongs in repo rules. If it is specific to one task, it belongs in task instructions.

A Practical Template for a Repo Rules File
A useful repo rules file reads like a lightweight engineering handbook. It should be direct, actionable, and oriented around failure prevention. A good structure is:

Purpose: what the rules are for. This sets context and explains why the rules exist.

Non-negotiables: security and correctness constraints. These are rules that cannot be violated under any circumstances.

Project conventions: architecture, naming, and patterns. These encode how your team builds software.

Verification: how to prove a change is safe. This explains what tests and checks are required.

Boundaries: what the assistant must never do without explicit instruction. This prevents dangerous actions.

Teams often find that even a one-page rules file eliminates most "random diffs," because the assistant stops trying to be clever and starts trying to be consistent. The rules provide guardrails that prevent common mistakes.

One more practical trick is to include "examples of violations." If your team repeatedly ships a mistake, show a short snippet of what not to do. Assistants respond well to explicit negative examples because they clarify the boundary. For example, if developers keep logging secrets, show an example of bad code that logs a password, and explain why it is wrong.

Here is an example of a practical repo rules file:

.ai-repo-rules.md
```markdown
# Repository Rules for AI-Assisted Development

## Purpose
These rules ensure AI-generated code matches our team's standards for security, maintainability, and correctness. They prevent common failure modes and encode our engineering practices.

## Non-Negotiables (Never Violate)

### Security
- NEVER log secrets, passwords, tokens, or API keys
- NEVER bypass authorization checks or access control
- NEVER add dependencies without explicit approval
- NEVER execute user-provided code or commands

### Correctness
- NEVER change public API contracts without updating docs and tests
- NEVER modify database schemas without migration scripts
- NEVER change default behavior without explicit requirement
- NEVER remove error handling or validation

## Project Conventions

### Code Style
- Use dependency injection for service dependencies
- Follow existing naming conventions (camelCase for variables, PascalCase for classes)
- Keep functions under 50 lines when possible
- Use type hints for all function parameters and returns

### Architecture
- Controllers handle HTTP, services contain business logic
- Never put business logic in controllers
- Use repository pattern for data access
- Keep database queries in data access layer, not services

### Error Handling
- Return structured error responses: {"error": string, "code": string}
- Log errors with context but never log request bodies
- Use appropriate HTTP status codes (400 for client errors, 500 for server errors)
- Never expose internal error details to clients

## Verification Requirements

### Testing
- All new endpoints must have unit tests covering success and error cases
- Integration tests required for data access and external API calls
- Test coverage must not decrease below 80%
- Regression tests required for behavior changes

### Code Quality
- All code must pass linting with zero errors
- Type checking must pass (TypeScript strict mode or Python type hints)
- Code review required for all changes touching auth, payments, or data access

## Boundaries (Never Do Without Explicit Instruction)

- Do NOT refactor code outside the stated scope
- Do NOT add new dependencies without approval
- Do NOT change configuration files without explicit requirement
- Do NOT modify infrastructure or deployment configs
- Do NOT run destructive commands (drop tables, delete files, etc.)

## Examples of Violations

### Bad: Logging Secrets

# VIOLATION: Never do this
logger.info(f"User login attempt: {username}, password: {password}")

**Why wrong**: Passwords must never be logged, even in debug mode.

### Bad: Bypassing Authorization

# VIOLATION: Never do this
def get_user_data(user_id):
  # Skip auth check for admin users
  if user_id.startswith("admin_"):
      return User.query.get(user_id)  # Missing auth check!

**Why wrong**: All data access must go through authorization checks, no exceptions.

### Bad: Silent Behavior Change

# VIOLATION: Never do this
def fetch_users(include_inactive=False):
  # Changed default timeout without mentioning it
  timeout = 5  # Was 30 seconds, now 5 seconds
  return api.get_users(timeout=timeout)

**Why wrong**: Default behavior changes break existing clients. Always preserve defaults unless explicitly required to change.
````


Before diving into enforcement, consider how rules become effective only when they are paired with verification and workflow support.

Guardrails That Prevent the Worst Failures
The highest-value rules are the ones that prevent irreversible damage. In AI-assisted development, the most expensive failures are usually:

Leaking secrets or sensitive data: a single API key in a PR can lead to unauthorized access
Breaking authorization and access control: bypassing auth checks can expose sensitive data
Introducing supply chain risk: unsafe dependencies or unvetted scripts can compromise security
Broad refactors that change behavior: silent behavior changes can break production
You can mitigate these failures by encoding guardrails that are easy to follow:

Do not touch authentication and authorization without an explicit task requirement. Auth changes have high impact, so they need explicit approval.

Do not add dependencies without explicit approval and justification. Dependencies introduce security and maintenance risk.

Do not run destructive commands or modify infrastructure state. These actions can cause outages.

Do not change public APIs without updating docs and tests. API changes affect external users.

Do not log raw user inputs or identifiers. This prevents data leakage and privacy violations.

The rule itself is not enough. You also need workflow support. For example, if "no dependency changes without approval" is a rule, your CI should clearly flag dependency diffs, and your PR template should have a checkbox for approval. Without workflow support, rules become suggestions that developers ignore.

Here is an example of how to encode these guardrails in a repo rules file:

guardrails.md
```markdown
## Critical Guardrails

### Authentication and Authorization
**Rule**: Never modify authentication or authorization logic without explicit task requirement and security review.

**Enforcement**:
- CI fails if auth files changed without [SECURITY-REVIEW] label
- PR template requires security team approval checkbox

**Example Violation**:

# BAD: Removing auth check "for convenience"
def get_user_data(user_id):
  return User.query.get(user_id)  # Missing auth check!

### Dependencies
**Rule**: Never add dependencies without explicit approval and justification.

**Enforcement**:
- CI fails if package.json/requirements.txt changed without [DEPENDENCY-APPROVED] label
- PR must include justification: why needed, security review, maintenance plan

**Example Violation**:

// BAD: Adding library for one small utility
{
"dependencies": {
  "lodash": "^4.17.21"  // Only used once, should use native JS
}
}


### Destructive Commands
**Rule**: Never run destructive commands or modify infrastructure without explicit instruction.

**Enforcement**:
- CI blocks PRs that modify infrastructure configs
- Requires infrastructure team approval

**Example Violation**:

# BAD: Dropping table "to clean up"
DROP TABLE users;  # Destructive, requires migration script


### Public API Changes
**Rule**: Never change public APIs without updating docs and tests.

**Enforcement**:
- CI fails if API routes changed without doc updates
- Requires API versioning for breaking changes

**Example Violation**:

# BAD: Changing response format without versioning
def get_user(user_id):
  return {"id": user_id}  # Was {"user_id": user_id} - breaks clients!


### Data Logging
**Rule**: Never log raw user inputs, identifiers, or sensitive data.

**Enforcement**:
- Linter flags common logging patterns that leak data
- Security scan detects high-entropy strings (likely secrets)

**Example Violation**:

# BAD: Logging sensitive user data
logger.info(f"User request: {request.body}")  # May contain passwords!
logger.debug(f"Processing user: {user.email}, SSN: {user.ssn}")  # PII leak!
```

A Small Enforcement Example: Dependency and Network Policies
Many AI-generated changes fail in two ways: they add a library "because it is easier," or they introduce network calls in places that should be deterministic (like tests). Both are easy to prevent with enforceable rules:

Dependency policy: fail CI if package lockfiles changed without an explicit label or approval. This prevents accidental dependency additions.

Test policy: fail CI if tests attempt real network access. This keeps tests deterministic and fast.

These policies do not require an advanced platform. They require a clear rule, a simple check, and a workflow to override intentionally when the team agrees. The check can be as simple as a grep for network calls in test files, or a diff check for lockfile changes.

The key is that the check is automatic and blocks merges. If developers must manually remember to check, they will forget. If the check is automatic, it becomes part of the workflow.

Here is an example of CI checks that enforce these policies:

.github/workflows/ai-safety-checks.yml
```yaml
name: AI Safety Checks

on:
pull_request:
  paths:
    - 'package.json'
    - 'package-lock.json'
    - 'requirements.txt'
    - '**/test_*.py'
    - '**/*.test.js'

jobs:
dependency-check:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3

    - name: Check for dependency changes
      run: |
        if git diff --name-only origin/main...HEAD | grep -E "(package-lock.json|requirements.txt)"; then
          if ! grep -q "\[DEPENDENCY-APPROVED\]" <<< "\${{ github.event.pull_request.body }}"; then
            echo "❌ Dependency changes require [DEPENDENCY-APPROVED] label"
            echo "Please add justification in PR description"
            exit 1
          fi
        fi

test-network-check:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3

    - name: Check for network calls in tests
      run: |
        # Check Python tests
        if grep -r "requests.get\|requests.post\|urllib\|http.client" tests/ --include="test_*.py"; then
          echo "❌ Tests should not make real network calls"
          echo "Use mocking or fixtures instead"
          exit 1
        fi

        # Check JavaScript tests
        if grep -r "fetch\|axios\|http.request" tests/ --include="*.test.js"; then
          echo "❌ Tests should not make real network calls"
          echo "Use mocking or fixtures instead"
          exit 1
        fi
```

Making Rules Enforceable, Not Aspirational
Rules that cannot be verified will be ignored. The best instruction layers are paired with enforcement:

Linters and formatters enforce consistency. They catch style violations automatically.

Tests enforce behavior. They catch logic errors and regressions.

Policy checks enforce constraints like "no new dependencies" or "no network calls in tests." They catch violations of repo rules.

Review checklists enforce human verification for risky changes. They ensure humans review high-risk code.

This is the same pattern as secure software development. Policy lives in text, but safety lives in enforcement. Without enforcement, rules are just suggestions.

Consider what happens without enforcement. A repo rule says "all endpoints must have tests." But there is no check that enforces this. Developers forget, tests are not written, and the rule becomes meaningless. With enforcement, CI fails if tests are missing, and developers must write tests to merge.

Here is an example of how to enforce "all endpoints must have tests" rule:

.github/workflows/test-enforcement.yml
```yaml
name: Test Enforcement

on:
pull_request:
  paths:
    - 'src/api/**/*.py'
    - 'src/routes/**/*.js'

jobs:
check-test-coverage:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3

    - name: Check for new endpoints without tests
      run: |
        # Find new endpoint files
        new_endpoints=\$(git diff --name-only origin/main...HEAD | grep -E "(controller|route)" || true)

        if [ -n "\$new_endpoints" ]; then
          for endpoint_file in \$new_endpoints; do
            # Extract endpoint name
            endpoint_name=$(basename "\$endpoint_file" | sed 's/\.[^.]*$//')

            # Check if corresponding test file exists
            test_file="tests/\${endpoint_file#src/}"
            test_file="\${test_file%.py}_test.py"

            if [ ! -f "\$test_file" ]; then
              echo "❌ New endpoint \$endpoint_file has no test file"
              echo "Expected test file: \$test_file"
              exit 1
            fi
          done
        fi

    - name: Run tests
      run: |
        pytest tests/ --cov=src --cov-report=term-missing

    - name: Check coverage threshold
      run: |
        coverage=\$(pytest tests/ --cov=src --cov-report=term | grep TOTAL | awk '{print $NF}' | sed 's/%//')
        if (( \$(echo "\$coverage < 80" | bc -l) )); then
          echo "❌ Test coverage is \$coverage%, minimum is 80%"
          exit 1
        fi
```

Measuring Whether Rules Actually Work
You can and should measure whether repo rules are reducing incidents and review time. Practical signals include:

Reduction in regressions tied to repeated failure modes: if rules prevent common mistakes, incidents should decrease.

Fewer review comments asking for basic conventions: if rules encode conventions, reviewers should not need to ask for them.

Lower variance in diff sizes for similar tasks: if rules constrain scope, diffs should be more consistent.

Fewer emergency rollbacks related to AI-assisted changes: if rules prevent dangerous changes, rollbacks should decrease.

If rules are not improving these signals, they might be too vague or too hard to follow. That is not a reason to abandon rules. It is a reason to make them more explicit and easier to enforce.

For example, if a rule says "write good tests" but test quality does not improve, the rule is too vague. A better rule might be "all new endpoints must have tests that cover success and error cases, and tests must run in CI." This is specific and enforceable.

Keeping Rules Current Without Breaking Developer Flow
Rules must evolve, but you want changes to be intentional:

Version rule updates through pull requests: this makes changes visible and reviewable.

Record a short rationale for changes: explain why the rule changed, like "we saw repeated regressions in X."

Prefer small rule updates instead of rewrites: small changes are easier to understand and adopt.

Add examples of good behavior when possible: examples make rules concrete and actionable.

When rules change silently, developers lose trust. When rules change through a visible process, the team builds shared understanding and the assistant's output becomes more consistent over time.

Consider what happens when rules change without visibility. A developer follows an old rule, but the rule changed last week. The developer's code violates the new rule, and they do not understand why. This creates frustration and reduces trust in the rules.


Summary: Rules as an Engineering Interface
Repo rules are the missing link between "prompting" and "reliable team workflows." They create a stable instruction hierarchy that keeps AI outputs consistent across developers and time. The highest-value rules encode invariants, safety boundaries, and verification expectations, and they are paired with enforcement in CI and review processes.

Rules work best when they are stable, enforceable, and aligned with team values. They should prevent failures, not micromanage implementation. When rules are clear and enforced, AI assistants produce consistent output that matches team standards.

Rolling Out Rules Without Slowing the Team
When you introduce repo rules, keep the rollout incremental:

Start with three to five non-negotiable safety rules: these are the highest-impact rules that prevent the worst failures.

Add enforcement for only one or two of them at first: this reduces friction and lets the team adapt gradually.

Communicate the reason for each rule with a real incident or near miss: this builds understanding and buy-in.

This reduces friction and makes it clear that rules exist to prevent failures, not to police behavior. Over time, expand the rule set based on actual pain points.

If you try to roll out too many rules at once, developers will resist. If you start small and expand gradually, adoption is smoother.

What to Do When Rules Are Ignored
If developers bypass rules, it is usually a signal that the rule is too strict, too vague, or too hard to comply with. Fix the rule or the tooling, not the people. A good rule should be easier to follow than to bypass.

For example, if developers keep adding dependencies without approval, build a simple approval path in the PR template or automate dependency diff labeling. If developers keep skipping tests, make the default branch policy require a minimum test set.

The goal is to make following rules easier than bypassing them. If bypassing is easier, developers will bypass. If following is easier, developers will follow.

Common Pitfalls and Solutions
Pitfall: Rules that are too generic. "Write clean code" does not change outcomes. Replace generic rules with concrete invariants, like "all new endpoints must include request validation and tests." Generic rules are unenforceable and ignored.

Pitfall: Rules that are too strict. If rules prevent legitimate work, developers will bypass them. Use "deny by default" only for high-risk actions, and provide a clear override path when the team approves. Rules should prevent mistakes, not block progress.

Pitfall: Rules that conflict. If repo rules say "prefer small diffs" but task templates encourage large refactors, the assistant will oscillate. Keep the hierarchy consistent and document precedence. Conflicting rules produce unpredictable output.

Pitfall: Rules without enforcement. If rules are not enforced, they become suggestions that developers ignore. Pair rules with automatic checks or review processes. Enforcement makes rules real.

Pitfall: Rules that never change. Rules should evolve with the codebase. If rules never change, they might become outdated or irrelevant. Review rules periodically and update them based on team needs.

Key concepts to remember
Make the hierarchy explicit—global rules, repo rules, and task instructions should not conflict
Encode invariants—focus on safety boundaries and recurring failure modes
Pair rules with enforcement—linters, tests, and policy checks turn rules into reality
Evolve rules intentionally—change rules through PRs with clear rationale
Measure effectiveness—track signals like incident reduction and review time
Start small—roll out a few high-impact rules first, then expand gradually