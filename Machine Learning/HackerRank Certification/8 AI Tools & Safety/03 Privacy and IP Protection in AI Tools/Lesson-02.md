## When "Don't Share Sensitive Data" Is Too Vague

Imagine your team has a policy: "Do not share sensitive data with AI tools." A developer needs to debug an issue and pastes a log file into an AI assistant. The log contains customer emails, but the developer does not realize emails are "sensitive data" under your policy. The data leaks, and you discover that your policy was too vague to be actionable.

This is why classification matters for AI workflows. Most data policies fail because they are too vague. "Do not share sensitive data" sounds reasonable, but it leaves developers guessing. Classification turns vague policy into concrete rules that can be enforced automatically.

In this lesson, you will learn how to build a simple classification scheme for developer workflows, how to implement redaction pipelines that remove sensitive data before it reaches AI tools, and how to test and monitor redaction quality. You will understand why classification enables automation, how redaction improves both safety and quality, and how to balance protection with usability.

By the end, you will have a practical classification and redaction framework that prevents data leaks while still allowing AI tools to be useful.

Why Classification Matters for AI Workflows
For AI-assisted development, a simple classification scheme is enough:

Public: safe to share. This includes open-source code, public documentation, and non-sensitive examples.

Internal: not public, but low sensitivity. This includes internal documentation, non-sensitive code, and general engineering discussions.

Confidential: proprietary code, internal docs, non-public product data. This includes your codebase, architecture decisions, and business logic.

Restricted: secrets, credentials, regulated data, customer PII. This includes API keys, passwords, customer information, and any data that would cause harm if exposed.

Once data is classified, you can enforce consistent handling rules. AI tools should never see restricted data, and they should see confidential data only through approved paths. This makes policy actionable instead of aspirational.

Classification also helps teams make decisions quickly. If a developer knows a file is "restricted," the rule is automatic: do not include it in prompts or logs. The classification removes ambiguity. When classification is clear, decisions are fast. When classification is vague, decisions are slow and inconsistent.

Classification also supports automation. If a file is tagged as restricted, the AI tool can automatically block it. This reduces the need for human judgment in the moment, which is where most leaks happen. When classification is automated, protection is consistent. When classification is manual, protection is inconsistent.

Building a Classification Inventory
Start with the highest-value data sources:

Production logs: these often contain customer data, secrets, and sensitive information.

Configuration repositories: these often contain API keys, database credentials, and service configurations.

Customer support tickets: these often contain customer PII and account information.

Internal knowledge bases: these often contain proprietary information and architecture decisions.

For each source, assign a classification and document how AI tools are allowed to access it. This inventory makes it possible to scale safe usage across teams. When sources are classified, access rules are clear. When sources are not classified, access rules are unclear.

Consider what happens without classification. A developer needs to debug an issue and looks at production logs. They do not know if logs are "sensitive," so they paste them into an AI tool. The logs contain customer emails, and the data leaks. With classification, the logs are marked as "restricted," and the tool blocks them automatically.

Where Sensitive Data Hides in Dev Workflows
Sensitive data often appears in places developers do not expect:

Log lines that include request headers: headers might contain authentication tokens or customer identifiers.

Config files with embedded tokens: configuration might include API keys or database passwords.

Stack traces that include user identifiers: error messages might contain customer emails or account IDs.

Sample datasets used in tests: test data might contain real customer information copied from production.

If your tool automatically gathers context, these sources can be pulled into prompts. Classification helps you build redaction rules that catch these cases before they leave the system boundary. When sources are classified, redaction rules are clear. When sources are not classified, redaction rules are unclear.

Redaction Is a Safety Control and a Quality Control
Redaction is not only about privacy. It improves output quality by removing noise. A clean, redacted prompt often produces more accurate outputs because the model is not distracted by irrelevant secrets or identifiers.

Consider what happens with unredacted prompts. A developer pastes a log file that contains customer emails, API keys, and error messages. The AI tool sees all of this and gets confused about what matters. It might focus on the wrong information or generate code that references sensitive data. With redaction, the tool sees only what matters, producing better results.

Redaction should happen as close to the source as possible. If you redact after the prompt is sent, you have already failed the policy. The data has left your control. When redaction happens early, leaks are prevented. When redaction happens late, leaks have already occurred.

Classification Labels in Repositories
One way to operationalize classification is to label directories or files:

```restricted/``` for secrets or regulated data. Files in this directory should never be accessed by AI tools.

```confidential/``` for proprietary logic. Files in this directory should be accessed only through approved paths.

```internal/``` for general engineering docs. Files in this directory can be accessed by AI tools with caution.

These labels can be enforced by tooling. If the AI tool attempts to read a restricted path, it should be blocked or require approval. When labels are enforced, protection is automatic. When labels are not enforced, protection is manual and inconsistent.

Here is an example of classification labels in a repository:

.data-classification.md
```markdown
# Data Classification Labels

## Directory Classifications

### Restricted (Never Access with AI Tools)
- secrets/ - API keys, credentials, tokens
- credentials/ - Database passwords, service accounts
- .env* - Environment files with secrets
- deployment/keys/ - SSH keys, certificates

### Confidential (Requires Approval)
- src/ - Proprietary source code
- architecture/ - Internal architecture decisions
- roadmap/ - Product plans and strategy

### Internal (Use with Caution)
- docs/ - Internal documentation
- tests/ - Test files (may contain test data)

### Public (Safe to Share)
- public/ - Public documentation
- examples/ - Example code (no secrets)
```

Here is an example of a redaction pipeline:

redaction-pipeline.py
```python
#!/usr/bin/env python3
"""
Redaction pipeline for AI tool inputs.
Removes sensitive data before sending to AI tools.
"""

import re
from typing import List, Dict
from pathlib import Path

class DataRedactor:
  """Redacts sensitive data from content."""

  def __init__(self):
      # Patterns for different data types
      self.patterns = {
          "email": r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
          "ssn": r'\b\d{3}-\d{2}-\d{4}\b',
          "phone": r'\b\d{3}-\d{3}-\d{4}\b',
          "api_key": r'(?i)(api[_-]?key|apikey)\s*[:=]\s*["\']?([A-Za-z0-9_\-]{20,})["\']?',
          "token": r'(?i)(token|bearer)\s*[:=]\s*["\']?([A-Za-z0-9_\-]{32,})["\']?',
          "password": r'(?i)(password|passwd|pwd)\s*[:=]\s*["\']([^"\']+)["\']',
      }

  def redact_content(self, content: str, data_types: List[str] = None) -> str:
      """Redact specified data types from content."""
      if data_types is None:
          data_types = list(self.patterns.keys())

      redacted = content

      for data_type in data_types:
          if data_type in self.patterns:
              pattern = self.patterns[data_type]
              replacement = f"[{data_type.upper()}_REDACTED]"
              redacted = re.sub(pattern, replacement, redacted)

      return redacted

  def redact_file(self, file_path: Path, classification: str) -> str:
      """Redact file based on classification."""
      content = file_path.read_text()

      if classification == "restricted":
          # Redact everything sensitive
          return self.redact_content(content)
      elif classification == "confidential":
          # Redact PII but keep code structure
          return self.redact_content(content, ["email", "ssn", "phone"])
      elif classification == "internal":
          # Light redaction
          return self.redact_content(content, ["api_key", "token", "password"])
      else:
          # Public - no redaction needed
          return content
```


Before diving into redaction pipelines, consider how classification allows you to build deterministic redaction rules that are enforceable and easy to audit.

Building a Practical Redaction Pipeline
A minimal redaction pipeline for AI tools includes:

Pattern detection: find tokens, keys, emails, and IDs with regex rules. This catches common sensitive patterns.

Context-aware filters: confirm that matches are actually sensitive. This reduces false positives.

Masking rules: replace sensitive values with placeholders. This preserves structure while removing data.

Audit logs: record what was removed and why. This enables debugging and learning.

Pattern detection is fast but imperfect. Context-aware filtering reduces false positives. For example, a string that looks like an API key might be a test fixture. Use a list of known test tokens or safe allowlists to reduce noise. When patterns are context-aware, false positives are reduced. When patterns are not context-aware, false positives are common.

Redaction Patterns That Actually Work
Effective redaction patterns are specific and tested:

Keys with known prefixes: API keys often start with "sk_" or "pk_". These patterns are reliable.

UUIDs with associated labels: UUIDs labeled "user_id" or "account_id" are likely sensitive. Labels provide context.

Email addresses and phone numbers: these are clearly PII and should be redacted.

Credit card patterns with checksum validation: credit cards have specific formats and checksums. These patterns are reliable.

Do not over-redact. If you remove too much, the model will not have enough context to be useful. The goal is to remove sensitive data while keeping the task solvable. When redaction is balanced, tools are useful and safe. When redaction is excessive, tools are safe but not useful.

Human-Readable Redaction
Redaction should preserve meaning where possible. Replace a secret with a placeholder like API_KEY_REDACTED instead of deleting the line entirely. This keeps the prompt understandable and helps the model respond appropriately.

Consider what happens with deletion. A developer pastes a config file that contains an API key. The redaction pipeline deletes the entire line. The AI tool sees a config file with missing values and cannot understand the structure. It generates code that does not work. With placeholders, the tool sees the structure and generates working code.

Handling Structured Data
Redaction is easier when data is structured. If you can convert logs or records to JSON with labeled fields, you can target redaction precisely. This is often more accurate than regex-only approaches and reduces false positives.

Consider what happens with structured data. A log entry is JSON: ```{"user_id": "12345", "email": "user@example.com", "action": "login"}```. You can redact the ```user_id``` and ```email``` fields precisely, leaving the ```action``` field intact. The tool sees the structure and the action, enabling useful responses. With unstructured data, redaction is less precise and more likely to remove useful information.

Redaction Before Retrieval and After Retrieval
There are two places to apply redaction:

