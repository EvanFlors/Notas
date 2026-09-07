## Prompting vs RAG vs Fine-Tuning

Imagine deploying a customer support chatbot that needs to answer questions about your product features, classify support tickets, and generate responses in your company's specific tone. Your team faces a critical decision: should you use prompt engineering, RAG, or fine-tuning? Many teams assume fine-tuning is the most powerful solution and proceed directly to model training, only to discover they have over-engineered their system, wasted computational resources, and created unnecessary maintenance complexity.

Understanding the full customization spectrum, from simple prompting to full fine-tuning, is essential for making cost-effective, maintainable decisions that align with business objectives. Each approach serves different purposes: prompting leverages existing capabilities, RAG adds knowledge without changing behavior, and fine-tuning modifies how models think and respond.

In this lesson, you will learn the four levels of AI customization, understand when each approach is appropriate through practical examples, and develop a decision framework that guides selection of the right technique for specific use cases.

The Four Levels of AI Customization
The AI customization spectrum consists of four distinct levels, each building on the previous one with increasing complexity and capability. Understanding this spectrum enables developers to start with the simplest approach and escalate only when necessary.

Level 1: Prompt Engineering
Prompt engineering is the foundation of all AI customization. At this level, model behavior is guided through carefully crafted instructions, examples, and formatting requirements. This includes zero-shot prompting (no examples), few-shot prompting (providing examples), and advanced techniques like chain-of-thought reasoning.

Prompt engineering is effective when the task aligns with the model's pre-existing capabilities. The model already understands classification, extraction, and generation tasks from its training; the prompt provides clear instructions and examples to guide its behavior.

Example: Customer Support Ticket Classification
Consider building a system to classify customer support tickets into categories. The following prompt structure demonstrates how to achieve this with prompt engineering:

```python
# Prompt Engineering Example: Ticket Classification
# This demonstrates how to structure a prompt with task description,
# examples, and the concrete task to classify

def classify_ticket(user_ticket: str) -> str:
  """Classify support tickets using prompt engineering"""

  # Task Description: Define the categories and their meanings
  # Examples: Provide few-shot examples showing the pattern
  # Concrete Task: The actual ticket to classify
  prompt = """
    Classify the following customer support ticket into one of these categories:
    - billing: Payment, subscription, refund issues
    - technical: Bug reports, feature not working
    - feature_request: Requests for new functionality
    - complaint: Negative feedback about service

    Examples:
    Ticket: "My payment was charged twice this month"
    Category: billing

    Ticket: "The login button doesn't work on mobile"
    Category: technical

    Ticket: "I wish you had dark mode"
    Category: feature_request

    Ticket: "Your customer service is terrible"
    Category: complaint

    Now classify this ticket:
    Ticket: "{ticket}"
    Category:
  """.format(ticket=user_ticket)

  # The model uses its pre-existing understanding of classification
  # combined with the examples to make the prediction
  return model.generate(prompt)

# Key insight: No training required - the model already understands
# classification tasks. The prompt just guides it with examples.
```

When Prompt Engineering Works:

Task aligns with model's existing capabilities
Acceptable performance achieved with examples and clear instructions
Rapid iteration and deployment are priorities
No specific style or behavioral requirements
Advantages:

No training time or infrastructure setup
Instant deployment and updates
Low cost and complexity
Easy to test and iterate
Limitations:

Cannot teach new behaviors or styles
Limited by model's pre-existing knowledge
May not handle domain-specific requirements
Level 2: Retrieval-Augmented Generation (RAG)
RAG adds an external knowledge layer to an AI system without modifying the model itself. Instead of relying solely on the model's training data, RAG retrieves relevant information from external documents, databases, or knowledge bases and provides it as context to the model.

RAG solves a specific problem: knowledge gaps. When a model needs access to information that was not in its training data, such as company-specific policies, recent product documentation, or proprietary databases, RAG bridges that gap. The model remains unchanged, but it receives additional context that enables accurate, up-to-date responses.

Example: Product Documentation Q&A
Consider a support chatbot that needs to answer questions about product features that change weekly. The following demonstrates a RAG workflow:

