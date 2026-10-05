## Quiz: Privacy and IP Protection in AI Tools

Privacy and IP Protection in AI Tools
Your organization is rolling out AI coding tools across multiple teams. You must protect proprietary code, prevent prompt logs from storing sensitive data, and meet privacy requirements without blocking developer productivity.


Which set of leak paths is most common in AI development tools?

Model size, temperature, and token limit.

Prompt content, context retrieval, and telemetry logs.

CPU usage, memory usage, and network latency.

Syntax errors, lint failures, and unit tests.
Correct Answer!
These are the primary routes for unintended data exposure.

What is the safest default rule for secrets in AI workflows?

Allow secrets if the tool is internal.

Allow secrets only when debugging production issues.

Never allow secrets to enter prompts or tool logs.

Allow secrets if they are short-lived.
Correct Answer!
Secrets are the highest-risk data category and should be blocked.

Why is data classification important for AI tool use?

It helps choose the best model architecture.

It defines what can be shared and what must be redacted.

It replaces the need for redaction.

It eliminates the need for audit logs.
Correct Answer!
Classification turns vague policy into enforceable rules.

Which retention approach best balances utility and risk?

Store all prompts forever to maximize future analysis.

Keep raw prompts briefly, store aggregated metrics longer.

Delete all logs immediately, even for incident response.

Store only outputs, not inputs.
Correct Answer!
Risk-based retention preserves useful signals while minimizing exposure.

Why is provenance tagging valuable for AI-assisted changes?

It improves model accuracy directly.

It enables you to reproduce and audit decisions later.

It eliminates the need for approvals.

It allows sensitive data to be stored indefinitely.
Correct Answer!
Provenance links outputs to prompts, context, and configuration.

Which statement best describes compliance for AI tools?

Compliance is a legal-only concern and does not affect engineering.

Compliance is best handled after deployment.

Compliance becomes actionable when it is implemented as technical controls.

Compliance is only relevant for external vendors.
Correct Answer!
Controls like redaction, retention, and access policies make compliance real.

When should redaction happen in AI workflows?

After prompts are sent to the model.

Before any sensitive data leaves the system boundary.

Only when a compliance audit is scheduled.

Only for external tools, not internal ones.
Correct Answer!
Redaction must happen before outbound requests or logging.