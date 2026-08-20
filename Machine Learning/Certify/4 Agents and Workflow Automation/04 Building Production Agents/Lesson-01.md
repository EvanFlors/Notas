## How Agents Fail Differently

Your code review agent passes all tests. It handles edge cases, manages timeouts, and gracefully recovers from API failures. You deploy it to production. Within a week, it has approved a PR containing an obvious SQL injection vulnerability, burned through $200 in API costs on a single review, and posted the same comment 47 times.

Traditional software fails in predictable ways: crashes, timeouts, and error responses. Agents fail differently. They make bad decisions confidently. They get stuck in reasoning loops. They consume unbounded resources pursuing unhelpful paths.

In this lesson, you will learn how agents fail, why traditional fault tolerance is not enough, and how to build resilience patterns that handle the unique challenges of autonomous decision-making systems.

By the end, you will understand agent-specific failure modes and have practical patterns to prevent them.

Reasoning Failures
The most insidious agent failures are reasoning errors. The agent runs successfully, returns a result, and posts a review—but the review is wrong. No exception is thrown. No error is logged. The agent simply made a bad decision.

Consider this scenario: your code review agent analyzes a pull request modifying the authentication module. The code contains this line:

```python
query = f"SELECT * FROM users WHERE username = '\{username\}'"
```

This is textbook SQL injection. But the agent says: "Authentication changes look secure. The query uses parameterized input via the username variable." The agent saw the code, processed it, and confidently reached the wrong conclusion.

Reasoning failures happen because language models pattern match against training data. When patterns are ambiguous, the model produces plausible-sounding but incorrect analysis.

Common reasoning failures in code review agents:

False negatives: Missing actual vulnerabilities because the pattern looks similar to safe code
False positives: Flagging safe code as vulnerable, eroding developer trust
Scope confusion: Analyzing the wrong files or missing context from related modules
Overconfidence: Stating conclusions with certainty when evidence is ambiguous
You cannot prevent reasoning failures entirely—they are inherent to LLM-based systems. But you can detect and mitigate them through structured validation and human escalation for critical decisions.

Infinite Loops and Stuck Agents
Traditional infinite loops crash your process or exhaust memory. Agent loops are worse: they exhaust your budget while appearing to work normally.

An agent loop happens when the agent repeatedly takes actions without making progress. The agent calls ```get_file_content("auth.py")```, observes the result, decides it needs more context, and calls ```get_file_content("auth.py")``` again. And again. Fifty times.

The agent keeps requesting the same information because its reasoning does not recognize it already has what it needs. This happens when context windows overflow, when prompts lack clear completion criteria, or when the agent cannot determine that its approach is failing.

Loop detection strategies:

Track action history and flag repeated identical calls
Set maximum iterations per review (not just timeouts)
Require progress indicators: if no new findings in N iterations, intervene
Include explicit "I am stuck" reasoning paths in prompts
Token Explosion
A typical code review costs $0.05 in API tokens. But a single problematic review can cost $50 or more. Token explosion happens when agents load excessive context, iterate too many times, or generate verbose outputs without constraints.

The pattern usually looks like this: the agent encounters a large PR with 200 changed files. It decides to analyze each file thoroughly, loading full file contents into context. By iteration 15, the agent is sending 100,000 tokens per request.

Token explosion is dangerous because it scales invisibly. Your average cost metrics look fine until one catastrophic review skews your monthly bill.

What drives token explosion:

Loading full file contents instead of diffs
Accumulating conversation history without summarization
Verbose tool outputs that the agent includes verbatim in reasoning
Retry loops that repeat expensive context
The solution is token budgets: explicit limits on how many tokens a single review can consume. When the budget is exhausted, the agent must stop or produce a partial result.

Goal Drift
You ask the agent to review a PR for security issues. It starts checking authentication code, notices some style inconsistencies, begins suggesting refactoring improvements, and eventually produces a review focused entirely on code style with no security analysis at all.

Goal drift happens when the agent loses track of its original objective during multi-step reasoning. Each individual step seems reasonable, but the cumulative effect is wandering away from the task.

Prevention strategies:

Include the goal in every prompt, not just the initial request
Structure reviews as phases: "Phase 1: Security, Phase 2: Style" with explicit transitions
Validate final output against original goal before posting

Before diving into traditional fault tolerance patterns, consider how agent failures differ from standard software failures.

Why Traditional Fault Tolerance Is Not Enough
You have built resilient systems before. You use retries with exponential backoff, circuit breakers for failing services, and graceful degradation when dependencies are unavailable. These patterns are necessary for agent systems—but they are not sufficient.

Traditional fault tolerance assumes failures are observable: an API returns an error, a timeout occurs. Agent failures are often unobservable. The agent completes successfully, returns a result, and the result is wrong. No error to catch.

Consider circuit breakers. A traditional circuit breaker opens when a service returns errors repeatedly. But what if the agent misinterprets responses? The circuit stays closed while the agent produces bad reviews. You need quality-based circuit breakers that track correctness, not just availability.

Retries illustrate another gap. When an API call fails, retrying often succeeds. When an agent makes a reasoning error, retrying produces the same error—or a different one. LLM outputs are non-deterministic, so retries might help, but they might also introduce new problems.

Timeouts prevent operations from hanging forever. But agent operations can complete quickly while still being catastrophically expensive. A review that finishes in 30 seconds might have consumed $50 in tokens.

