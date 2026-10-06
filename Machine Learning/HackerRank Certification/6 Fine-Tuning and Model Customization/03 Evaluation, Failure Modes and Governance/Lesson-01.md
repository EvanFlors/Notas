## Evaluation and Catastrophic Forgetting

After fine-tuning your customer support chatbot, you need to know: did it actually improve? Many teams skip proper evaluation and deploy models that perform worse than the base model or fail in production. Worse, fine-tuning can cause catastrophic forgetting: your model might excel at customer support but lose its ability to handle general tasks it could do before.

Evaluation is critical for understanding whether fine-tuning actually improved your model. Pre-fine-tuning evaluation establishes baselines so you can measure improvement. Post-fine-tuning evaluation validates that fine-tuning achieved its goals and didn't introduce regressions. Catastrophic forgetting occurs when fine-tuning causes models to lose previously learned general capabilities, making them worse at tasks they handled before fine-tuning.

In this lesson, you will learn to design comprehensive evaluation frameworks for your customer support chatbot, establish baselines, compare pre/post fine-tuning performance, and prevent catastrophic forgetting that could degrade your model's general capabilities.

Pre-Fine-Tuning Evaluation
Establishing baseline performance before fine-tuning enables you to measure improvement and identify specific areas where fine-tuning should focus.

Why Baseline Evaluation Matters

Before fine-tuning your customer support chatbot, evaluate the base model (e.g., Llama-2-7b-chat) on your target tasks. This establishes what the model can do "out of the box" and helps you identify where fine-tuning should focus.

Baseline Metrics for Customer Support Chatbot

For your customer support chatbot, evaluate the base model on key tasks: ticket classification, response generation, and information extraction.

```python
# Pre-Fine-Tuning Baseline Evaluation
# Evaluate base model to establish baseline performance

from transformers import AutoModelForCausalLM, AutoTokenizer
import json
import torch

# Load base model and test dataset
base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-2-7b-chat-hf")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-2-7b-chat-hf")
with open("data/customer_support_test.json", "r") as f:
  test_dataset = json.load(f)

# Evaluate on key tasks
def evaluate_classification(model, tokenizer, test_examples):
  """Evaluate ticket classification accuracy"""
  correct = total = 0
  for example in test_examples:
      if example.get("task") != "classify":
          continue
      prompt = f"Classify this support ticket: {example['input']}"
      inputs = tokenizer(prompt, return_tensors="pt", truncation=True, max_length=512)
      with torch.no_grad():
          outputs = model.generate(**inputs, max_new_tokens=50, do_sample=False)
      prediction = tokenizer.decode(outputs[0], skip_special_tokens=True)
      if example["output"].lower() in prediction.lower():
          correct += 1
      total += 1
  return {"accuracy": correct / total if total > 0 else 0, "correct": correct, "total": total}

# Evaluate and save baseline metrics
classification_baseline = evaluate_classification(base_model, tokenizer, test_dataset)
baseline_metrics = {"classification_accuracy": classification_baseline["accuracy"]}

with open("baseline_metrics.json", "w") as f:
  json.dump(baseline_metrics, f, indent=2)

print(f"Baseline Classification Accuracy: {classification_baseline['accuracy']:.2%}")
```

Identifying Improvement Opportunities

Analyze baseline performance to identify specific areas where fine-tuning should focus. Look for:

Low performance on specific categories: If your chatbot performs poorly on "billing" tickets but well on "shipping" tickets, focus fine-tuning on billing examples.
Systematic errors: Patterns where the model consistently fails (e.g., always misclassifying urgent tickets as non-urgent).
Edge cases: Unusual scenarios where the model fails (e.g., tickets with multiple issues, very long tickets, or tickets with technical jargon).
Use confusion matrices, per-category accuracy metrics, and error analysis to identify these patterns. This helps you prioritize which types of examples to include in your fine-tuning dataset.

Test Set Design

Design test sets that represent production scenarios. For your customer support chatbot, include diverse ticket types, edge cases, and balanced category distribution.

Post-Fine-Tuning Evaluation
Post-fine-tuning evaluation validates that fine-tuning achieved its goals and identifies any regressions or new issues.

