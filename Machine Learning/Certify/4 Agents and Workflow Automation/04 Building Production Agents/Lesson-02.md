## Understanding Agent Decisions

A developer reports that your code review agent approved a pull request containing a SQL injection vulnerability. You want to investigate. You open your logs and find: "Review completed for PR #1247. Duration: 12.3s. Status: success."

That tells you nothing. You know the agent ran successfully—but you need to understand why it approved the PR. What did it see? What did it reason? Why did it miss the vulnerability?

This is the observability challenge for agents. Traditional monitoring tells you whether systems are running. Agent observability must tell you why agents made specific decisions.

In this lesson, you will learn how to instrument agents for meaningful observability: capturing decisions, tracing reasoning, and building the visibility you need to understand and improve agent behavior.

By the end, you will have patterns for observing not just what agents do, but why they do it.

Three Levels of Agent Observability
Observing agents requires visibility at three distinct levels. Each level answers different questions.

Infrastructure observability answers: "Is the agent running?" This is traditional monitoring—uptime, error rates, latency, resource utilization. You need it, but it is the baseline. An agent can have perfect infrastructure metrics while producing terrible reviews.

Behavior observability answers: "What did the agent do?" This tracks actions: which tools were called, what parameters were used, what results were returned.

Reasoning observability answers: "Why did the agent decide that?" This captures the agent's thought process: what it considered, what it concluded, and how it connected observations to decisions.

Consider investigating the SQL injection incident. Infrastructure observability shows the review completed in 12 seconds with no errors. Behavior observability shows the agent called ```analyze_security(pr_number=1247)``` and received a result. Reasoning observability shows the agent's thought: "The query uses a variable named ```safe_query```, suggesting proper parameterization."

That reasoning trace reveals the failure: the agent was fooled by the variable name. Without reasoning observability, you would never discover this.

Debugging Agent Decisions
Let us walk through debugging a real incident. A user reports that PR #1247 was approved despite containing a SQL injection vulnerability.

Step 1: Confirm the incident exists

Check infrastructure metrics: was the review completed successfully?

Step 2: Examine behavior trace

What tools did the agent call?

text
[12:34:01] tool_call: ```get_pr_details(pr_number=1247)```
         result: {files: ["auth.py"], additions: 47}

[12:34:03] tool_call: ```get_file_diff(pr_number=1247, file="auth.py")```
         result: {diff: "...safe_query = f\"SELECT * FROM users...\""}

[12:34:05] tool_call: ```analyze_security(pr_number=1247)```
         result: {vulnerabilities: []}
The security scanner returned no vulnerabilities. Two possibilities: the scanner failed to detect the issue, or the agent misinterpreted results.

Step 3: Examine reasoning trace

text
[12:34:05] reasoning: "The diff shows a query being constructed.
         The variable is named 'safe_query' which suggests the developer
         intended this to be safe. The security scanner found no issues."

[12:34:07] reasoning: "No vulnerabilities detected. Recommending approval."
The reasoning trace reveals two issues: the agent relied on variable naming as evidence of security, and the scanner has a detection gap.

Understanding the three levels of observability helps you investigate agent failures systematically.

Logging Agent Decisions
Effective agent logging captures decisions with their context. Every log entry should answer: what happened, why did it happen, and what should I know to understand this later?

```python
class AgentLogger:
  def log_decision(self, decision_type: str, decision: str,
                   reasoning: str, evidence: list, confidence: float = None):
      entry = {
          "timestamp": datetime.utcnow().isoformat(),
          "type": "decision",
          "decision_type": decision_type,
          "decision": decision,
          "reasoning": reasoning,
          "evidence": evidence,
          "confidence": confidence
      }
      self._emit(entry)

  def log_reasoning(self, thought: str, observation: str = None):
      entry = {
          "timestamp": datetime.utcnow().isoformat(),
          "type": "reasoning",
          "thought": thought,
          "observation": observation[:500] if observation else None
      }
      self._emit(entry)
```

Using the logger in agent code:

