## Licensing and Compliance

Selecting a base model for fine-tuning involves more than technical capabilities. Licensing restrictions and compliance requirements can eliminate otherwise suitable models from consideration. Many teams discover these constraints only after investing in fine-tuning, forcing expensive migrations or compliance violations. Understanding these requirements upfront prevents costly mistakes and ensures your fine-tuning project aligns with enterprise governance standards.

Open-source models use different licenses with varying commercial use restrictions. Some models like Mistral use permissive Apache 2.0 licenses, while others like LLaMA use custom licenses that restrict usage for large companies. Meanwhile, compliance frameworks like HIPAA, SOC 2, and GDPR impose additional requirements on how models are deployed and where data is processed.

In this lesson, you will learn practical license selection guidelines, understand essential compliance requirements, and develop a framework for evaluating models against your organization's legal and regulatory needs.

Open-Source License Essentials
Open-source LLM licenses determine what you can and cannot do with models, particularly for commercial use. Understanding these licenses is essential before investing in fine-tuning.

Apache 2.0 License

Apache 2.0 is the most permissive license used by open-source LLMs. Models like Mistral 7B, Mistral 8x7B (Mixtral), and many others use Apache 2.0, which allows unrestricted commercial use, modification, and distribution. You can fine-tune these models, deploy them in production, and use them for any commercial purpose without restrictions.

Apache 2.0 requires attribution and includes a patent grant, making it ideal for enterprise use. There are no usage thresholds, company size restrictions, or special requirements. This makes Apache 2.0-licensed models the safest choice for commercial fine-tuning projects where licensing clarity is important.

LLaMA Community License

Meta's LLaMA models (LLaMA 2, LLaMA 3) use a custom license called the LLaMA Community License. This license allows commercial use but includes restrictions that eliminate it for some large enterprises. Specifically, companies with over 700 million monthly active users cannot use LLaMA models commercially without a separate agreement with Meta.

The LLaMA Community License also requires that derivative works (including fine-tuned models) be distributed under the same license, meaning you cannot create proprietary fine-tuned models from LLaMA. This restriction can be problematic for companies that want to keep their fine-tuned models proprietary.

For most companies, the LLaMA Community License is acceptable, but you must verify that your company size does not exceed the threshold. If you are close to or above 700 million monthly active users, you need a separate commercial agreement with Meta or should choose an Apache 2.0-licensed model instead.

Practical License Selection

When evaluating models, check the license terms carefully. Even if a model appears open-source, commercial use restrictions can eliminate it from consideration. For enterprise deployments, prefer models with clear, permissive licenses like Apache 2.0 to avoid future licensing complications.

If you plan to distribute or sell your fine-tuned models, license compatibility becomes critical. Apache 2.0 allows proprietary derivatives, while the LLaMA Community License requires open-source distribution. Choose licenses that align with your business model for fine-tuned model distribution.

Data Residency and Compliance Essentials
Data residency laws and compliance frameworks impose requirements on where data can be stored and processed, impacting model deployment decisions.

GDPR and EU Data Residency

The General Data Protection Regulation (GDPR) in the European Union imposes strict requirements on data processing. While GDPR does not explicitly mandate data residency, it requires that data transfers outside the EU meet adequacy decisions or use approved transfer mechanisms. In practice, many organizations choose to keep EU data within the EU to simplify compliance.

For fine-tuning, this means that if you process personal data from EU residents, you may need to ensure that both training data and inference occur within EU boundaries. Self-hosted models deployed in EU data centers satisfy this requirement, while hosted models from US providers may require additional compliance measures.

When fine-tuning models for EU use cases, prefer self-hosted deployments in EU data centers or use providers with EU data residency guarantees. This simplifies GDPR compliance and avoids complex data transfer agreements.

Data Localization Laws

Some countries have explicit data localization laws that require certain data to remain within national boundaries. China, Russia, and India have data localization requirements for specific types of data, particularly personal data and financial information.

For fine-tuning projects involving data from these regions, you must deploy models and process training data within the required geographic boundaries. This eliminates hosted models from US providers and requires self-hosted deployments in compliant regions.

