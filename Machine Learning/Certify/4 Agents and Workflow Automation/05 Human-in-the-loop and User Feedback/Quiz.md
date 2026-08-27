## Quiz: Human-in-the-Loop and User Feedback

Human-in-the-Loop and User Feedback
Your code review agent is ready for production, but you need human oversight for high-stakes decisions. The agent should auto-post minor comments but require approval before blocking PRs or requesting changes. You also want to collect feedback to improve the agent over time. The system must handle approval workflows, timeouts, and feedback integration.


Why is human-in-the-loop oversight essential for production agents?

Humans are faster than agents at making decisions

Agents make mistakes that testing cannot fully prevent; human oversight provides safety nets for high-stakes decisions and enables correction of agent errors

Human oversight eliminates the need for testing agent systems

Agents cannot function without human approval for every action
Correct Answer!
Agents are imperfect and make reasoning errors. Human oversight catches mistakes before they cause damage, especially for irreversible or high-impact actions.

In the spectrum of agent autonomy, what does 'agent-initiated with override' mean?

Agents propose actions but humans must approve before execution

Agents execute actions automatically, but humans can intervene, edit, or retract those actions after execution

Humans make all decisions and agents only provide information

Agents execute without any human involvement or oversight
Correct Answer!
Agent-initiated with override means agents act autonomously, but humans retain the ability to modify or undo actions.

When determining if an agent action requires human approval, which factors should you consider?

Only the action type, regardless of context or impact

Reversibility (how easily actions can be undone), impact scope (how many people/systems are affected), and agent confidence level

Only the cost of the action in API tokens

Only whether the agent has made similar decisions before
Correct Answer!
These three factors help assess risk: irreversible actions, broad impact, and low confidence all warrant human oversight.

What are the key elements that an approval workflow must handle?

Only routing approval requests to the right person

What triggers approval, who approves, what information they see, how they respond, and what happens after approval or rejection

Only storing approval requests in a database

Only sending email notifications to approvers
Correct Answer!
Complete workflows handle the full lifecycle: triggers, routing, information presentation, response handling, and post-approval execution.

When an approval request times out (approver doesn't respond within the deadline), what should happen?

The action should execute automatically after timeout

The system should escalate to alternative approvers, cancel the action, or apply a default policy based on the action's risk level

The agent should retry the approval request indefinitely until someone responds

The approval request should be deleted and the action forgotten
Correct Answer!
Timeout handling depends on risk: high-risk actions should escalate or cancel, while low-risk might have safe defaults.

Why is collecting human feedback important for improving agent systems?

Feedback is only useful for tracking user satisfaction metrics

Feedback helps identify agent mistakes, correct false positives/negatives, and improve future decision-making through learning from human corrections

Feedback eliminates the need for automated testing of agents

Feedback is only needed during development, not in production
Correct Answer!
Human feedback reveals where agents fail, provides corrections, and creates training data to improve future performance.

How should an agent use confidence estimation to determine when to escalate to humans?

Agents should always escalate, regardless of confidence level

Agents should escalate when confidence is low or when actions are high-risk, allowing autonomous execution for high-confidence, low-risk decisions

Confidence estimation is not useful for determining escalation

Agents should only escalate based on action type, not confidence
Correct Answer!
Confidence-based escalation enables autonomy for routine decisions while ensuring human oversight for uncertain or risky actions.

SkillUp | Hackerrank