Circuit Breakers for Agent Systems
Standard circuit breakers protect against service failures. Agent circuit breakers must also protect against quality degradation.

```python
class AgentCircuitBreaker:
  def __init__(self, failure_threshold=3, quality_threshold=0.8):
      self.consecutive_failures = 0
      self.recent_quality_scores = []
      self.state = "closed"

  def record_result(self, success: bool, quality_score: float = None):
      if not success:
          self.consecutive_failures += 1
          if self.consecutive_failures >= self.failure_threshold:
              self.state = "open"
      else:
          self.consecutive_failures = 0

      if quality_score is not None:
          self.recent_quality_scores.append(quality_score)
          avg = sum(self.recent_quality_scores[-10:]) / min(10, len(self.recent_quality_scores))
          if avg < self.quality_threshold:
              self.state = "degraded"
```

The key addition is the degraded state. The agent is working—it completes reviews without errors—but the reviews are not good enough. This state triggers alerts and potentially routes reviews to human reviewers.

Graceful Degradation with Uncertainty
When a traditional service degrades, you return cached data or a simplified response. When an agent degrades, you must communicate uncertainty to users.

If the security scanner is unavailable, your agent should not silently skip security analysis and approve the PR. It should explicitly state what it could not check:

```python
async def review_with_degradation(self, pr_number: int) -> dict:
  result = {"completed_checks": [], "skipped_checks": [], "warnings": []}

  if self.security_circuit.is_available():
      try:
          result["security"] = await self.scan_security(pr_number)
          result["completed_checks"].append("security_scan")
      except Exception as e:
          result["skipped_checks"].append("security_scan")
          result["warnings"].append(f"Security scan unavailable: \{e\}")

  if result["skipped_checks"]:
      result["recommendation"] = "MANUAL_REVIEW_REQUIRED"

  return result
```

Graceful degradation for agents means degrading to human judgment, not to silent assumptions. When the agent cannot do its job fully, it should say so clearly and escalate appropriately.

Now that you understand agent-specific failures like infinite loops and token explosion, consider how to prevent runaway resource consumption.

Building Resilient Agent Workflows
Resilience is not a single pattern but a combination of strategies working together. A production agent workflow incorporates loop detection, budget enforcement, progress tracking, and quality monitoring.

```python
class ResilientReviewAgent:
  async def review_pr(self, pr_number: int) -> ReviewResult:
      action_history = []
      goal = f"Review PR #\{pr_number\} for security vulnerabilities"

      while len(action_history) < self.config.max_iterations:
          if not self.token_budget.can_continue():
              return self.create_partial_result("Token budget exhausted")

          if self.detect_loop(action_history):
              return self.create_partial_result("Agent stuck in loop")

          action = await self.get_next_action(goal=goal, history=action_history)
          action_history.append(action)

          if action.type == "complete":
              return self.create_final_result()

      return self.create_partial_result("Max iterations reached")
```

This loop incorporates multiple resilience strategies:

Token budgets prevent runaway costs. Before each iteration, the agent checks if it can afford to continue.

Loop detection catches stuck agents. The agent tracks its action history and detects when it repeats the same actions.

Goal anchoring prevents drift. The original goal is included in every prompt.

Progress tracking through findings ensures the agent is accomplishing something.

Handling Agent Restarts
Long-running reviews can be interrupted by deployments, crashes, or infrastructure issues. Without state persistence, an interrupted review must start over.

```python
class CheckpointedAgent:
  async def review_with_checkpoints(self, pr_number: int, review_id: str):
      checkpoint = await self.load_checkpoint(review_id)

      if checkpoint:
          findings = checkpoint.findings
          phase = checkpoint.phase
      else:
          findings = []
          phase = "security"

      if phase == "security":
          findings.extend(await self.run_security_phase(pr_number))
          await self.save_checkpoint(review_id, "coverage", findings)
          phase = "coverage"

      if phase == "coverage":
          findings.extend(await self.run_coverage_phase(pr_number))
          await self.save_checkpoint(review_id, "complete", findings)

      return self.compile_review(findings)
````

Checkpoints should capture meaningful state: completed phases, accumulated findings, and context needed to resume. Do not checkpoint raw LLM conversation history—it is too large and not portable across model versions.

Summary
Agents fail differently from traditional software. Reasoning errors produce incorrect results without raising exceptions. Infinite loops consume resources while appearing to work. Token explosion causes unbounded costs. Goal drift leads agents away from their objectives.

Traditional fault tolerance patterns—circuit breakers, retries, timeouts—are necessary but not sufficient. Agent systems need quality-aware circuit breakers, graceful degradation that communicates uncertainty, and resource limits that prevent token explosion.

Key Takeaways:

Reasoning failures are silent: the agent succeeds but produces wrong results—validate outputs
Infinite loops waste resources without crashing—track action history and detect repetition
Token explosion can cost 1000x normal—enforce per-review token budgets
Goal drift leads agents astray—include the goal in every prompt, not just the first
Traditional circuit breakers miss quality problems—track correctness, not just availability
Graceful degradation means escalating to humans, not silently skipping checks
Checkpoint at phase boundaries so interrupted reviews can resume
Now that you understand how agents fail and how to build resilience, you are ready to learn how to observe and debug agent behavior in production.