Before retrieval: sanitize documents and logs in storage. This prevents sensitive data from being stored in the first place.

After retrieval: sanitize the retrieved content before prompting. This protects against newly introduced sensitive content.

Both are valuable. Pre-redaction reduces risk in storage, while post-redaction protects against newly introduced sensitive content. When redaction happens in both places, protection is layered. When redaction happens in only one place, protection is incomplete.

Testing and Monitoring Redaction Quality
Redaction needs tests just like any other code:

Unit tests for each regex pattern: verify that patterns catch what they should.

Integration tests for common log formats: verify that redaction works with real data formats.

Regression tests for known leaks: verify that past leaks are prevented.

Monitor false positives and false negatives. If you over-redact, the model becomes less useful. If you under-redact, you risk leakage. The balance should be explicit and measurable. When redaction is tested and monitored, quality is maintained. When redaction is not tested, quality degrades.

Sampling Audits for Redaction Drift
Even good pipelines drift over time as new data formats appear. Add a lightweight sampling audit:

Sample a small percentage of prompts each week: check a random sample of prompts for redaction quality.

Verify that sensitive fields were redacted correctly: ensure patterns are still working.

Update patterns when new formats appear: adapt to changing data formats.

This keeps the pipeline aligned with real data, not just test fixtures. When audits are regular, drift is caught early. When audits are irregular, drift accumulates.

Redaction Failure Handling
Redaction will occasionally fail. When it does, treat it like any other safety issue:

Log the failure with minimal sensitive content: record what happened without exposing data.

Add a new test case for the missed pattern: prevent the same failure from happening again.

Update the redaction rule set: improve the pipeline based on the failure.

This turns a one-time mistake into a systematic improvement. When failures are learned from, systems improve. When failures are ignored, systems degrade.


Summary: Make Redaction Deterministic
Data classification gives you a shared language for what is safe. Redaction turns that language into enforceable rules. The best pipelines are deterministic, tested, and auditable. When classification is clear and redaction is automated, protection is consistent and reliable.

Redaction improves both safety and quality. It prevents data leaks and improves AI tool outputs by removing noise. When redaction is done well, tools are safer and more useful. When redaction is done poorly, tools are either unsafe or not useful.

Redaction in the Developer Experience
The most successful redaction systems are invisible. Developers should not have to manually redact data in every prompt. If they do, they will skip it under pressure. Build redaction into the tooling so that safe behavior is the default behavior.

When redaction is automatic, developers use it. When redaction is manual, developers skip it. The goal is to make safe behavior easy and unsafe behavior hard. When redaction is built in, safe behavior is the default.

A Redaction Readiness Checklist
Are classification labels applied to high-risk data? If not, redaction rules are unclear.

Do we have redaction rules for common secret formats? If not, secrets will leak.

Are redaction rules tested in CI? If not, rules will break without notice.

Do we monitor false positives and false negatives? If not, quality will degrade.

If any answer is no, redaction is likely to fail in practice. When readiness is incomplete, protection is incomplete. When readiness is complete, protection is reliable.

Exceptions and Override Paths
Sometimes teams need to override redaction for legitimate reasons, such as debugging an incident. If you allow overrides, they should be:

Time-limited: overrides expire automatically.

Approved by an owner: overrides require explicit approval.

Fully logged: overrides are recorded for audit.

This keeps exceptions rare and auditable rather than routine and invisible. When overrides are controlled, they are manageable. When overrides are uncontrolled, they become the norm.

Connecting Redaction to Policy
Redaction rules should map directly to classification policy. If a data type is classified as restricted, there must be a corresponding redaction rule. This alignment reduces ambiguity and makes audits much easier.

When redaction aligns with policy, protection is consistent. When redaction does not align with policy, protection is inconsistent. The goal is to make redaction a direct implementation of policy, not a separate system.

Common Pitfalls and Solutions
Pitfall: redaction rules with no tests. Solution: add unit tests for every redaction pattern. When rules are not tested, they break silently. When rules are tested, they are reliable.

Pitfall: over-redacting context. Solution: add allowlists and context rules to preserve useful data. When redaction is excessive, tools are not useful. When redaction is balanced, tools are useful and safe.

Pitfall: redaction after the prompt is sent. Solution: enforce redaction before any outbound request. When redaction happens late, leaks have already occurred. When redaction happens early, leaks are prevented.

Pitfall: no classification. Solution: classify data before building redaction rules. When classification is missing, redaction rules are unclear. When classification is present, redaction rules are clear.

Pitfall: no monitoring. Solution: monitor redaction quality and adapt to changes. When monitoring is missing, quality degrades. When monitoring is present, quality is maintained.

Key concepts to remember
Classification makes policy actionable—define what is public, confidential, and restricted
Redaction should be deterministic—pattern rules plus context checks
Redact early—sanitize before data leaves the system boundary
Test the redaction pipeline—treat redaction like any other critical control
Monitor quality—track false positives and false negatives
Make it invisible—build redaction into tooling so safe behavior is default
Connect to policy—redaction rules should map directly to classification policy