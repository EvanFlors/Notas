## Security Considerations for AI Systems

AI systems face unique security challenges beyond traditional software. Models can leak training data, adversarial inputs can fool predictions, and model theft is a real threat.

Data privacy is paramount. Training data often contains sensitive information: user behavior, personal details, or proprietary business data. Models can memorize training examples and potentially leak them through predictions. Differential privacy techniques add noise during training to prevent memorization. Data minimization limits what sensitive data enters training pipelines.

Model security protects intellectual property. Trained models represent significant investment. Model stealing attacks query models repeatedly to recreate them. Defense includes rate limiting, obfuscating predictions, and monitoring for suspicious query patterns. Watermarking embeds signatures in models to prove ownership if theft occurs.

Adversarial attacks craft inputs designed to fool models. Adding imperceptible noise to images can cause misclassification. Adversarial training includes adversarial examples during training, making models more robust. Input validation detects obviously adversarial inputs before they reach models.

Inference endpoint security prevents unauthorized access. API keys, OAuth, or mutual TLS authenticate clients. Rate limiting prevents abuse. Request logging enables detecting attacks. Encryption in transit (HTTPS) protects data. Encryption at rest protects stored models and data.

Model poisoning attacks corrupt training data to backdoor models. An attacker adds carefully crafted examples to training data. The model learns to behave normally except on specific trigger inputs. Defense includes data validation, anomaly detection in training data, and validation that trained models behave correctly.

Dependency vulnerabilities affect AI systems like any software. ML libraries, containers, and infrastructure have security vulnerabilities. Regular security scanning, dependency updates, and vulnerability monitoring reduce exposure. Use automated tools to detect known vulnerabilities in dependencies.

Access control limits who can train, deploy, or query models. Role-based access control (RBAC) assigns permissions based on roles. Data scientists might access training systems but not production serving. Principle of least privilege gives users minimum necessary access.

PII Handling and Data Privacy
Personally Identifiable Information (PII) requires special handling. Regulations mandate protection, and violations have serious consequences.

PII detection identifies sensitive data in datasets. Names, emails, social security numbers, addresses, and phone numbers are obvious PII. Less obvious PII includes IP addresses, device IDs, and behavioral patterns that identify individuals. Automated scanning detects PII in data pipelines before it reaches training or serving.

Data anonymization removes or obscures PII while preserving utility. Hashing emails produces unique identifiers without revealing addresses. Generalization replaces specific values with ranges (age 34 becomes age 30-40). Suppression removes highly identifying attributes entirely. The challenge is balancing privacy and model utility.

Differential privacy provides mathematical privacy guarantees. Adding calibrated noise during training or serving prevents extracting information about specific individuals. Differential privacy is complex to implement correctly but provides strong guarantees. It is increasingly required for sensitive applications.

Data retention policies limit how long PII is stored. GDPR requires retaining data only as long as necessary. Define retention periods for different data types. Automatically delete old data. Retain aggregated, anonymized data longer than raw PII. Document retention policies and enforce them automatically.

Right to deletion (right to be forgotten) requires removing individuals' data on request. This affects both training data and deployed models. For training data, retraining without the individual's data is necessary. For models already deployed, determining the impact and deciding whether to retrain is complex. Document procedures for handling deletion requests.

Data access controls limit who can view PII. Use encryption at rest and in transit. Implement row-level security so analysts only see data they are authorized for. Log all data access for audit purposes. Regularly review access logs for suspicious patterns.

Privacy-preserving machine learning techniques enable learning from sensitive data without seeing it. Federated learning trains models across distributed datasets without centralizing data. Homomorphic encryption enables computation on encrypted data. Secure multiparty computation allows multiple parties to train together without revealing their data. These advanced techniques add complexity but enable use cases otherwise impossible due to privacy constraints.

Compliance Frameworks
Regulatory compliance is mandatory for many AI applications. Understanding requirements and implementing appropriate controls prevents violations and penalties.

GDPR (General Data Protection Regulation) affects any organization processing EU residents' data. Requirements include data minimization, purpose limitation, consent management, and rights to access and deletion. AI systems must document data usage, implement privacy by design, and conduct Data Protection Impact Assessments (DPIAs) for high-risk processing.

CCPA (California Consumer Privacy Act) provides similar protections for California residents. Requirements include disclosure of data collection, opt-out rights, and non-discrimination against users exercising privacy rights. AI systems serving California users must comply.

HIPAA (Health Insurance Portability and Accountability Act) governs healthcare data in the US. Protected Health Information (PHI) has strict access, storage, and transmission requirements. AI systems handling PHI need encryption, access controls, audit logging, and Business Associate Agreements (BAAs) with vendors.

SOC 2 compliance demonstrates security and availability controls. Organizations prove they protect customer data through documented policies, procedures, and controls. AI platforms require SOC 2 Type II certification to sell to enterprises. Regular audits verify ongoing compliance.

Model bias and fairness regulations are emerging. Some jurisdictions require fairness testing, bias audits, or impact assessments before deploying AI in sensitive domains (hiring, lending, criminal justice). Document how models were tested for bias. Monitor deployed models for disparate impact. Have procedures for addressing discovered biases.

Explainability requirements exist in some domains. GDPR grants rights to explanation of automated decisions. Some US states require loan denial explanations. AI systems need to provide explanations when required. This might mean using interpretable models, building explanation layers, or documenting decision factors.

Industry-specific regulations add requirements. Financial services have anti-money laundering and know-your-customer requirements. Healthcare has medical device regulations. Automotive has safety standards. Understand regulations affecting your industry and domain.

Compliance documentation proves controls exist and function. Maintain policies, procedures, training records, audit logs, and evidence of controls. Regular reviews ensure documentation stays current. External auditors will request this documentation during compliance assessments.

Summary
Security for AI systems requires protecting data privacy, defending against adversarial attacks, securing models from theft, and controlling access. PII handling demands detection, anonymization, retention policies, and support for deletion rights. Privacy-preserving techniques enable learning from sensitive data.

Compliance frameworks like GDPR, HIPAA, and SOC 2 mandate specific controls and documentation. Organizations must understand applicable regulations, implement required controls, and maintain compliance documentation. Emerging regulations around model fairness and explainability add requirements for bias testing and providing explanations.

Key concepts to remember
Unique Security Threats - AI systems face adversarial attacks, model theft, and training data leakage requiring specialized defenses
Privacy Protection - PII detection and anonymization are essential; differential privacy provides mathematical guarantees for sensitive applications
Regulatory Compliance - GDPR and similar regulations require data minimization, consent management, and support for access and deletion rights
Control Frameworks - SOC 2 and HIPAA mandate documented security controls, audit logs, and regular assessments
Fairness Requirements - Model bias regulations are emerging; testing for fairness and monitoring for disparate impact will become standard