```python
async def review_pr(self, pr_number: int) -> dict:
  self.logger.set_context(review_id=review_id, pr_number=pr_number)

  self.logger.log_reasoning(thought=f"Starting security review for PR #{pr_number}")

  pr_details = await self.get_pr_details(pr_number)
  self.logger.log_tool_call(
      tool="get_pr_details",
      arguments={"pr_number": pr_number},
      result_summary=f"{len(pr_details['files'])} files changed"
  )

  # Log the final decision with reasoning
  self.logger.log_decision(
      decision_type="review_verdict",
      decision="approve",
      reasoning="No security issues detected in changed files",
      evidence=[],
      confidence=0.70
  )
```

Notice how each decision includes the reasoning that led to it. When you investigate later, you see not just "approved" but "approved because no security issues were detected, with 70% confidence."

Quality Metrics for Agents
Infrastructure metrics tell you if the system is running. Quality metrics tell you if the system is working well. For agents, quality metrics must capture decision correctness.

```python
from prometheus_client import Counter, Histogram

# Decision accuracy (requires human feedback or ground truth)
review_decisions = Counter(
  'agent_review_decisions_total',
  'Total review decisions by verdict and correctness',
  ['verdict', 'was_correct']
)

# False positive/negative rates
false_positives = Counter(
  'agent_false_positives_total',
  'Reviews where agent flagged issues that were not real'
)

false_negatives = Counter(
  'agent_false_negatives_total',
  'Reviews where agent missed real issues'
)
```

Quality metrics require ground truth—you need to know whether the agent's decisions were correct. Sources include:

Human review of agent decisions (sampling)
Known test cases with expected outcomes
Downstream signals (did the merged PR cause bugs?)
User feedback on review quality

Now that you understand how to log agent decisions with context, apply that knowledge to debugging a real incident.

Alerting on Agent Behavior
Agent alerts should catch quality degradation, not just outages. An agent that is running but approving bad code is worse than an agent that is down.

```yaml
groups:
- name: agent-quality
  rules:
    - alert: AgentOverlyPermissive
      expr: |
        sum(rate(agent_review_decisions_total{verdict="approve"}[1h])) /
        sum(rate(agent_review_decisions_total[1h])) > 0.95
      for: 2h
      annotations:
        summary: "Agent approving 95%+ of reviews"

    - alert: AgentQualityDegradation
      expr: |
        sum(rate(agent_review_decisions_total{was_correct="false"}[24h])) /
        sum(rate(agent_review_decisions_total[24h])) > 0.15
      annotations:
        summary: "Agent decision accuracy below 85%"
```

Practical Debugging Workflows
When an agent issue is reported, follow a systematic debugging workflow:

Workflow 1: Investigating a bad decision

Get the review ID from the report
Pull the complete reasoning trace
Identify the decision point where the error occurred
Examine the evidence the agent had at that point
Determine: was the error in reasoning, tool results, or missing information?
Workflow 2: Finding patterns in failures

When multiple issues are reported, look for patterns:

```python
async def analyze_failure_patterns(time_range: tuple) -> dict:
  failures = await db.query("""
      SELECT * FROM reviews
      WHERE was_correct = false
      AND created_at BETWEEN ? AND ?
  """, time_range)

  patterns = {"by_file_type": Counter(), "common_phrases": Counter()}

  for failure in failures:
      trace = await db.get_trace(failure["review_id"])
      for entry in trace:
          phrases = extract_key_phrases(entry["thought"])
          for phrase in phrases:
              patterns["common_phrases"][phrase] += 1

  return patterns
```

If you discover that failures cluster around "variable name suggests safe" reasoning, you know to update the prompt to discourage this heuristic.

Summary
Agent observability requires visibility into reasoning, not just infrastructure. Three levels of observability—infrastructure, behavior, and reasoning—answer different questions and all are necessary for production debugging.

Decision logging captures not just what happened but why. Every logged decision should include the reasoning and evidence that led to it. Reasoning traces from the agent loop provide the complete thought process for later analysis.

Quality metrics track decision correctness over time. Quality-based alerts catch degradation that infrastructure alerts miss.

Key Takeaways:

Infrastructure observability is not enough—you need to see agent reasoning
Log decisions with their reasoning and evidence, not just outcomes
Capture complete reasoning traces for post-hoc analysis
Quality metrics track correctness, not just availability
Alert on quality degradation: approval rates, accuracy, and behavioral changes
Pattern analysis across failures reveals systemic prompt or tool issues
Build investigation tools that pull complete context for any review
Now that you can observe and debug agent behavior, you are ready to learn how to control agent costs in production.