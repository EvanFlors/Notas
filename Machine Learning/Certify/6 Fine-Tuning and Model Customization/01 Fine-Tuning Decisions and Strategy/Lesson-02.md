## Open-Source vs Hosted Models

When selecting a base model for fine-tuning, your first decision is whether to use an open-source model you can self-host or a hosted model from providers like OpenAI or Anthropic. This choice fundamentally shapes your customization strategy, cost structure, compliance posture, and operational model. Many teams default to hosted models for simplicity, only to discover later that self-hosted open-source models offer better control, lower costs at scale, and compliance advantages that are critical for enterprise applications.

The open-source LLM landscape has matured significantly in 2024-2025, with models like LLaMA 3, LLaMA 4, Mistral 7B, and Mixtral 8x7B achieving performance that rivals or exceeds hosted models for many tasks. Meanwhile, hosted providers continue to release advanced models like GPT-5, Gemini 3, and Claude 4, offering managed fine-tuning APIs that simplify the process but limit your control and flexibility. Understanding the trade-offs between these approaches is essential for making informed decisions that serve your business objectives.

In this lesson, you will explore the open-source and hosted model landscapes, understand the control spectrum from full self-hosting to managed APIs, learn to calculate costs accurately, and develop a framework for choosing the right approach based on your requirements.

The Open-Source LLM Landscape
The open-source LLM ecosystem has evolved rapidly, with several model families competing for enterprise adoption. Understanding these models helps you choose the right base for fine-tuning.

LLaMA Family

Meta's LLaMA models have become the de facto standard for open-source fine-tuning. LLaMA 2 (7B, 13B, 70B) established strong performance benchmarks, while LLaMA 3 (8B, 70B) and LLaMA 3.1/3.2 improved instruction following and reasoning capabilities. LLaMA 4 (released April 2025) includes Scout and Maverick models, with Scout focusing on efficiency and Maverick offering advanced reasoning and multimodal capabilities. The LLaMA architecture is well-optimized for fine-tuning, with extensive community support, proven training recipes, and compatibility with popular fine-tuning libraries.

LLaMA models excel at instruction following and chat applications. The 7B variant is popular for cost-effective fine-tuning, while 70B models provide stronger capabilities for complex tasks. However, LLaMA models use Meta's custom license, which restricts commercial use for companies with over 700 million monthly active users, making it unsuitable for some large enterprises.

Mistral Family

Mistral AI's models prioritize efficiency and performance. Mistral 7B uses an optimized architecture with sliding window attention, providing strong capabilities in a smaller model. Mistral 8x7B (Mixtral) uses a mixture-of-experts architecture with sparse activation, achieving 70B-level performance while using only a fraction of the parameters during inference.

Mistral models use Apache 2.0 licensing, making them more permissive than LLaMA for commercial use. They are particularly well-suited for applications requiring efficient inference and strong performance in smaller model sizes. The Mistral architecture is also optimized for fine-tuning, with good support in the PEFT library.

Other Notable Models

Qwen (Alibaba), Phi (Microsoft), Gemma (Google), and Falcon (Technology Innovation Institute) represent additional options in the open-source landscape. Qwen3 (released April 2025) includes both dense and sparse models trained on 36 trillion tokens across 119 languages, supporting reasoning and offering a 128K token context window. Each model family has different strengths: Qwen offers strong multilingual capabilities, Phi focuses on efficiency, Gemma provides Google's research-backed architecture, and Falcon emphasizes open licensing.

When selecting among these models, consider your specific requirements: task complexity, infrastructure constraints, licensing needs, and community support. LLaMA and Mistral currently have the strongest ecosystem support for fine-tuning, but other models may be better fits for specific use cases.

Hosted Model Providers
Hosted model providers offer managed infrastructure and APIs that simplify deployment but limit customization options.

OpenAI

