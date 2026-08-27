## Quiz: Understanding LLMs
Understanding LLMs
Your transformer-based system effectively detects bugs and provides contextual understanding. Now developers want more: automated fix suggestions, code refactoring recommendations, and even generated unit tests. You are exploring large language models for these generative capabilities.


Which characteristic makes LLMs most effective for code generation tasks compared to smaller specialized models?

Exposure to massive code repositories during training provides knowledge of programming conventions, patterns, and best practices across diverse contexts.

LLMs generate code faster than template-based approaches.

LLMs use less computational resources than smaller specialized models.

LLMs provide more deterministic and consistent outputs.
Correct Answer!
LLMs saw millions of code examples - learned syntax, conventions, patterns, and best practices across scenarios/languages.

For cost-effective deployment of your code review system, how should you architect LLM usage?

Use LLMs for complex generative tasks (fixes, explanations), smaller models for classification and detection.

Use the largest available LLM for all code analysis tasks to maximize quality.

Avoid LLMs entirely due to computational costs and stick with transformers.

Use LLMs only for offline analysis, not real-time developer tools.
Correct Answer!
Different complexity needs: simple detection doesn't need expensive LLMs; explanations/fixes benefit from LLM power.

What is the most significant risk when using LLMs to generate code suggestions for developers?

Generated code will be too slow to run efficiently.

LLMs might generate insecure, buggy, or inappropriate code that developers trust and integrate.

Code generation will be too expensive for practical deployment.

LLMs won't understand modern programming languages and frameworks.
Correct Answer!
Developers may trust LLM code without thorough review. Security vulnerabilities/bugs could reach production.

When implementing LLM-powered code suggestions, which approach best manages the hallucination risk?

Use only the largest, most capable LLMs to minimize errors.

Generate multiple suggestions and let developers choose the best one.

Implement validation layers (syntax checking, security scanning, testing) before showing suggestions to developers.

Clearly label all suggestions as "AI-generated" and let developers handle validation.
Correct Answer!
Automated validation (syntax, security, testing) filters obviously problematic suggestions before developers see them.

Your LLM generates excellent code explanations but occasionally suggests deprecated APIs or outdated patterns. How should you address this?

Accept this limitation as unavoidable with current LLM technology.

Switch to a different LLM that was trained on more recent data.

Implement retrieval-augmented generation (RAG) with current documentation and best practices.

Fine-tune the LLM on only the most recent code examples.
Correct Answer!
RAG lets LLM access current docs/APIs/best practices during generation, providing up-to-date suggestions despite older training data.