## Quiz: Securing Agentic Toolchains

Securing Agentic Toolchains
Your team is deploying an AI coding assistant that can read repos, run tools, and open pull requests. You want to prevent prompt injection, reduce blast radius, and keep high-risk actions under human control without blocking everyday productivity.


What is the most useful first step in a threat model for an AI toolchain?

Pick a model with the lowest latency.

List the assets and trust boundaries the tool can access.

Disable all tools so no actions can occur.

Write a generic security policy without mapping workflow steps.
Correct Answer!
Assets and boundaries define what needs protection and where risk enters.

Which permission strategy best reduces risk while keeping the tool useful?

Grant full repo and network access for convenience.

Grant minimum scopes and expand only with explicit approvals.

Give broad access in development and restrict only in production.

Use prompts as the only safeguard.
Correct Answer!
Least privilege plus approvals provides safe flexibility.

What makes indirect prompt injection especially dangerous?

It comes only from external web pages.

It hides instructions inside data that the model treats as trustworthy.

It requires advanced jailbreak prompts to succeed.

It is only a risk for consumer chatbots.
Correct Answer!
The model can follow hidden instructions if data is not treated as untrusted.

Which defense best reduces indirect prompt injection risk?

Treat retrieved text as untrusted data and separate it from instructions.

Increase model temperature for creativity.

Disable all retrieval permanently.

Only rely on human review after the tool acts.
Correct Answer!
Instruction-data separation prevents untrusted content from overriding rules.

Which action most clearly warrants an approval gate?

Formatting code to match lint rules.

Adding a new dependency for convenience.

Renaming a local variable in a test.

Updating comments in documentation.
Correct Answer!
Dependencies are a security and maintenance decision and should be approved.

What is the primary purpose of sandboxing tool-using agents?

To make the model more accurate.

To reduce the blast radius of mistakes or malicious actions.

To replace code review.

To allow unrestricted network access.
Correct Answer!
Sandboxing limits filesystem, network, and execution impact.

Why are network egress controls important in AI toolchains?

They prevent external sites from showing up in search results.

They reduce the chance of data exfiltration if the tool is compromised.

They make the model generate shorter outputs.

They improve code formatting consistency.
Correct Answer!
Blocking outbound access stops secrets from leaving the environment.