OpenAI provides GPT-4, GPT-4 Turbo, GPT-4o, GPT-4o-mini, and GPT-5 series models through API access. GPT-4o (released May 2024) is a multimodal model optimized for text, image, and audio processing, offering improved performance and lower latency compared to GPT-4. GPT-4o-mini (released July 2024) provides a cost-effective alternative, offering 60% cost savings compared to GPT-3.5 Turbo while maintaining strong performance. GPT-4 Turbo offers enhanced efficiency with a 128K context window.

GPT-5 (released August 2025) represents a significant advancement with improved reasoning capabilities and multimodal processing. GPT-5.2 (released December 2025) is available in three variants: Instant for lightweight tasks, Thinking for complex reasoning, and Pro for high-accuracy professional use. GPT-5.2 features a 400,000-token context window and improved performance on coding and reasoning benchmarks.

OpenAI offers fine-tuning APIs for GPT-3.5 Turbo and GPT-4, but fine-tuning capabilities are limited compared to open-source models. Fine-tuning is not available for GPT-4o, GPT-4o-mini, or GPT-5 series models. OpenAI's models excel at general capabilities but provide less control over the fine-tuning process, limited access to model internals, and ongoing API costs that scale with usage.

OpenAI's fine-tuning API is suitable for teams that want managed infrastructure and do not need deep customization. However, the per-token pricing model makes it expensive at scale, and you cannot self-host or modify the base architecture. Note that OpenAI frequently releases new model versions and updates pricing, so verify current offerings and costs before making decisions.

Anthropic

Anthropic provides Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku, Claude 3.7 Sonnet, and Claude 4 series models through API access. Claude 3.5 Sonnet (released June 2024) offers improved reasoning, coding, and multilingual capabilities compared to earlier versions. Claude 3 Opus provides the strongest reasoning capabilities, while Claude 3 Haiku offers faster, more cost-effective inference.

Claude Sonnet 4 and Claude Opus 4 (released May 2025) represent significant advancements with enhanced reasoning capabilities, code execution tools, and Model Context Protocol connectors. Opus 4 is classified as a "Level 3" model, indicating advanced capabilities that require careful deployment consideration.

Anthropic offers fine-tuning capabilities for some models, but like OpenAI, these are more limited than open-source fine-tuning. Claude models excel at reasoning, safety, and long-context understanding (up to 200K tokens for Claude 3 series, with expanded context windows in Claude 4), but the hosted model approach limits customization depth.

Anthropic's fine-tuning is appropriate for applications requiring strong reasoning capabilities and safety guarantees, but teams needing extensive customization or cost control at scale may find open-source models more suitable. Note that Anthropic regularly updates models and pricing, so verify current offerings before making decisions.

Google

Google provides Gemini 1.5 Pro, Gemini 1.5 Flash, Gemini 2.5 series, and Gemini 3 series models through API access. Gemini 1.5 Pro (released February 2024) features a 1 million token context window and strong multimodal capabilities for text, images, audio, and video. Gemini 1.5 Flash offers faster, more cost-effective inference while maintaining strong performance.

Gemini 3 Pro and Gemini 3 Pro DeepThink (released November 2025) represent significant advancements with improved reasoning, coding capabilities, and a 1 million-token context window. Gemini 3 Flash (released December 2025) provides a cost-effective variant with capabilities similar to the Pro model, focusing on speed and efficiency. The Gemini 3 series has been integrated into Google Search as "AI mode" and demonstrates strong performance on coding and reasoning benchmarks.

Google's fine-tuning capabilities are still evolving, and the ecosystem support is less mature than open-source alternatives. Gemini models excel at multimodal tasks and long-context understanding, but for text-only fine-tuning, open-source models often provide better control and lower costs. Note that Google frequently updates the Gemini model lineup, so verify current offerings and capabilities before making decisions.



Control Spectrum Comparison
The choice between open-source and hosted models represents a fundamental trade-off between control and convenience. Understanding this spectrum helps you choose the right balance for your needs.