```python
# RAG Workflow Example: Product Documentation Q&A
# This demonstrates how RAG augments knowledge without modifying the model

def answer_question_with_rag(user_question: str, vector_db, model):
  """Answer questions using RAG to retrieve current documentation"""

  # Step 1: Retrieve relevant documents from vector database
  # The vector DB searches for documents semantically similar to the question
  relevant_docs = vector_db.search(user_question, top_k=3)

  # Step 2: Build context from retrieved documents
  # This creates a knowledge base that the model can reference
  context = "\n\n".join([doc.content for doc in relevant_docs])

  # Step 3: Provide context to the model in the prompt
  # The model uses this external knowledge to answer accurately
  prompt = f"""
  Use the following product documentation to answer the question.

  Documentation:
  {context}

  Question: {user_question}

  Answer:
  """

  return model.generate(prompt)

# Key insight: RAG solves knowledge gaps, not capability gaps.
# The model remains unchanged - it just receives additional context
# that enables it to answer questions about information not in its training data.
```

When RAG Works:

Primary challenge is knowledge gaps, not capability gaps
Information changes frequently (documentation, policies, pricing)
Need to cite sources or provide traceability
Model understands the task but lacks specific information
Advantages:

Updates knowledge without retraining
Provides source citations
Handles frequently changing information
Lower cost than fine-tuning
Limitations:

Does not change model behavior or style
Adds latency (100-500ms for retrieval)
Requires vector database infrastructure
Quality depends on retrieval accuracy
Level 3: Parameter-Efficient Fine-Tuning (PEFT)
Parameter-efficient fine-tuning modifies a small subset of model parameters to adapt behavior while keeping most of the model unchanged. Techniques like LoRA (Low-Rank Adaptation) and adapters add trainable parameters that learn task-specific patterns without updating the billions of parameters in the base model.

PEFT is ideal when behavioral changes are needed that prompting cannot achieve, but the full capacity of complete fine-tuning is not required. For example, a model might need to adopt a company's specific writing style, follow proprietary formatting requirements, or perform a classification task with domain-specific categories that the base model does not understand.

Example: Custom Support Response Style
Consider training a model to generate support responses that match your team's specific style and protocols:

```python
# PEFT with LoRA Example: Custom Support Response Style
# This demonstrates parameter-efficient fine-tuning that modifies
# only a small subset of model parameters to adapt behavior

from peft import LoraConfig, get_peft_model
from transformers import AutoModelForCausalLM, TrainingArguments, Trainer

# Configure LoRA (Low-Rank Adaptation) to modify only attention layers
# LoRA adds trainable parameters without updating all model weights
lora_config = LoraConfig(
  r=16,  # Low-rank dimension - controls adapter capacity
  lora_alpha=32,  # Scaling factor for adapter weights
  target_modules=["q_proj", "v_proj"],  # Only modify query/value projections
  lora_dropout=0.1,  # Regularization to prevent overfitting
)

# Load the base model (unchanged)
base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-2-7b-chat-hf")

# Apply LoRA adapter to base model
# This creates a new model with trainable adapter layers
model = get_peft_model(base_model, lora_config)

# Training configuration
# PEFT requires much less GPU memory than full fine-tuning
training_args = TrainingArguments(
  output_dir="./results",
  num_train_epochs=3,
  per_device_train_batch_size=4,
  gradient_accumulation_steps=4,
  learning_rate=2e-4,
)

# Train on support ticket examples
# The adapter learns task-specific patterns from your data
trainer = Trainer(
  model=model,
  args=training_args,
  train_dataset=support_ticket_dataset,  # Examples of desired behavior
)

trainer.train()

# After training, the model learns behavioral changes:
# - To start responses with empathy statements (style change)
# - To follow your specific troubleshooting format (format change)
# - To use your team's preferred phrases and tone (behavioral change)

# Key insight: PEFT modifies behavior and style, not just knowledge.
# Unlike RAG, this changes how the model generates responses.
```

When PEFT Works:

Need behavioral or stylistic changes that prompting cannot achieve
Have moderate amounts of task-specific data (hundreds to thousands of examples)
Want to maintain ability to switch between multiple task-specific adapters
Need more than prompting but less than full fine-tuning
Advantages:

10-100x less GPU memory and training time than full fine-tuning
Can train multiple adapters for different tasks
Maintains most of base model's general capabilities
Relatively quick to train and test
Limitations:

Has capacity limits for deep behavioral changes
May plateau before achieving desired performance
Still requires training infrastructure and data preparation
Less flexible than prompting for rapid changes
Level 4: Full Fine-Tuning
Full fine-tuning updates all model parameters, providing maximum capacity to modify behavior, inject knowledge, and adapt to specific domains. This approach is necessary when PEFT reaches its limits, when continued pre-training on domain-specific data is required, or when deep architectural changes are needed.

Full fine-tuning is appropriate for scenarios like training a model on a proprietary codebase to improve code completion, adapting a model to a specialized medical domain with extensive domain-specific terminology, or creating a model that must follow complex, multi-step workflows specific to business processes.

When Full Fine-Tuning Is Necessary:

PEFT has plateaued and better performance is still needed
Need to inject substantial domain knowledge through continued pre-training
Require deep behavioral changes that affect model's fundamental reasoning patterns
Have large amounts of high-quality domain-specific data (tens of thousands of examples)
Trade-offs:

Resource Requirements: Substantial GPU memory (often 80GB+ for 7B models), longer training times, complex infrastructure
Flexibility: Lose ability to switch between adapters; each fine-tuned model is a separate artifact
Maintenance: Requires retraining as requirements evolve, versioning complexity
Cost: High upfront investment in compute and expertise

Decision Framework: When to Use Each Approach
Understanding when to use each level requires analyzing specific requirements across multiple dimensions: task complexity, data availability, knowledge requirements, and resource constraints. The decision framework below provides a systematic approach to navigate these choices.

Decision tree flowchart showing when to use prompting, RAG, PEFT, or full fine-tuning based on task understanding, knowledge gaps, behavioral needs, and resource availability

