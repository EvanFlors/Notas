## Putting It All Together
You have learned the HITL patterns individually: autonomy calibration, approval workflows, feedback collection, confidence estimation, and escalation. But real systems need all these patterns working together, each informing the others. Confidence estimates feed into autonomy decisions; feedback improves confidence calibration; approval workflows capture corrections that become training data.

This lesson integrates everything into a complete code review agent. You will see how the patterns interconnect and support each other in a production system.

By the end, you will have a blueprint for building agents that combine automation efficiency with human judgment effectively.

System Architecture
The HITL code review agent consists of components for review generation, confidence assessment, approval management, and feedback processing. The flow is:

PR Webhook triggers the review process
Review Engine generates the review using feedback-refined prompts
Confidence Assessor estimates how certain the agent is
Autonomy Decision determines the appropriate mode
Execution posts autonomously, queues for approval, or escalates
Feedback Collector captures human reactions for improvement
HITL code review agent flow showing PR webhook through review engine, confidence assessment, autonomy decision, execution modes, and feedback loop

![Complete HITL code review agent architecture](https://hrcdn.net/ai-engineering/module-4/dark/hitl-lesson04-system-architecture.svg)

```python
class HITLCodeReviewAgent:
  def __init__(self, config):
      self.policy_engine = PolicyEngine()
      self.confidence_estimator = ConsistencyBasedConfidence(self.llm)
      self.escalation_engine = EscalationEngine(config)
      self.approval_engine = ApprovalEngine(storage, notifier)
      self.feedback_collector = FeedbackCollector(storage)
      self.prompt_manager = FeedbackDrivenPromptManager(storage)

  async def review_pr(self, pr_number, repo):
      pr_context = await self.fetch_pr_context(pr_number, repo)
      review_draft = await self.generate_review(pr_context)
      confidence = await self.estimate_confidence(review_draft, pr_context)
      mode = self.determine_mode(review_draft, confidence, pr_context)
      return await self.execute_mode(mode, review_draft, confidence, pr_context)
```

The agent flows through these steps: generate review using feedback-improved prompts, estimate confidence through consistency and calibration, determine autonomy level based on confidence and risk, then execute accordingly.

Confidence Assessment and Mode Selection
The agent combines multiple confidence signals: stated confidence from structured outputs, response consistency across multiple generations, historical calibration based on past accuracy, and context adjustments for factors like PR size and file sensitivity.

```python
def determine_mode(self, review, confidence, context) -> str:
  risk = self._assess_risk(context)

  if risk == "critical":
      return "escalated"
  if risk == "high" and confidence < 0.7:
      return "escalated"
  if risk == "high":
      return "approval_required"
  if risk == "low" and confidence > 0.8:
      return "autonomous"

  return "approval_required"
```

Each mode executes differently: autonomous posts immediately, approval queues for human review, assisted posts with disclaimers requesting verification, and escalated hands off entirely with a draft for human completion.

Understanding how confidence and risk interact helps you determine the right autonomy mode for each situation.

Mode Execution
Each autonomy mode requires different execution logic:

```python
async def execute_mode(self, mode, review, confidence, context):
  if mode == "autonomous":
      return await self._execute_autonomous(review, confidence, context)
  elif mode == "assisted":
      return await self._execute_assisted(review, confidence, context)
  elif mode == "approval_required":
      return await self._execute_with_approval(review, confidence, context)
  elif mode == "escalated":
      return await self._execute_escalation(review, confidence, context)
```

Autonomous execution posts directly with feedback collection:

```python
async def _execute_autonomous(self, review, confidence, context):
  formatted = self._format_for_github(review)
  formatted["body"] += self._add_feedback_section(review["review_id"])

  await self.github.post_review(context["repo"], context["pr_number"], formatted)
  return {"mode": "autonomous", "confidence": confidence, "feedback_enabled": True}
```

Approval-required execution queues for human review:

```python
async def _execute_with_approval(self, review, confidence, context):
  approval_request = await self.approval_engine.submit_for_approval(
      action_type="post_review",
      payload={"review": review, "context": context},
      context={"pr_number": context["pr_number"], "confidence": confidence}
  )
  return {"mode": "approval_required", "approval_id": approval_request.action_id}
```

Escalation hands off to humans with a draft:

```python
async def _execute_escalation(self, review, confidence, context):
  decision = self.escalation_engine.decide_escalation(review, confidence, context)
  targets = await self.escalation_engine.route_escalation(decision, context)

  for target in targets:
      await self.notifier.send_escalation(target, {
          "pr_context": context,
          "draft_review": review,
          "reason": decision.get("reason")
      })
  return {"mode": "escalated", "escalation_target": targets[0] if targets else None}
```

Feedback Integration and Continuous Improvement
The agent collects feedback and uses it to improve over time:

```python
def _add_feedback_section(self, review_id: str) -> str:
  return f"""
    ---
    <details>
    <summary>📊 Rate this review</summary>

    - [👍 Helpful](https://feedback.example.com/{review_id}?rating=helpful)
    - [👎 Not Helpful](https://feedback.example.com/{review_id}?rating=not_helpful)
    - [🎯 Good Catch](https://feedback.example.com/{review_id}?rating=good_catch)
    - [❌ Incorrect](https://feedback.example.com/{review_id}?rating=incorrect)
    </details>
  """
```

Daily feedback analysis detects patterns and updates prompts:

```python
async def daily_feedback_analysis(self):
  patterns = await self.feedback_collector.detect_patterns(timedelta(days=7))

  for pattern in patterns:
      if pattern["pattern"] == "high_rejection_rate":
          await self.prompt_manager.add_guideline(
              f"Be cautious with {pattern['suggestion_type']} suggestions. "
              f"Recent rejection rate: {pattern['rejection_rate']:.0%}."
          )

  recent_satisfaction = await self.feedback_collector.get_satisfaction_score()
  if recent_satisfaction < 0.7:
      await self.notifier.alert_team("Agent satisfaction dropping")
```

Common Pitfalls and Solutions
Over-escalation: The agent escalates too often, creating bottlenecks. Solution: tune confidence thresholds and track escalation rates to find the right balance.

Feedback not closing the loop: Feedback is collected but never influences behavior. Solution: implement daily feedback analysis that updates prompts or guidelines.

Mode selection too rigid: Fixed thresholds do not adapt to different contexts. Solution: consider context-specific thresholds based on file type, author experience, or historical accuracy.

No monitoring of satisfaction trends: Problems go unnoticed until users complain. Solution: track satisfaction scores and alert when they drop.

Now that you understand the complete HITL system, consider how to use feedback patterns to drive continuous improvement.

Your agent's feedback analysis detects a 70% rejection rate for a specific suggestion type. What is the best response?

Remove the suggestion type entirely

Add a guideline to the prompt cautioning about this suggestion type

Increase confidence threshold for this suggestion type

Ignore the pattern—70% rejection might be user error
Summary
A complete HITL code review agent integrates autonomy decisions, approval workflows, confidence estimation, escalation strategies, and feedback collection. The agent operates across a spectrum of autonomy—from fully autonomous for low-risk, high-confidence reviews to full escalation when it is out of its depth.

Confidence estimation uses multiple techniques: stated confidence, response consistency, historical calibration. Mode selection combines confidence with risk assessment to determine the appropriate level of human involvement.

Feedback collection enables continuous improvement. Explicit ratings, implicit signals from modifications, and pattern detection all contribute to prompt refinement and behavior adjustment over time.

Key Takeaways:

Integrate multiple HITL patterns: autonomy levels, approval, confidence, escalation, and feedback
Use multi-signal confidence estimation rather than relying on a single technique
Match autonomy level to both confidence and risk—high confidence alone is not enough for high-risk actions
Queue for approval when requirements dictate, even if confidence is high
Escalate gracefully with context so humans can take over effectively
Collect feedback at every level and use it to improve prompts and behavior
Monitor satisfaction trends to catch degradation early