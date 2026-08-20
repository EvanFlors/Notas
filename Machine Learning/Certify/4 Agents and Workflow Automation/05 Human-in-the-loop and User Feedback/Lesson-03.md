## Why Feedback Matters

Your code review agent keeps suggesting developers add extensive error handling to test files. Developers dismiss these suggestions every time. But the agent does not know—it has no mechanism to learn from this pattern. Next week, it makes the same unhelpful suggestions again.

Feedback closes the gap between agent behavior and human expectations. Without it, agents are frozen in their initial configuration, repeating mistakes indefinitely. With feedback, agents improve continuously, learning which suggestions developers find valuable.

In this lesson, you will learn how to design feedback mechanisms that capture explicit ratings, track implicit signals, and translate human input into agent improvements.

By the end, you will have patterns for building agents that get better over time based on real-world usage.

The Feedback Loop
Agents improve through feedback. Without a mechanism to capture what worked and what did not, agents repeat the same mistakes indefinitely.

Feedback comes in multiple forms: explicit ratings, implicit signals, and corrections. A developer clicking "helpful" on a review comment provides explicit feedback. A developer ignoring a suggestion provides implicit feedback. A developer editing the agent's comment before posting provides corrective feedback.

```python
from enum import Enum
from dataclasses import dataclass
from datetime import datetime

class FeedbackType(Enum):
  HELPFUL = "helpful"
  NOT_HELPFUL = "not_helpful"
  INCORRECT = "incorrect"
  GOOD_CATCH = "good_catch"

@dataclass
class FeedbackItem:
  feedback_id: str
  action_id: str
  feedback_type: FeedbackType
  user: str
  timestamp: datetime
  text_feedback: str = None
```

Designing Feedback Mechanisms
Effective feedback collection is low-friction and contextual. Asking for feedback at the wrong time or requiring too much effort results in sparse, biased data.

Inline feedback captures reactions in context:

```python
class InlineFeedbackCollector:
  def generate_feedback_buttons(self, action_id: str) -> dict:
      return {
          "options": [
              {"label": "👍", "value": "helpful"},
              {"label": "👎", "value": "not_helpful"},
              {"label": "🎯", "value": "good_catch"},
              {"label": "❌", "value": "incorrect"}
          ]
      }

  async def record_feedback(self, action_id: str, feedback_type: str, user: str):
      feedback = FeedbackItem(
          feedback_id=str(uuid.uuid4()),
          action_id=action_id,
          feedback_type=FeedbackType(feedback_type),
          user=user,
          timestamp=datetime.utcnow()
      )
      await self.storage.save_feedback(feedback)

      if feedback_type in ["incorrect", "not_helpful"]:
          await self.queue_for_review(feedback)
```

Post-action surveys gather detailed feedback after significant interactions. Keep surveys short—one or two questions maximum—to maintain response rates.

Understanding different types of feedback helps you design comprehensive collection mechanisms.

Implicit Feedback Signals
Not all feedback requires explicit action. User behavior signals satisfaction or dissatisfaction implicitly.

```python
class ImplicitFeedbackTracker:
  def __init__(self):
      self.signal_weights = {
          "suggestion_applied": 1.0,       # Strong positive
          "suggestion_modified": 0.5,      # Weak positive
          "suggestion_ignored": -0.3,      # Weak negative
          "suggestion_dismissed": -0.8,    # Strong negative
          "review_quick_merge": 0.7,       # Positive
          "review_disputed": -0.9,         # Strong negative
      }

  async def track_suggestion_outcome(self, action_id: str, suggestion_id: str,
                                      outcome: str):
      weight = self.signal_weights.get(f"suggestion_{outcome}", 0)
      await self.update_suggestion_score(suggestion_id, weight)
```

Behavioral pattern detection identifies systematic issues:

```python
class FeedbackPatternDetector:
  async def detect_patterns(self, time_window: timedelta) -> list:
      patterns = []

      # Low accuracy for specific file types
      accuracy_by_type = await self.analyze_accuracy_by_file_type(time_window)
      for file_type, accuracy in accuracy_by_type.items():
          if accuracy < 0.3:
              patterns.append({
                  "pattern": "low_accuracy_file_type",
                  "file_type": file_type,
                  "accuracy": accuracy
              })

      # High rejection rate for suggestion types
      rejection_rates = await self.analyze_suggestion_rejections(time_window)
      for suggestion_type, rate in rejection_rates.items():
          if rate > 0.7:
              patterns.append({
                  "pattern": "high_rejection_rate",
                  "suggestion_type": suggestion_type,
                  "rejection_rate": rate
              })

      return patterns
```

Using Feedback to Improve Agents
Collected feedback should drive agent improvements. Prompt refinement incorporates feedback into prompts:

```python
class FeedbackDrivenPromptManager:
  async def get_refined_prompt(self, context: dict) -> str:
      prompt_parts = [self.base_prompt]

      guidelines = await self.get_feedback_guidelines(context)
      if guidelines:
          prompt_parts.append("\n## Guidelines from Past Feedback\n")
          prompt_parts.extend(guidelines)

      negative_examples = await self.get_negative_examples(context)
      if negative_examples:
          prompt_parts.append("\n## Common Mistakes to Avoid\n")
          prompt_parts.extend(negative_examples)

      return "\n".join(prompt_parts)
```

Confidence Estimation
Agents that know what they do not know are more valuable than agents that confidently make mistakes. Confidence estimation helps agents decide when to proceed autonomously versus when to escalate.

Response consistency measures confidence by asking the same question multiple times:

```python
async def estimate_with_consistency(self, messages, num_samples=3):
  """Generate multiple responses and measure agreement"""
  responses = await asyncio.gather(*[
      self.llm.chat(messages, temperature=0.7) for _ in range(num_samples)
  ])

  decisions = [self._extract_decision(r) for r in responses]
  consistency_score = max(Counter(decisions).values()) / len(decisions)
  return consistency_score
```

Structured uncertainty asks the model to explicitly rate its confidence per issue. Calibrate stated confidence against historical accuracy—if the model says "high confidence" but is historically wrong 30% of the time, adjust accordingly.

Escalation Strategies
When confidence is low or risk is high, agents should escalate to humans:

```python
class EscalationEngine:
  def decide_escalation(self, review, confidence, risk) -> dict:
      if self._has_critical_security_issue(review):
          return {"level": "security", "urgency": "immediate"}
      elif confidence < 0.5:
          return {"level": "senior", "urgency": "soon"}
      elif self._is_high_impact(review):
          return {"level": "lead", "urgency": "when_available"}
      return {"should_escalate": False}
```

Escalation routing finds the right person based on expertise, code ownership, and availability. Critical security issues go to the security team immediately. Low-confidence reviews go to senior engineers.

Graceful degradation ensures agents remain useful even when uncertain. High confidence proceeds autonomously. Medium confidence posts with disclaimers. Low confidence escalates with a draft review for human completion.

Now that you understand confidence estimation and escalation strategies, apply that knowledge to calibrating agent confidence.

Summary
Feedback collection enables continuous agent improvement. Explicit feedback through ratings provides clear signals. Implicit feedback through behavior tracking captures signals without user effort.

Pattern detection identifies systematic issues—file types with low accuracy, frequently rejected suggestions. Feedback integration refines prompts with guidelines and negative examples.

Confidence estimation using response consistency helps agents know when they are uncertain. Escalation strategies route uncertain or high-risk decisions to appropriate humans.

Key Takeaways:

Design low-friction feedback mechanisms that capture reactions in context
Track implicit signals like suggestion acceptance, modification, and dismissal
Aggregate feedback to detect patterns indicating systematic issues
Use feedback to refine prompts with guidelines and negative examples
Use response consistency to estimate confidence beyond model self-assessment
Define clear escalation rules based on confidence, risk, and issue type
Route escalations to people with relevant expertise and availability
Degrade gracefully: post with disclaimers, request verification, or escalate