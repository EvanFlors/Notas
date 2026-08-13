Evaluation
This quiz assesses your understanding of evaluation methods including traditional metrics (BLEU, ROUGE, cosine similarity), LLM-as-a-Judge evaluation, designing effective judge prompts, and multi-judge systems. You'll need to identify when different evaluation approaches are appropriate and how to design reliable evaluation systems.


Your content generation system produces technical documentation. Traditional BLEU scores show high performance (0.85), but users complain the documentation does not actually help them solve problems. When would switching to LLM-as-a-Judge evaluation provide the most value?

When you need faster evaluation that can process thousands of documents per minute

When you need to assess semantic qualities like helpfulness and clarity that BLEU cannot capture

When you need exact reproducibility of evaluation scores across different evaluation runs

When you want to reduce evaluation costs by eliminating human reviewers entirely
Correct Answer!
LLM judges evaluate semantic qualities like helpfulness and user value that BLEU cannot capture. BLEU measures n-gram overlap but misses whether content solves user problems.

You built a judge prompt to evaluate customer service responses for "quality." Initial testing shows high variability—the same response receives scores ranging from 2 to 5 across different evaluation runs. What is the most likely root cause and solution?

Temperature setting is too high, causing random variation in judge outputs

Evaluation criteria are vague and lack specific, measurable definitions with calibration examples

The judge model lacks sufficient training data for customer service evaluation

The judge prompt should include few-shot examples of high-quality responses
Correct Answer!
Vague criteria like "quality" cause inconsistent evaluations. Break into specific dimensions (helpfulness, accuracy, tone) with clear rubrics and calibration examples.

Your golden dataset for evaluating a legal document analysis system was created 18 months ago. Recent production logs show the system performs well on dataset examples but users report increasing dissatisfaction. What is the most likely issue?

The golden dataset lacks sufficient diversity in document types and complexity levels

BLEU and ROUGE scores are not appropriate metrics for legal document analysis

Reference data staleness—legal standards and user expectations have evolved since dataset creation

The system needs multi-judge evaluation instead of single golden dataset comparison
Correct Answer!
Standards and expectations evolve over time, making 18-month-old benchmarks outdated. The system meets old standards but not current needs.

Your content moderation system uses a single AI judge to evaluate posts for safety violations. Testing reveals the judge consistently misses subtle harassment patterns involving cultural references while over-flagging legitimate content. How should you improve evaluation reliability?

Implement a multi-judge system with diverse models and specialized safety expertise

Increase the confidence threshold for flagging content to reduce false positives

Add calibration examples showing cultural harassment patterns to the judge prompt

Switch to traditional metrics like keyword matching for more consistent results
Correct Answer!
Diverse models and specialized judges catch patterns individual judges miss while reducing false positives through consensus.

You designed a judge prompt requiring JSON output with specific fields for scores and justifications. In production, 15% of judge responses fail to parse because of minor formatting variations like extra whitespace or slightly different field names. What architectural improvement best solves this?

Use stricter JSON schema validation that rejects any formatting deviations

Add more calibration examples showing exact JSON format requirements

Design output formats with flexibility and implement robust parsing that handles minor variations gracefully

Switch to natural language output instead of structured JSON to avoid parsing issues
Correct Answer!
Robust parsing handles minor variations gracefully, maintaining structured benefits while preventing edge case failures.

Your e-commerce product description generator uses cosine similarity (0.75 threshold) for evaluation. All generated descriptions pass this threshold, but business stakeholders complain descriptions lack persuasive language and do not highlight key selling points. Why is cosine similarity insufficient for this use case?

Cosine similarity measures semantic closeness but cannot assess persuasiveness or business value

Product descriptions require ROUGE metrics instead of cosine similarity for proper evaluation

The similarity threshold of 0.75 is too low and should be raised to 0.90 or higher

The reference descriptions in the golden dataset need to be updated more frequently
Correct Answer!
Cosine similarity measures semantic closeness but cannot assess persuasiveness, emotional appeal, or emphasis on selling points. These require LLM judges.

You built a multi-judge system using three different GPT-5 instances with identical prompts. Judge agreement is high (95%), but all three judges consistently undervalue creative responses that users actually prefer. What is the fundamental architectural flaw?

The judges need specialized prompts focusing on different evaluation dimensions

The consensus mechanism should use weighted voting instead of simple averaging

Human validation is needed to calibrate the judges against user preferences

Correlation without diversity—using similar models creates correlated failures rather than independent assessment
Correct Answer!
Same model instances share biases and blind spots. True multi-judge benefits require diversity in models, training, or perspectives for independent failures.

Your medical advice AI uses both automated BLEU scores (fast, cheap) and LLM judges (slow, expensive) for evaluation. You want to optimize costs while maintaining quality. Which tiered evaluation strategy provides the best balance?

Use LLM judges for all evaluations since quality matters most in medical contexts

Use BLEU scores for all evaluations and rely on user feedback to catch quality issues

Use fast BLEU scores for initial screening, route cases with low scores or high stakes to LLM judges

Alternate between BLEU and LLM judges randomly to get representative sampling
Correct Answer!
Fast metrics screen initially, expensive evaluation for flagged cases. Dramatically reduces costs while maintaining quality where it matters.

SkillUp | Hackerrank