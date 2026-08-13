In-Context Learning and Basic Reasoning
This quiz evaluates your understanding of different prompting strategies including zero-shot, few-shot, chain-of-thought, and self-consistency approaches. You'll need to identify the most appropriate strategy for various real-world scenarios based on resource constraints, accuracy requirements, and task complexity.


Your e-commerce platform needs to generate product descriptions for 50,000 items across diverse categories. The descriptions must highlight features and appeal to target audiences, but you have no budget for maintaining example sets. Response time is critical due to high traffic. Which prompting approach best fits these requirements?

Zero-shot prompting with clear instructions specifying features and target audience

Few-shot prompting with 5-7 examples covering major product categories

Chain-of-thought prompting to reason through feature prioritization

Self-consistency with multiple generation attempts for quality assurance
Correct Answer!
Zero-shot excels for high-volume, well-defined tasks where maintaining examples is impractical and response time matters. The task is straightforward and scales efficiently.

You are building a customer support ticket classifier that must distinguish between "Technical Issue," "Billing Question," "Feature Request," and "Account Management." Initial zero-shot attempts work well for obvious cases but struggle with ambiguous tickets like "I can't access my premium features after payment." What should you do first?

Switch to chain-of-thought prompting to show reasoning for classifications

Add 3-5 examples demonstrating boundary cases and overlapping categories

Increase temperature to generate more diverse classification attempts

Implement self-consistency by generating multiple classifications and using majority vote
Correct Answer!
Few-shot with strategic edge case examples (like billing-technical overlaps) directly addresses boundary ambiguity and classification confusion.

Your financial risk assessment AI must evaluate investment opportunities by analyzing market conditions, company financials, industry risks, and economic indicators before assigning risk ratings. Stakeholders need to understand how ratings are determined. Which prompting strategy addresses both accuracy and explainability requirements?

Zero-shot prompting with explicit instructions for each evaluation dimension

Few-shot prompting with diverse investment examples showing good and bad risks

Chain-of-thought prompting requiring step-by-step analysis of each factor

Self-consistency without chain-of-thought to reduce response latency
Correct Answer!
Chain-of-thought forces systematic reasoning through each factor, providing both improved accuracy and transparent, auditable reasoning for stakeholders.

You built a code review system using few-shot prompting with three examples: one showing security issues, one showing performance problems, and one showing a well-written function. The system now flags almost every function as having security issues, even simple utility functions with no security implications. What is the most likely problem?

Temperature setting is too low, causing overfitting to security patterns

Examples are too similar and lack diversity in the types of issues demonstrated

The three-example count is below the optimal 5-7 range for complex tasks

Example distribution is skewed toward security focus rather than balanced issue types
Correct Answer!
Skewed distribution (1 security, 1 performance, 1 clean) inadvertently prioritizes security. The model applies security patterns too broadly.

Your medical diagnosis assistant uses chain-of-thought prompting to analyze patient symptoms step by step: checking vital signs, reviewing symptoms, considering differential diagnoses, and recommending tests. Sometimes the reasoning looks thorough but reaches incorrect conclusions based on faulty assumptions made in early steps. How should you improve reliability?

Switch to few-shot prompting with medical case examples instead of reasoning steps

Implement reasoning validation checkpoints after each major step to verify conclusions

Use self-consistency to generate multiple reasoning paths and select by consensus

Reduce the number of reasoning steps to minimize opportunities for logical errors
Correct Answer!
Multiple independent reasoning paths catch errors that appear in single attempts. Consensus identifies consistently correct answers, catching faulty assumptions—critical for high-stakes medical decisions.

You need to build a sentiment analysis system for product reviews. Initial testing with zero-shot prompting shows 75% accuracy, which is acceptable for your use case. However, the system struggles specifically with sarcastic reviews and mixed sentiment (e.g., "Great product, terrible customer service"). What is the most efficient improvement approach?

Maintain zero-shot approach but add explicit instructions about handling sarcasm and mixed sentiment

Switch to chain-of-thought prompting to reason through sentiment indicators

Add 4-5 few-shot examples focusing specifically on sarcastic and mixed sentiment cases

Implement self-consistency with 5 attempts to improve accuracy on difficult cases
Correct Answer!
With 75% accuracy but specific weaknesses, few-shot targeting exact gaps (sarcasm, mixed sentiment) efficiently improves performance with just 4-5 examples.

SkillUp | Hackerrank