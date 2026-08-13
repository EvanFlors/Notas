LLMs in Practice
You are deploying AI code review as a production system integrated with IDEs, CI/CD pipelines, and code review workflows. Real-world constraints: 200ms response time for IDE integration, $0.02 per analysis budget, 99.9% uptime requirement, and seamless integration with existing developer tools.


For real-time IDE integration, which implementation strategy best balances performance and capability?

Run all analysis through LLMs for consistent high-quality results.

Implement a tiered system: fast local models for real-time feedback, LLMs for detailed analysis on-demand.

Cache all possible code patterns and their analyses for instant lookup.

Use only the fastest available models regardless of analysis quality.
Correct Answer!
Tiered approach: immediate feedback for common cases, deep analysis when needed. Balances UX with costs and speed.

How should you monitor your production system to ensure it is delivering business value?

Track developer adoption rates, suggestion acceptance rates, actual bug reduction, and developer productivity metrics.

Focus only on technical metrics like model accuracy, latency, and system uptime.

Monitor primarily based on user complaints and support tickets.

Use the same evaluation metrics from your development environment.
Correct Answer!
Production needs business metrics: adoption, suggestion quality, actual bug impact matter for developer tools.

A major dependency library update introduces new patterns not in your training data, causing your system to flag correct code as potentially buggy. What is your immediate response strategy?

Disable the system until you can retrain on the new library patterns.

Let the LLM handle it since it should be able to generalize to new patterns.

Implement rapid feedback collection from developers and fast model updating pipelines while providing manual override options.

Add rule-based exceptions for the new library patterns.
Correct Answer!
Graceful degradation: collect feedback quickly, let developers override bad suggestions, enable fast model updates without full retraining.

Your system needs to handle sensitive proprietary code. Which deployment approach best addresses security and privacy concerns?

Use cloud-based LLM APIs for the most capable analysis.

Anonymize code by removing variable names and comments before analysis.

Deploy smaller, specialized models on-premises while using cloud LLMs only for anonymized, generalized patterns.

Avoid using any external AI services and rely only on rule-based analysis.
Correct Answer!
Hybrid: on-premises models for proprietary code, cloud services for general programming knowledge/patterns only.

After 6 months in production, you notice developers increasingly ignore certain types of suggestions. How should you adapt your system?

Increase the confidence threshold for those suggestion types.

Remove those suggestion types entirely from the system.

Analyze why suggestions are ignored (false positives, poor timing, unclear value) and adapt the system accordingly.

Add more aggressive notifications to ensure developers see the suggestions.
Correct Answer!
Understanding why is crucial: false positives, poor UX, unclear value, wrong timing - each needs different solutions.