| Approach | Control Level | Infrastructure | Fixed Cost | Per-Request Cost | Customization | Best For |
| --- | --- | --- | --- | --- | --- | --- |
| Self-Hosted Open-Source | Full Control | You Manage | $500-10K/month | ~ $0 (negligible at scale) | Full (architecture, hyperparameters, deployment) | High volume (100K+ requests/month), regulated industries, deep customization needs |
| Managed Fine-Tuning APIs | Limited Control | Provider Manages | Medium | ~ $0.001-0.002/request (varies by model and provider) | Partial (limited hyperparameters, no architecture changes) | Medium volume (10K-100K requests/month), teams wanting customization without infrastructure management |
| Hosted Inference (Prompt-Only) | Minimal Control | Provider Manages | $0 | ~ $0.0002-0.002/request (varies by model and provider) | Minimal (prompt engineering only, no fine-tuning) | Low volume (<10K requests/month), prototyping, simple applications |

Cost Estimation Assumptions:

Self-Hosted Open-Source: Estimates assume 7B models (LLaMA 3 8B, Mistral 7B) on single GPU infrastructure (A10G, ~$500-800/month) for 7B models, or A100/H100 (~$3K-10K/month) for 70B models. Real deployments often need multiple GPUs and redundancy, increasing costs 2-3x.

Managed Fine-Tuning APIs: Estimates assume GPT-4o or similar models with typical request sizes. Actual costs vary significantly by model (GPT-4o-mini is much cheaper, GPT-5 series may be more expensive) and provider.

Hosted Inference (Prompt-Only): Estimates assume GPT-4o-mini or similar cost-effective models. GPT-4o-mini costs ~$0.00016/request, while GPT-4o costs ~$0.00145/request. Verify current pricing.

Important: Pricing changes frequently. Always verify current costs from provider documentation before making decisions.

Full Control: Self-Hosted Open-Source

Self-hosting open-source models gives you complete control over the model, infrastructure, and fine-tuning process. You can modify architectures, experiment with different fine-tuning techniques, control data residency, and avoid per-token API costs. This control comes at the cost of infrastructure management, engineering expertise requirements, and operational complexity.

Self-hosting is appropriate when you need data residency guarantees, have high-volume applications where API costs become prohibitive, require deep customization, or operate in regulated industries where control is essential. The infrastructure investment pays off at scale, typically around 50,000-100,000 requests per month depending on your specific costs.

Managed Fine-Tuning: Provider APIs

OpenAI and Anthropic offer managed fine-tuning APIs that handle infrastructure while allowing some customization. These APIs simplify the fine-tuning process but limit your control over training hyperparameters, model architecture, and deployment options. You still pay per-token for inference, making them expensive at scale.

Managed fine-tuning APIs are suitable for teams that want to fine-tune without managing infrastructure but do not need deep customization. They work well for low to medium volume applications where the convenience outweighs the cost and control limitations.

Prompt-Only Customization: Hosted Inference

The simplest approach is using hosted models with prompt engineering only. This provides zero infrastructure management but offers minimal customization. You pay per token, have no control over model updates, and cannot fine-tune at all.

Prompt-only customization works for applications where the base model capabilities are sufficient and you do not need behavioral adaptation. However, for applications requiring specific behaviors, styles, or domain knowledge, this approach is insufficient.

Cost Comparison Framework
Accurate cost comparison requires understanding both upfront and ongoing expenses across the control spectrum. The examples below use consistent assumptions to demonstrate relative cost differences.

Cost Comparison Assumptions (Used Throughout This Section):

Request Size: 500 input tokens + 200 output tokens per request
Monthly Volumes: 10K, 100K, and 1M requests/month for comparison
Self-Hosted Model: 7B open-source model (LLaMA 3 8B or Mistral 7B)
Self-Hosted Infrastructure: Single A10G GPU (~$600/month), high utilization
API Models: GPT-4o-mini for cost-effective option, GPT-4o for premium option
Note: These assumptions are for illustrative comparison only. Real costs vary significantly.
Self-Hosting Costs