![Decision framework for choosing the right customization approach](https://hrcdn.net/ai-engineering/module-6/light/customization-decision-tree.svg)

Navigating the Decision Tree
The decision tree above guides you through a series of questions to identify the appropriate customization level. Follow these steps systematically:

Step 1: Assess Task Understanding

Start by asking: Does the base model understand your task? If the model already understands the task type (classification, extraction, generation, etc.) and acceptable performance can be achieved with examples and clear instructions, start with prompt engineering. Only escalate if you encounter clear performance ceilings that cannot be resolved through better prompting.

Step 2: Identify the Core Challenge

This is the critical distinction that determines your path. Ask yourself: Is your primary challenge knowledge or capability?

Knowledge Gap: If the model lacks access to specific information, such as recent data, proprietary knowledge, or frequently updated content, RAG is likely the solution. The model understands the task but needs additional context.

Capability Gap: If the model does not understand how to perform the task or does not exhibit the required behaviors, consider fine-tuning. The model needs to learn new patterns, styles, or behaviors.

Practical Test: If you could solve your problem by providing the model with a document containing the right information, RAG will work. If the model needs to learn new patterns, styles, or behaviors, fine-tuning is necessary.

Step 3: Evaluate Behavioral Requirements

If you identified a capability gap, ask: Can goals be achieved with behavioral changes? If the model needs to adopt specific styles, follow particular formats, or exhibit behaviors not present in the base model, and you have hundreds to thousands of examples available, PEFT is a good starting point. Train a LoRA adapter, evaluate performance, and escalate to full fine-tuning only if PEFT plateaus.

Step 4: Assess Resources

Before committing to full fine-tuning, verify: Do you have sufficient data and resources? Full fine-tuning requires substantial data (tens of thousands of examples for meaningful improvement), significant GPU resources, and expertise in training workflows. If these resources are not available, reconsider whether PEFT or even enhanced prompting might achieve the goals.

Cost, Latency, and Volume Considerations
Understanding the cost and latency trade-offs helps you make informed decisions. The table below provides a practical comparison across approaches.

| Approach | Upfront Cost | Per-Request Cost | Latency | Break-Even Volume | Best For |
|----------|---------------|------------------|---------|-------------------|----------|
| Prompting | $0 | ~$0.027/request (varies by model) | 2-5 seconds | Always cheapest at low volume | Low to medium volume (<1M requests/month), rapid iteration |
| RAG | $200-500/month (vector DB) | ~$0.027/request + infrastructure (varies by model) | 2.5-5.5 seconds | Similar to prompting | Knowledge gaps, frequently changing information |
| PEFT (Self-Hosted) | $500-800/month (GPU infrastructure) | ~$0 (negligible at scale) | 2-4 seconds (can be lower with shorter prompts) | 50K-100K requests/month | High volume, behavioral adaptation needed |
| Full Fine-Tuning (Self-Hosted) | $500-10K/month (GPU infrastructure) | ~$0 (negligible at scale) | 2-4 seconds | 50K-100K requests/month | Maximum customization, when PEFT plateaus |

Cost Estimation Assumptions:

API-Based (Prompting/RAG): Estimates assume GPT-4 pricing ($0.03/1K input, $0.06/1K output tokens) with 500 input + 200 output tokens per request. Other models (GPT-4o-mini, GPT-5) have different pricing. Verify current rates.

Self-Hosted (PEFT/Full Fine-Tuning): Estimates assume 7B open-source models (LLaMA 3 8B, Mistral 7B) on single GPU infrastructure (A10G, ~$500-800/month). Real deployments often need multiple GPUs and redundancy, increasing costs 2-3x. Note: 7B models are not directly comparable to GPT-4 in quality or capabilities.

Important: Pricing changes frequently. Always verify current costs from provider documentation before making decisions.

Key Insights:

Prompting and RAG scale linearly with usage, making them cost-effective for low to medium volume but expensive at scale.
Self-hosted fine-tuning (PEFT or full) has fixed infrastructure costs but negligible per-request costs, making them cost-effective at high volume (typically 50K-100K+ requests/month).
Latency is similar across approaches (2-5 seconds), though fine-tuned models can reduce latency by requiring fewer prompt examples.
Break-even point depends on your specific costs, but typically occurs around 50K-100K requests per month when comparing API-based approaches to self-hosted fine-tuning.
The Ladder of Customization Principle

The ladder of customization is a principle that guides decision-making: always start at the simplest level that meets requirements, and escalate only when there is evidence that the current level is insufficient. This approach minimizes cost, complexity, and maintenance burden while ensuring solutions are not over-engineered.

Ladder diagram showing escalation from prompt engineering to RAG to PEFT to full fine-tuning, with cost and complexity increasing at each level

![The ladder of customization: escalate only when necessary](https://hrcdn.net/ai-engineering/module-6/light/customization-ladder.svg)

Step-by-Step Escalation Example
Consider building an email classification system for your company. The ladder approach guides you through systematic escalation:

Step 1: Try Prompting First

Write a prompt with examples of each email category and test it on 50 emails. Achieve 85% accuracy. For many use cases, this is sufficient. Deploy a working solution in hours instead of weeks. Most problems stop here.

Step 2: Evaluate If RAG Helps

Notice the model struggles with emails that reference internal project names or company-specific terminology. This is a knowledge gap, not a capability gap. Add RAG to retrieve relevant company documents when classifying emails. Accuracy improves to 90%. RAG solved the knowledge problem without any model training. Many problems are solved at this level.

Step 3: Escalate to PEFT If Needed

If you still need better performance, and the issue is that the model does not understand your specific email categories or formatting requirements, try PEFT. Collect 500 examples of correctly classified emails, train a LoRA adapter in a few hours, and achieve 94% accuracy. PEFT gave you the behavioral adaptation you needed without the full cost of complete fine-tuning.

Step 4: Full Fine-Tuning as Last Resort

Only if PEFT plateaus and you still need better performance should you consider full fine-tuning. By this point, you have validated that simpler approaches do not work, you understand your requirements clearly, and you have the data and infrastructure to support full fine-tuning.

This ladder approach saves time and money. Most problems are solved at levels 1 or 2. Only a small fraction require fine-tuning.

Understanding What Each Approach Changes
A critical distinction in the customization spectrum is understanding what each approach does and does not change.

RAG: Knowledge Augmentation, Not Behavioral Change
RAG augments the model's knowledge by providing external context, but it does not modify the model's behavior, style, or fundamental capabilities.

Example: Legal Document Assistant
Consider a RAG system built for a legal document assistant. The system has a vector database of the firm's contracts, case law, and regulatory documents.

Scenario:

Query: "What does our standard employment contract say about non-compete clauses?"

RAG Response: RAG retrieves the relevant contract sections and provides them as context. The model can now answer accurately about the specific contracts.

❌ Limitation: The model still responds in its default style: it might be conversational, informal, or use technical language in ways the firm does not prefer. If the model needs to format responses as legal briefs with specific citation formats and formal language, RAG alone will not achieve that.

Key Insight: RAG solves knowledge gaps; it does not solve behavioral or stylistic requirements.

Fine-Tuning: Behavioral and Stylistic Modification
Fine-tuning, whether PEFT or full, modifies the model's behavior, style, and capabilities. Unlike RAG, which only provides additional context, fine-tuning changes how the model processes information, generates responses, and makes decisions.

Example: Customer Support Agent Training
Consider fine-tuning a model on customer support interactions. The training data includes examples such as:

```
Customer: "The app crashed when I tried to upload a photo"
Agent: "I understand how frustrating this must be. Let me help you troubleshoot this step by step. First, can you tell me what device you're using?"
```

After Fine-Tuning, the Model Learns:

To recognize this as a technical issue
To start with an empathetic statement
To use the team's specific troubleshooting approach
To follow the question format
Key Insight: The model does not just have access to support documentation (RAG); it has learned to behave like a support agent.

This behavioral modification is powerful but comes with trade-offs:

Fine-tuned models can lose general capabilities if not trained carefully
They require ongoing maintenance as requirements evolve
They create versioning complexity: each fine-tuned model is a separate artifact

Common Pitfalls
Jumping to Fine-Tuning Prematurely: Many teams assume fine-tuning is the most powerful solution and skip simpler approaches. Always start with prompt engineering and escalate only when necessary. Most problems do not require fine-tuning.

Using RAG When Fine-Tuning Is Needed: If the challenge is behavioral or stylistic rather than knowledge-based, RAG will not solve it. Distinguish between knowledge gaps (RAG) and behavioral requirements (fine-tuning). If the model needs to learn new patterns or styles, fine-tuning is necessary.

Ignoring RAG When Knowledge Is the Bottleneck: Teams sometimes try to fine-tune models to learn information that changes frequently or is proprietary. Use RAG for dynamic knowledge that updates regularly. Fine-tuning is for stable behavioral patterns, not frequently changing information.

Underestimating Maintenance Burden: Fine-tuned models require ongoing maintenance: retraining as data evolves, monitoring for performance degradation, and managing model versions. Consider maintenance costs when choosing an approach. If requirements change frequently, simpler approaches like prompting and RAG may be more sustainable.

Summary
Understanding the AI customization spectrum, from prompt engineering through full fine-tuning, enables making cost-effective, maintainable decisions that serve business objectives. The four levels each serve different purposes: prompting for tasks that align with base capabilities, RAG for knowledge augmentation, PEFT for efficient behavioral adaptation, and full fine-tuning for maximum capacity changes.

The ladder of customization principle guides starting simple and escalating only when necessary, minimizing cost and complexity while ensuring solutions are not over-engineered. A structured decision tree helps navigate these choices systematically, asking the right questions to identify the appropriate level for specific use cases.

Key concepts to remember
Four Customization Levels - Prompt engineering, RAG, PEFT, and full fine-tuning each serve different purposes
Start Simple, Escalate When Needed - The ladder of customization minimizes cost and complexity
Knowledge vs Capability - RAG solves knowledge gaps; fine-tuning solves capability gaps
Decision Framework - Systematic questions guide selection of the right approach
Avoid Common Pitfalls - Premature fine-tuning, confusing RAG with fine-tuning, and underestimating maintenance