Compliance Framework Essentials

Compliance frameworks impose specific requirements on how systems handle data, particularly sensitive data like healthcare records, financial information, or personal data.

HIPAA for Healthcare: Systems that process Protected Health Information (PHI) must implement administrative, physical, and technical safeguards. For fine-tuning with healthcare data, HIPAA compliance requires using HIPAA-compliant cloud providers, implementing encryption, maintaining audit logs, and ensuring that only authorized personnel access PHI. Self-hosted models deployed in HIPAA-compliant environments can satisfy HIPAA requirements, but you must ensure that all infrastructure, processes, and personnel meet HIPAA standards.

SOC 2 for Enterprise SaaS: SOC 2 demonstrates that a provider has implemented appropriate security controls and processes. For fine-tuning, using SOC 2-compliant infrastructure helps satisfy enterprise customer requirements. Most major cloud providers offer SOC 2-compliant services, making it feasible to achieve SOC 2 compliance for self-hosted fine-tuning.

PCI-DSS for Financial Data: Systems that process, store, or transmit credit card data require PCI-DSS compliance. Fine-tuning with financial data that includes credit card information requires PCI-DSS-compliant infrastructure, network segmentation, and encryption. Self-hosted deployments in PCI-DSS-compliant environments can satisfy these requirements.

Making Compliance-Informed Decisions
Selecting models that meet licensing, compliance, and data residency requirements requires systematic evaluation.

License Compatibility Assessment

Evaluate license compatibility with your business model. If you plan to distribute fine-tuned models commercially, ensure the base model license allows this. Prefer Apache 2.0-licensed models for maximum flexibility, or verify that custom licenses meet your needs.

Compliance Framework Mapping

Map your compliance requirements to model deployment options. Identify which frameworks apply (HIPAA, SOC 2, GDPR, PCI-DSS) and verify that your chosen deployment approach satisfies each framework's requirements.

Data Residency Verification

Identify data residency requirements based on data origin, user location, and applicable laws. Ensure that your deployment location (cloud region, on-premise) satisfies residency requirements for all relevant jurisdictions.

Risk Assessment

Assess risks associated with license restrictions, compliance gaps, and data residency violations. Document mitigation strategies and ensure that model selection decisions account for these risks alongside technical and cost considerations.

Common Pitfalls
Selecting Models Without Checking Licenses: Teams often choose models based on performance without verifying license terms, only to discover restrictions after investing in fine-tuning. Always check license compatibility with your business model, especially if you plan to distribute fine-tuned models commercially.

Assuming All Open-Source Licenses Are Equal: Not all open-source licenses are equally permissive. LLaMA's custom license restricts large companies and requires open-source distribution of derivatives, while Apache 2.0 allows unrestricted commercial use. Understand license differences before committing to a model.

Ignoring Data Residency Requirements: Teams deploy models in convenient locations without considering data residency laws. GDPR, data localization laws, and compliance frameworks may require specific deployment locations. Verify residency requirements before selecting deployment infrastructure.

Overlooking Compliance Framework Requirements: Teams assume that using compliant cloud providers automatically satisfies all requirements, but compliance frameworks like HIPAA require end-to-end compliance across infrastructure, processes, and personnel. Ensure your entire deployment stack meets compliance requirements.

Underestimating License Migration Costs: Teams discover license incompatibilities after fine-tuning and must migrate to different models, requiring retraining and infrastructure changes. Evaluate licenses upfront to avoid costly migrations later.

Summary
Licensing, compliance, and data residency requirements fundamentally constrain model selection for enterprise fine-tuning. Open-source licenses vary in permissiveness, with Apache 2.0 being most flexible and custom licenses potentially restricting commercial use. Data residency laws and compliance frameworks impose additional requirements that may mandate specific deployment approaches.

Key concepts to remember
License Types - Apache 2.0 is most permissive; LLaMA Community License restricts large companies
Data Residency - GDPR and localization laws constrain deployment locations
Compliance Frameworks - HIPAA, SOC 2, and PCI-DSS impose specific security and process requirements
Risk Assessment - Evaluate licensing, compliance, and residency risks alongside technical considerations