Comparing Fine-Tuned Model to Baseline

Evaluate your fine-tuned customer support chatbot using the same metrics as baseline evaluation to enable fair comparison.

```python
# Post-Fine-Tuning Evaluation
# Compare fine-tuned model to baseline

from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import json

# Load fine-tuned model and baseline metrics
base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-2-7b-chat-hf")
fine_tuned_model = PeftModel.from_pretrained(base_model, "./chatbot_lora_adapter")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-2-7b-chat-hf")
with open("baseline_metrics.json", "r") as f:
  baseline_metrics = json.load(f)

# Evaluate fine-tuned model (reuse evaluation function from baseline)
fine_tuned_classification = evaluate_classification(fine_tuned_model, tokenizer, test_dataset)

# Calculate improvements
improvement = fine_tuned_classification["accuracy"] - baseline_metrics["classification_accuracy"]
print(f"Classification: {baseline_metrics['classification_accuracy']:.2%} -> {fine_tuned_classification['accuracy']:.2%} ({improvement:+.2%})")

# Check if improvement meets threshold
meets_threshold = improvement > 0.05
print(f"{'✅' if meets_threshold else '⚠️'} Model {'meets' if meets_threshold else 'does not meet'} improvement threshold")
```

Regression Detection

Detect regressions where fine-tuning degraded performance on important metrics or scenarios. This is critical: sometimes fine-tuning improves one metric but hurts another.

Compare each metric between baseline and fine-tuned models. If a metric decreases by more than 2-5% (depending on your threshold), that's a regression. For example, if classification accuracy improved from 75% to 92% but response quality dropped from 80% to 78%, you have a regression in response quality that needs investigation.

Check regressions at multiple levels:

Metric-level: Overall accuracy, F1 score, response quality
Category-level: Performance on specific ticket categories (shipping, billing, product issues)
Scenario-level: Performance on edge cases or specific customer types
If regressions are detected, investigate the cause. Common causes include: overfitting to specific patterns, imbalanced training data, or training for too many epochs.

Catastrophic Forgetting
Catastrophic forgetting occurs when fine-tuning causes models to lose previously learned general capabilities, making them perform worse on tasks they handled before fine-tuning. Your customer support chatbot might excel at support tasks but lose its ability to handle general conversation or other tasks.

What is Catastrophic Forgetting?

Imagine your base model could handle general questions, code generation, and creative writing. After fine-tuning it for customer support, it might become excellent at support tickets but struggle with general questions it could answer before. This is catastrophic forgetting: the model "forgot" its general capabilities.

Identifying Catastrophic Forgetting

Signs of catastrophic forgetting include:

Fine-tuned model performs worse than base model on general tasks
Model loses capabilities in areas not covered by fine-tuning data
Performance on original tasks degrades significantly
Model becomes overly specialized and loses flexibility

```python
# Detecting Catastrophic Forgetting
# Check if fine-tuning degraded general capabilities

from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import torch

# Load both models
base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-2-7b-chat-hf")
fine_tuned_model = PeftModel.from_pretrained(
  AutoModelForCausalLM.from_pretrained("meta-llama/Llama-2-7b-chat-hf"),
  "./chatbot_lora_adapter"
)
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-2-7b-chat-hf")

# Test on general tasks (not customer support related)
general_tasks = [
  "Explain quantum computing in simple terms.",
  "Write a Python function to reverse a string.",
  "What are the main themes in Shakespeare's Hamlet?"
]

def evaluate_general_capability(model, tokenizer, prompts):
  """Evaluate model on general tasks"""
  scores = []
  for prompt in prompts:
      inputs = tokenizer(prompt, return_tensors="pt", truncation=True, max_length=512)
      with torch.no_grad():
          outputs = model.generate(**inputs, max_new_tokens=100, do_sample=True, temperature=0.7)
      response = tokenizer.decode(outputs[0], skip_special_tokens=True)
      # Simple quality check (in practice, use LLM-as-Judge or human eval)
      scores.append(1.0 if 20 < len(response) < 500 else 0.5)
  return sum(scores) / len(scores) if scores else 0

# Compare general capabilities
base_score = evaluate_general_capability(base_model, tokenizer, general_tasks)
fine_tuned_score = evaluate_general_capability(fine_tuned_model, tokenizer, general_tasks)
degradation = (base_score - fine_tuned_score) / base_score if base_score > 0 else 0

print(f"Base Model: {base_score:.2f}, Fine-Tuned: {fine_tuned_score:.2f}")
if degradation > 0.15:
  print(f"⚠️ Catastrophic forgetting detected ({degradation:.1%} degradation)")
else:
  print(f"✅ General capabilities preserved")
```

