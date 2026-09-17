## Quiz: Fine-Tuning Decision and Strategy

Fine-Tuning Decision and Strategy
Your engineering team is building an AI-powered customer support system that needs to handle 500,000 support tickets per month. The system must answer questions about product features, refund policies, and technical documentation. The team is evaluating different customization approaches: prompting with GPT-4 API, RAG with a knowledge base, parameter-efficient fine-tuning with LoRA, or full fine-tuning of an open-source model. The team has collected 2,000 examples of high-quality support interactions and maintains a knowledge base with 10,000 support articles that update monthly. They need to balance cost, latency, accuracy, and maintenance requirements while ensuring the system can handle the scale and provide consistent, high-quality responses.


The support system needs to answer questions about product features that change monthly. The model understands how to answer questions but lacks access to current product documentation. Which approach is most appropriate?

Fine-tune the model on product documentation to teach it the information

Use RAG to retrieve current product documentation and provide it as context

Use prompt engineering with examples from the documentation

Use full fine-tuning to inject all product knowledge into the model
Correct Answer!
RAG solves knowledge gaps by providing external information as context. When information changes frequently, RAG allows updates without retraining.

The team has 200 examples of support interactions and is considering fine-tuning. According to best practices, what should they do first?

Proceed with fine-tuning since they have examples

Exhaust prompt engineering first, then evaluate if fine-tuning is needed

Use RAG since they have a knowledge base

Collect more examples until they reach 10,000 before fine-tuning
Correct Answer!
Always start with the simplest approach. Exhaust prompt engineering first, measure performance, and only escalate to fine-tuning if you hit clear performance ceilings and have sufficient data.

At 500,000 requests per month, which approach is likely most cost-effective?

Prompting with GPT-4 API at $0.027 per request

RAG with GPT-4 API, adding vector database costs

Self-hosted PEFT with LoRA, requiring GPU infrastructure

Full fine-tuning with self-hosted infrastructure
Correct Answer!
At high volume, self-hosted fine-tuning becomes cost-effective. GPU infrastructure ($500/month) plus training amortized ($50/month) = $550/month, much cheaper than API costs.

The team is considering using LLaMA 3 for fine-tuning. Their company has 800 million monthly active users. What licensing consideration applies?

LLaMA Community License allows unrestricted commercial use

They need a separate commercial agreement with Meta or choose an Apache 2.0-licensed model

They can use LLaMA but must open-source their fine-tuned model

Licensing does not apply to fine-tuning
Correct Answer!
Companies with over 700 million monthly active users cannot use LLaMA models commercially without a separate agreement with Meta. They should either negotiate with Meta or choose an Apache 2.0-licensed model like Mistral.

The support system will process personal data from EU residents. What data residency consideration applies?

GDPR explicitly requires all data to remain in the EU

Self-hosted models in EU data centers or providers with EU data residency guarantees simplify compliance

Any cloud provider is acceptable as long as encryption is used

Data residency only applies to training data, not inference
Correct Answer!
While GDPR does not explicitly require EU residency, keeping EU data within EU boundaries simplifies compliance and avoids complex data transfer agreements.