Self-hosting requires GPU infrastructure. For a 7B model, you need approximately 16GB GPU memory (A10G or similar), costing $500-800 per month in cloud infrastructure. For 70B models, you need 80GB+ (A100 or H100), costing $3,000-10,000 per month. These are fixed costs regardless of request volume.

Using our assumptions (7B model, single A10G GPU at $600/month), self-hosting costs are:

10K requests/month: $600/month ($0.06 per request)
100K requests/month: $600/month ($0.006 per request)
1M requests/month: $600/month ($0.0006 per request)
The advantage of self-hosting is that per-request costs approach zero at high volume. A single GPU can handle hundreds of requests per minute, making the cost per request negligible compared to API pricing. The break-even point typically occurs around 50,000-100,000 requests per month, depending on model size and infrastructure costs.

API Costs at Scale

Hosted model APIs charge per token, and pricing varies significantly by model and provider. Using our assumptions (GPT-4o-mini: $0.15/1M input, $0.60/1M output; GPT-4o: $2.50/1M input, $10.00/1M output; 500 input + 200 output tokens per request):

GPT-4o-mini costs:

Per request: $0.00016
10K requests/month: $1.60/month
100K requests/month: $16/month
1M requests/month: $160/month
GPT-4o costs:

Per request: $0.00145
10K requests/month: $14.50/month
100K requests/month: $145/month
1M requests/month: $1,450/month
These costs scale linearly with volume, making APIs expensive at scale but cost-effective for low-volume applications. At 100K requests/month, GPT-4o-mini ($16/month) is cheaper than self-hosting ($600/month), but at 1M requests/month, self-hosting ($600/month) becomes more cost-effective than GPT-4o-mini ($160/month) and significantly cheaper than GPT-4o ($1,450/month).

Important Note: API pricing changes frequently as providers release new models and adjust rates. Always verify current pricing from provider documentation before making cost calculations. The examples above use specific assumptions for comparison purposes and may not reflect current pricing.

Hybrid Approaches

Many teams use hybrid approaches: hosted models for development and prototyping, self-hosted models for production at scale. This provides the convenience of APIs during development while optimizing costs for production workloads.

Hybrid approaches also enable gradual migration: start with APIs to validate approaches, then migrate to self-hosted models once you have validated requirements and achieved sufficient volume to justify infrastructure investment.

Capability Benchmarks and When Size Matters
Model size directly impacts capabilities, but larger models are not always better. Understanding when size matters helps you choose cost-effectively.

7B Models: Classification, Extraction, Simple Generation

7B models like LLaMA 3 8B and Mistral 7B excel at classification, entity extraction, and simple generation tasks. They can handle most business applications that do not require complex reasoning or multi-step problem solving. For these tasks, 7B models provide excellent performance at a fraction of the cost of larger models.

Fine-tuning 7B models requires less infrastructure (16GB GPU vs 80GB+ for 70B), making them accessible to more teams. They also have lower latency and can run on more affordable hardware, enabling edge deployment and cost-effective scaling.

13B Models: Reasoning, Complex Instructions, Multi-Step Tasks

13B models provide stronger reasoning capabilities and can handle more complex instructions. They excel at tasks requiring multi-step problem solving, complex analysis, and nuanced understanding. For applications where 7B models plateau, 13B models often provide the necessary capability boost.

The infrastructure requirements for 13B models (32-40GB GPU memory) are still manageable, making them a good middle ground between 7B and 70B models. They provide stronger capabilities than 7B without the infrastructure complexity of 70B models.

70B+ Models: When Smaller Models Plateau

70B+ models are necessary when smaller models reach performance ceilings. For highly complex reasoning tasks, advanced code generation, or applications requiring extensive world knowledge, 70B models provide capabilities that smaller models cannot match.

However, 70B models require substantial infrastructure (80GB+ GPU memory, often multiple GPUs), making them expensive to deploy and fine-tune. Only use 70B models when you have validated that smaller models are insufficient and have the infrastructure budget to support them.

Quantization Impact on Quality

Quantization (4-bit, 8-bit) reduces memory requirements and enables running larger models on smaller hardware. 4-bit quantization can reduce 70B model memory requirements from 140GB to 40GB with minimal quality loss (typically 1-3% performance degradation).