Preventing Catastrophic Forgetting

Prevent catastrophic forgetting through several strategies:

Use PEFT (LoRA/QLoRA): PEFT preserves most base model weights, reducing forgetting. This is why we used LoRA for your customer support chatbot.

Include General Examples: Mix general examples (10-20%) with task-specific examples during training. For example, if you have 2000 support tickets, include 200-400 general examples (Q&A, summarization, general conversation) to help the model retain general capabilities.

Lower Learning Rates: Use lower learning rates (e.g., 1e-4 instead of 2e-4) to cause smaller weight updates, preserving general capabilities.

Regularization: Use weight decay (0.01) and dropout to help preserve base model knowledge.

Fewer Epochs: Train for fewer epochs (2-3 instead of 5+) to prevent over-specialization that causes forgetting.

When preparing mixed training data, randomly sample 10-20% general examples and combine them with your task-specific examples. Shuffle the combined dataset to ensure the model sees both types throughout training.

Why PEFT Helps

PEFT (LoRA/QLoRA) is particularly effective at preventing catastrophic forgetting because:

It only trains a small number of adapter parameters (typically less than 1% of model weights)
Base model weights remain frozen, preserving all original knowledge
Adapters can be easily removed, restoring the original model
This is why we used LoRA for your customer support chatbot: it allows task-specific learning while preserving general capabilities.

Evaluation Best Practices
Use Representative Test Sets: Test sets should reflect production scenarios with diverse examples and edge cases. For your customer support chatbot, include various ticket types, urgency levels, and customer tones.

Evaluate Multiple Metrics: Use multiple metrics to get a complete picture. No single metric captures all aspects of performance. For customer support, evaluate classification accuracy, response quality, response time, and customer satisfaction.

Compare Systematically: Always compare fine-tuned models against baselines using the same test sets and metrics. This ensures fair comparison and accurate measurement of improvement.

Monitor General Capabilities: Ensure fine-tuning does not degrade general model capabilities that may be needed. Your chatbot might need to handle general questions occasionally.

Document Evaluation Results: Keep detailed records of evaluation results to track improvements and regressions over time. This helps with debugging and future improvements.

Common Pitfalls
Evaluating on Training Data: Testing on training data gives inflated metrics. Always use held-out test sets that the model has never seen.

Ignoring Regressions: Focusing only on improvements while ignoring regressions leads to models that fail in production. Always check for regressions.

Single Metric Focus: Relying on a single metric misses important aspects of performance. Use multiple metrics for comprehensive evaluation.

No Baseline Comparison: Fine-tuning without baseline comparison makes it impossible to know if improvements are real. Always establish and compare to baselines.

Ignoring Catastrophic Forgetting: Not checking general capabilities leads to discovering forgetting only after deployment. Always evaluate general capabilities.

Summary
Comprehensive evaluation is essential for successful fine-tuning. Pre-fine-tuning evaluation establishes baselines and identifies improvement opportunities. Post-fine-tuning evaluation validates improvements and detects regressions. Catastrophic forgetting occurs when fine-tuning causes models to lose general capabilities. Prevent it with PEFT, lower learning rates, mixed training data, and regular evaluation of general capabilities.

Key concepts to remember
Baseline Evaluation - Establish baseline metrics before fine-tuning to measure improvement
Multiple Metrics - Use task-specific and general metrics for comprehensive evaluation
Regression Detection - Identify where fine-tuning degraded performance
Catastrophic Forgetting - Loss of general capabilities after fine-tuning
Prevention Strategies - Use PEFT, lower learning rates, mixed training data, and monitor general capabilities