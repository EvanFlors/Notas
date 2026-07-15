## Chain-of-Thought Prompting
When you asked early GPT models "How many times does the letter 'r' appear in the word 'strawberry'?" they would confidently answer "2" or "1"—completely wrong. This simple counting task exposed a fundamental limitation: these models would jump to conclusions without systematic reasoning. The repeated failures on letter counting in "strawberry" became so notorious that it helped drive the development of reasoning-focused models like OpenAI's o1. Chain-of-thought prompting emerged as the solution, forcing models to spell out their reasoning step by step: "Let me break this down: s-t-r-a-w-b-e-r-r-y... I see 'r' in positions 3, 8, and 9, so that's 3 total." This systematic approach transformed unreliable guessing into reliable reasoning.

In production AI systems, getting the right answer is only half the battle. You also need to understand how the model arrived at that answer, validate its reasoning, and catch errors before they impact users. Chain-of-thought prompting gives you this visibility while dramatically improving performance on complex reasoning tasks. By the end of this lesson, you will understand how to implement basic and advanced chain-of-thought techniques that you can deploy in production systems today.

Why Models Need to Show Their Work
Traditional prompting works like asking simple questions and hoping for good answers. This approach handles basic tasks like writing text or simple classification well, but fails when you need the model to solve complex problems requiring multiple steps of reasoning.

Consider asking a model to calculate the total cost of a cloud infrastructure setup with different pricing tiers, regional variations, and usage patterns. Without chain-of-thought prompting, the model might give you a number, but you have no way to verify its calculations or understand which assumptions it made. With chain-of-thought prompting, the model shows each calculation step, making errors immediately visible and the reasoning process auditable.

The difference becomes critical in production environments where incorrect reasoning can lead to costly mistakes. A financial analysis assistant that miscalculates risk without showing its work is a liability. The same assistant that walks through its reasoning step by step becomes a valuable tool that humans can validate and trust.

Breaking Down Complex Problems Step by Step
Basic chain-of-thought prompting works by explicitly asking the model to think through problems systematically. Instead of jumping to conclusions, you guide the model to identify the problem components, work through each step logically, and build toward a final answer.
Here is a practical example for a customer support AI analyzing a complex billing dispute:

```python
from openai import OpenAI

def analyze_billing_dispute(customer_data, billing_history):
    prompt = f"""
    Analyze this billing dispute step by step:

    Customer: {customer_data['name']}
    Dispute: {customer_data['complaint']}
    Billing History: {billing_history}

    Please work through this systematically:
    1. First, identify what specific charges the customer is disputing
    2. Then, check if those charges appear in their billing history
    3. Next, determine if the charges align with their service usage
    4. Finally, recommend a resolution based on your analysis

    Show your reasoning for each step.
    """

    return call_llm(prompt)

def call_llm(prompt):
    client = OpenAI(
        api_key="API_KEY",
        base_url="BASE_URL",
    )

    try:
        response = client.chat.completions.create(
            model="gpt-5-mini",
            messages=[
                {"role": "system", "content": "You are a customer service analyst specializing in billing disputes."},
                {"role": "user", "content": prompt}
            ]
        )
        return response.choices[0].message.content
    except Exception as e:
        return f"Error calling LLM: {str(e)}"

# Sample input data
customer_data = {
    'name': 'Sarah Johnson',
    'complaint': 'I was charged $89.99 for premium support in March, but I never signed up for this service. I only have the basic plan which should be $29.99/month.'
}

billing_history = [
    {'date': '2024-01-15', 'description': 'Basic Plan', 'amount': 29.99},
    {'date': '2024-02-15', 'description': 'Basic Plan', 'amount': 29.99},
    {'date': '2024-03-15', 'description': 'Basic Plan', 'amount': 29.99},
    {'date': '2024-03-15', 'description': 'Premium Support Add-on', 'amount': 89.99},
    {'date': '2024-03-22', 'description': 'Premium Support Usage - 3 tickets', 'amount': 0.00}
]

# Run the function
result = analyze_billing_dispute(customer_data, billing_history)
print(result)
```

This structured approach transforms a potentially confusing dispute into manageable analysis steps. The model cannot skip ahead to a conclusion without demonstrating its reasoning, making errors easier to catch and decisions easier to explain to customers.

The key is being explicit about the reasoning process you want. Phrases like "think step by step," "work through this systematically," and "show your reasoning" signal to the model that you want transparent thinking rather than immediate answers.