Quantization is essential for making large models accessible, but it does introduce some quality trade-offs. For most applications, 4-bit quantization provides an excellent balance between quality and accessibility. Only use full precision (FP16/BF16) when quantization quality loss is unacceptable for your use case.



Making Informed Model Selection Decisions
Selecting between open-source and hosted models requires analyzing your specific requirements across multiple dimensions.

Volume Analysis

Calculate your expected request volume and compare total costs using consistent assumptions. Based on the cost comparison framework above (7B self-hosted model at $600/month vs GPT-4o-mini at $0.00016/request), the break-even point occurs around 375,000 requests per month ($600 ÷ $0.00016 = 3.75M requests, but accounting for infrastructure overhead, the practical break-even is lower).

For volumes under 50,000 requests per month, hosted APIs (like GPT-4o-mini at $8/month) are typically more cost-effective due to zero infrastructure overhead. For volumes over 100,000 requests per month, self-hosted models ($600/month) become cost-effective compared to premium APIs (GPT-4o at $145/month), though cost-effective APIs (GPT-4o-mini at $16/month) may still be cheaper until very high volumes.

Note: These comparisons use the assumptions from the Cost Comparison Framework section. Your actual break-even point will vary based on your specific model choices, infrastructure costs, and API pricing.

Control Requirements

Evaluate your need for control. Regulated industries, data residency requirements, and applications requiring deep customization benefit from self-hosted models. Applications where convenience and managed infrastructure are priorities may prefer hosted APIs.

Capability Needs

Assess your capability requirements. Start with 7B models and only escalate to larger models if you hit performance ceilings. Many applications achieve excellent results with 7B models, avoiding unnecessary infrastructure complexity.

Team Expertise

Consider your team's expertise. Self-hosting requires ML engineering, infrastructure management, and operational expertise. If your team lacks these capabilities, managed APIs or consulting support may be necessary.

Common Pitfalls
Defaulting to Hosted Models Without Volume Analysis: Many teams choose hosted APIs for simplicity without analyzing expected volume. At high volume (100K+ requests/month), self-hosted models often become more cost-effective despite infrastructure overhead. Always calculate total costs at your expected volume before deciding.

Choosing 70B Models When 7B Would Suffice: Teams sometimes select larger models assuming they will perform better, but 7B models excel at most business applications. Only use 70B models when you have validated that smaller models plateau and have the infrastructure budget. Starting with 7B models saves significant infrastructure costs.

Ignoring Licensing Restrictions: Teams select models based on performance without checking license terms. LLaMA models restrict commercial use for companies with over 700 million monthly active users, which can force expensive migrations. Always verify license compatibility before investing in fine-tuning.

Underestimating Infrastructure Complexity: Self-hosting costs assume efficient infrastructure management, but real deployments often need multiple GPUs, load balancers, monitoring, and redundancy, increasing costs 2-3x. Factor in infrastructure complexity and operational overhead when comparing to hosted APIs.

Assuming API Pricing Is Static: Teams make decisions based on current API pricing without accounting for frequent changes. Providers regularly update pricing and release new models, which can significantly alter cost calculations. Always verify current pricing and build flexibility into your architecture.

Summary
The choice between open-source and hosted models fundamentally shapes your fine-tuning strategy. Open-source models provide control, cost advantages at scale, and compliance benefits, while hosted models offer convenience and managed infrastructure. Understanding the control spectrum, cost structures, and capability trade-offs enables you to make informed decisions that serve your business objectives.

Key concepts to remember
Open-Source Landscape - LLaMA, Mistral, and other models provide strong alternatives to hosted models
Control Spectrum - Self-hosting provides full control; hosted APIs provide convenience
Cost Analysis - Self-hosting becomes cost-effective at 50k-100k requests/month
Size Selection - Start with 7B models; escalate only when smaller models plateau
Quantization - 4-bit quantization enables running larger models with minimal quality loss