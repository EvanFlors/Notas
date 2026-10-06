## Designing Approval Workflows
Your code review agent is ready to post a suggestion: "This function should be refactored into three smaller functions." It is a significant change, and you want a human to verify before posting. But how? Does the agent wait? For how long? Who reviews it? What if they are busy?

Approval workflows answer these questions. They define the mechanics of human review: how requests are queued, who sees them, what happens when approvers are unavailable, and how human edits get incorporated.

In this lesson, you will learn how to design approval workflows that feel natural, handle edge cases gracefully, and capture human feedback for agent improvement.

By the end, you will have patterns for building approval systems that make human-agent collaboration efficient rather than frustrating.

Workflow Fundamentals
Approval workflows create checkpoints where humans review agent decisions before they take effect. The workflow design determines how smoothly humans and agents collaborate.

A code review agent might generate a comprehensive review with multiple comments and a recommendation. Rather than posting immediately, it submits the review for approval. A human reviewer sees the proposed comments, edits any that seem off, and approves the batch. The agent then posts the final version.

The key workflow elements are: what triggers approval, who approves, what information they see, how they respond, and what happens after.

```python
from dataclasses import dataclass
from enum import Enum
from datetime import datetime, timedelta

class ApprovalStatus(Enum):
  PENDING = "pending"
  APPROVED = "approved"
  REJECTED = "rejected"
  MODIFIED = "modified"
  EXPIRED = "expired"

@dataclass
class PendingAction:
  action_id: str
  action_type: str
  payload: dict
  created_at: datetime
  expires_at: datetime
  status: ApprovalStatus = ApprovalStatus.PENDING
  required_approvers: list = None
  approvals_received: list = None
```

Approval Engine Implementation
The approval engine manages the lifecycle of pending actions—from submission through approval or rejection.

```python
class ApprovalEngine:
  async def submit_for_approval(self, action_type: str, payload: dict,
                                 context: dict) -> PendingAction:
      workflow = self._get_workflow(action_type)
      approvers = await self._find_approvers(workflow, context)

      pending = PendingAction(
          action_id=str(uuid.uuid4()),
          action_type=action_type,
          payload=payload,
          created_at=datetime.utcnow(),
          expires_at=datetime.utcnow() + timedelta(hours=workflow.timeout_hours),
          required_approvers=approvers
      )

      await self.storage.save_pending(pending)
      for approver in approvers:
          await self.notifier.request_approval(pending, approver)

      return pending
```

The engine routes actions to appropriate approvers, tracks responses, and handles timeouts. Different action types can have different workflows—code reviews might need one approval, while auto-merge might need two.

Understanding the approval engine's key elements helps you design workflows that handle real-world scenarios.

Implementing Review Queues
Approval requests need a queue system that tracks pending items, handles timeouts, and routes to available reviewers.

```python
class ApprovalQueue:
  async def get_queue_for_approver(self, approver: str) -> list:
      """Get all items an approver can act on"""
      all_pending = await self.storage.get_pending_items()

      approver_items = [
          item for item in all_pending
          if approver in item.required_approvers
          and item.status == ApprovalStatus.PENDING
      ]

      # Sort by priority, then by age
      approver_items.sort(key=lambda x: (-x.priority, x.created_at))
      return approver_items

  async def process_timeouts(self):
      """Handle expired approvals"""
      pending_items = await self.storage.get_pending_items()
      now = datetime.utcnow()

      for item in pending_items:
          if item.status == ApprovalStatus.PENDING and now > item.expires_at:
              await self._handle_expiry(item)
```

Timeout handling defines what happens when approvals are not received in time:

```python
async def _handle_expiry(self, pending: PendingAction):
  workflow = self._get_workflow(pending.action_type)

  if workflow.on_timeout == "escalate":
      pending.status = ApprovalStatus.ESCALATED
      await self._escalate(pending)
  elif workflow.on_timeout == "auto_approve":
      pending.status = ApprovalStatus.APPROVED
      await self._execute_action(pending)
  else:  # auto_reject
      pending.status = ApprovalStatus.REJECTED
      await self.notifier.notify_rejection(pending, "Approval timed out")

  await self.storage.save_pending(pending)
```

Load balancing distributes approval requests fairly among available reviewers:

```python
class ApprovalLoadBalancer:
  async def select_approvers(self, eligible: list, count: int) -> list:
      """Select approvers with balanced workload"""
      loads = {}
      for approver in eligible:
          loads[approver] = await self._get_approver_load(approver)

      # Sort by load (ascending) and select
      sorted_approvers = sorted(eligible, key=lambda a: loads[a])
      return sorted_approvers[:count]
```

Now that you understand review queue implementation, consider how to prevent common problems like approval fatigue.

Modification and Feedback Capture
When approvers modify agent-proposed actions, capturing these modifications improves future agent performance.

```python
class ApprovalWithModification:
  async def approve_with_edits(self, action_id: str, approver: str,
                                edits: dict, feedback: str = None) -> dict:
      """Approve an action with modifications"""
      pending = await self.storage.get_pending(action_id)

      # Apply edits
      if "comments" in edits:
          pending.payload["comments"] = self._merge_comments(
              pending.payload.get("comments", []), edits["comments"]
          )

      # Record modification as feedback
      await self.tracker.record_modification(pending, approver, edits)

      # Complete approval
      return await self.engine.process_approval(action_id, approver, "approved", edits)
```

Modifications serve as valuable training signals. If a human consistently edits agent suggestions in a particular way, that pattern can inform prompt improvements.

Common Pitfalls and Solutions
Single point of failure: If only one person can approve, vacations or busy periods block the system. Solution: define pools of eligible approvers with load balancing.

Approval fatigue: Too many requests cause approvers to rubber-stamp without reviewing. Solution: calibrate what truly needs approval versus what can proceed automatically.

Lost modifications: Human edits are applied but not recorded. Solution: capture every modification for feedback analysis.

No reassignment: If an approver becomes unavailable, the request hangs. Solution: detect unavailability and automatically reassign to another eligible approver.

Summary
Approval workflows create structured checkpoints for human review. The workflow design includes trigger conditions, approver selection, timeout handling, and modification support.

Queue systems track pending approvals and handle timeouts with configurable behaviors—escalate, auto-approve, or auto-reject. Load balancing distributes work fairly among approvers.

Modification tracking captures when humans edit agent proposals, providing valuable feedback for improving agent performance.

Key Takeaways:

Design workflows around what triggers approval, who approves, and what happens after
Implement queues that track pending items and handle timeouts gracefully
Balance approval load across available reviewers
Allow modifications during approval to capture human corrections
Record modifications as feedback for agent improvement
Support multiple escalation paths when approvals are not received in time