![Step-by-Step Reasoning](https://hrcdn.net/ai-engineering/module-2/light/005-cot_illustration.svg)

Making Intermediate Reasoning Visible
One of the most powerful aspects of chain-of-thought prompting is how it exposes intermediate reasoning steps that would normally remain hidden inside the model. This visibility serves multiple purposes in production systems: error detection, reasoning validation, and knowledge extraction for improving your prompts over time.

When building a code review AI, for example, you want the model to identify potential issues systematically rather than making vague assessments. Here is how chain-of-thought prompting makes this process transparent:

```python
from openai import OpenAI

def review_code_systematically(code_snippet):
  prompt = f"""
  Review this code step by step:

  {code_snippet}

  Analysis process:
  1. Security: Check for common vulnerabilities (SQL injection, XSS, etc.)
  2. Performance: Identify potential bottlenecks or inefficient patterns
  3. Maintainability: Assess code clarity and adherence to best practices
  4. Testing: Evaluate testability and error handling

  For each category, explain what you found and why it matters.
  Then provide an overall assessment and specific recommendations.
  """

  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
  )

  response = client.chat.completions.create(
      model="gpt-5-mini",
      messages=[{"role": "user", "content": prompt}]
  )

  return response.choices[0].message.content

# Example code snippet with various issues
sample_code = """
def process_user_login(username, password):
  import sqlite3
  conn = sqlite3.connect('users.db')
  cursor = conn.cursor()

  query = f"SELECT * FROM users WHERE username='{username}' AND password='{password}'"
  cursor.execute(query)
  result = cursor.fetchone()

  if result:
      session_data = {'user_id': result[0], 'username': result[1]}
      return session_data
  else:
      return None
"""

# Demonstrate chain-of-thought code review
print("=== CHAIN-OF-THOUGHT CODE REVIEW ===\n")
review_result = review_code_systematically(sample_code)
print(review_result)
```

This approach gives you insight into the model's reasoning process at each stage. If the security analysis misses an obvious SQL injection vulnerability, you can identify that specific gap and improve your prompting strategy. If the performance analysis focuses on micro-optimizations while missing major architectural issues, you can adjust the prompt to emphasize the right priorities.

The intermediate steps also make it easier to automate follow-up actions. If the model identifies security issues in step one, your system can automatically flag the code for additional review before the analysis continues.

Self-Consistency Through Multiple Reasoning Paths
While basic chain-of-thought prompting improves reasoning quality, individual attempts can still contain errors or inconsistencies. Self-consistency addresses this limitation by generating multiple reasoning paths for the same problem and using consensus to identify the most reliable answer.

The technique recognizes a fundamental principle: while any single reasoning attempt might go wrong, correct answers tend to emerge consistently across multiple independent attempts. This is similar to how code reviews work better with multiple reviewers, even when individual reviewers might miss specific issues.

Here is how to implement self-consistency for a financial risk assessment system:

```python
def assess_investment_risk_with_consistency(investment_data, num_attempts=5):
  base_prompt = f"""
  Assess the risk level of this investment opportunity:

  {investment_data}

  Work through your analysis step by step:
  1. Evaluate market conditions and trends
  2. Analyze the company's financial health
  3. Consider industry-specific risks
  4. Factor in economic indicators
  5. Assign a risk rating (Low/Medium/High) with confidence level

  Show your reasoning for each step.
  """

  results = []
  for i in range(num_attempts):
      # Add slight variation to encourage different reasoning paths
      varied_prompt = base_prompt + f"\nConsider this from perspective #{i+1}:"
      result = call_llm(varied_prompt)
      results.append(extract_risk_rating(result))

  # Use majority voting for final decision
  final_rating = most_common(results)
  confidence = calculate_consensus_strength(results)

  return {
      'rating': final_rating,
      'confidence': confidence,
      'individual_analyses': results
  }
```

This approach provides multiple benefits in production environments. First, it gives you confidence indicators based on consensus strength. If all five attempts rate an investment as "High Risk," you can trust that assessment more than if the results are split between "Medium" and "High." Second, it helps identify edge cases where reasoning is genuinely difficult, allowing you to flag these situations for human review.

The trade-off is increased computational cost and latency. Five reasoning attempts take roughly five times longer than a single attempt, so you need to balance accuracy gains against performance requirements. For critical decisions like financial assessments or medical diagnoses, this trade-off often makes sense. For routine tasks like email classification, basic chain-of-thought prompting might be sufficient.

![Self-Consistency Diagram](https://hrcdn.net/ai-engineering/module-2/light/006-self_consistency_illustration.svg)

Common Pitfalls and Solutions
Chain-of-thought prompting can fail in predictable ways that you need to anticipate in production systems. The most common issue is reasoning that looks sophisticated but contains fundamental logical errors. Models can produce elaborate step-by-step analyses that sound convincing but are built on incorrect assumptions or faulty logic.

To address this, implement reasoning validation checkpoints. After each major reasoning step, have the model verify its conclusions against the available data. For numerical calculations, include explicit verification steps where the model double-checks its arithmetic. For logical reasoning, ask the model to consider potential counterarguments or alternative explanations.

Another frequent problem is reasoning that becomes too verbose or loses focus on the original question. Models can get caught up in detailed tangents that do not contribute to solving the actual problem. Combat this by providing clear reasoning templates that keep the model on track and setting explicit length limits for each reasoning step.

Finally, watch for consistency issues where different reasoning steps contradict each other. This often happens when models make assumptions early in the reasoning process and then forget those assumptions later. Address this by having the model explicitly state and track its assumptions throughout the reasoning process.

Summary
Chain-of-thought prompting transforms AI models from opaque answer generators into transparent reasoning partners. By requiring models to show their work step by step, you gain visibility into their decision-making process while significantly improving performance on complex reasoning tasks.

Key concepts to remember
Explicit Reasoning Instructions - Use explicit reasoning instructions like "think step by step" and "show your reasoning"
Structure Complex Problems - Structure complex problems into manageable sequential steps
Visible Reasoning - Make intermediate reasoning visible for validation and error detection
Self-Consistency for Critical Decisions - Implement self-consistency through multiple reasoning paths for critical decisions
Balance Accuracy and Cost - Balance accuracy improvements against increased computational costs
Validation Checkpoints - Include reasoning validation checkpoints to catch logical errors
Clear Reasoning Templates - Provide clear reasoning templates to keep models focused on the core problem