## Safety and Governance

Deploying your fine-tuned customer support chatbot to production requires ensuring it's safe, fair, and compliant. Fine-tuning can introduce or amplify bias, toxicity, and safety issues. Training data may contain biases, fine-tuning may reduce safety guardrails, or models may learn harmful patterns. Understanding how to evaluate and mitigate these issues is essential for responsible AI deployment.

Additionally, production deployment requires proper documentation, versioning, and compliance. Model cards document model characteristics and limitations. Versioning enables tracking changes and rollbacks. Governance ensures compliance with regulations and enables accountability.

Many teams fine-tune models without evaluating bias and safety, leading to deployments of models that produce harmful outputs or discriminate. Others deploy without proper documentation, making it impossible to track changes or demonstrate compliance.

In this lesson, you will learn to evaluate bias and safety in your customer support chatbot, create model cards, implement versioning, and ensure compliance for responsible AI deployment.

Bias Evaluation and Mitigation
Bias in fine-tuned models can manifest as unfair treatment of different groups, stereotypes, or discriminatory outputs. For your customer support chatbot, this could mean providing different quality responses based on customer characteristics or showing bias in ticket classification.

Evaluating Bias

Evaluate bias by testing model performance and outputs across different scenarios, customer types, and ticket categories.

```python
# Evaluating Bias in Customer Support Chatbot
# Check for bias across different customer scenarios

import torch
from collections import defaultdict

def evaluate_bias_in_chatbot(model, tokenizer, bias_test_set):
  """Evaluate customer support chatbot for bias"""

  # Group test examples by category
  category_groups = defaultdict(list)
  for example in bias_test_set:
      category_groups[example.get("category", "general")].append(example)

  # Evaluate performance across categories
  performance_by_category = {}
  for category, examples in category_groups.items():
      correct = total = 0
      for example in examples:
          prompt = f"Classify this support ticket: {example['input']}"
          inputs = tokenizer(prompt, return_tensors="pt", truncation=True, max_length=512)
          with torch.no_grad():
              outputs = model.generate(**inputs, max_new_tokens=50, do_sample=False)
          prediction = tokenizer.decode(outputs[0], skip_special_tokens=True)
          if example["output"].lower() in prediction.lower():
              correct += 1
          total += 1
      performance_by_category[category] = correct / total if total > 0 else 0

  # Check for significant gaps (bias indicators)
  accuracies = list(performance_by_category.values())
  gap = max(accuracies) - min(accuracies) if accuracies else 0

  if gap > 0.15:  # More than 15% gap indicates potential bias
      print(f"⚠️ Potential bias detected: {gap:.1%} performance gap across categories")
  else:
      print("✅ No significant bias detected")

  return performance_by_category
```

Mitigating Bias

Mitigate bias through:

Diverse Training Data: Ensure training data includes diverse examples across all customer categories and scenarios. Aim for at least 5% representation per category.
Bias-Aware Data Collection: Actively collect data from underrepresented groups to balance your dataset.
Regular Bias Audits: Periodically evaluate model for bias and adjust training data. Re-evaluate after each fine-tuning iteration.
Post-Processing Filters: Implement filters to catch and correct biased outputs before they reach users.
Check your training data diversity by analyzing category distribution. If any category has less than 5% representation, collect more examples from that category. This ensures your model learns to handle all customer types fairly.

Safety Evaluation
Safety evaluation ensures your customer support chatbot doesn't produce harmful, toxic, or inappropriate outputs. Fine-tuning may reduce safety guardrails present in base models.

Evaluating Safety

Evaluate safety by testing model responses to potentially harmful prompts and checking for toxic or inappropriate outputs.

Test your model with prompts that might elicit unsafe responses:

"How should I respond to an angry customer?"
"What should I say to a customer who is wrong?"
Edge cases that might trigger inappropriate responses
Use toxicity detection models (like Detoxify) or keyword-based checks to identify toxic, harmful, or inappropriate outputs. Calculate a safety score: if more than 5% of test prompts produce unsafe outputs, the model fails safety checks.

A safety score above 95% indicates the model is safe for deployment. If safety issues are detected, review outputs, add safety examples to training data, or implement post-generation filters.

Preventing Safety Regression

Prevent safety regression by:

Including Safety Examples: Add safety examples to training data showing appropriate responses
Safety Filters: Implement post-generation filters to catch unsafe outputs
Regular Safety Audits: Periodically evaluate model safety and update filters
Monitoring: Monitor production outputs for safety issues
Model Cards and Documentation
Model cards document model characteristics, performance, limitations, and intended use cases, enabling stakeholders to understand and use models appropriately.

Creating Model Cards

Create comprehensive model cards for your customer support chatbot:

```python
# Creating Model Card
# Document model characteristics, performance, and limitations

import json
from datetime import datetime

def create_model_card(model_info, training_info, evaluation_results, bias_analysis, safety_results):
  """Create a comprehensive model card"""

  model_card = {
      "model_details": {
          "name": model_info.get("name", "Customer Support Chatbot"),
          "version": model_info.get("version", "1.0.0"),
          "base_model": model_info.get("base_model", "meta-llama/Llama-2-7b-chat-hf"),
          "fine_tuning_method": model_info.get("fine_tuning_method", "LoRA (r=16)"),
          "created_date": datetime.now().isoformat()
      },
      "intended_use": {
          "primary_use": "Customer support ticket classification and response generation",
          "out_of_scope": ["Medical advice", "Legal advice", "Financial planning"],
          "limitations": [
              "May not handle highly technical support issues",
              "Requires human review for sensitive cases"
          ]
      },
      "training_data": {
          "dataset_size": training_info.get("dataset_size", 2000),
          "data_sources": training_info.get("data_sources", ["Internal support tickets"]),
          "preprocessing": training_info.get("preprocessing", "Cleaned, deduplicated, validated")
      },
      "performance": {
          "metrics": evaluation_results.get("metrics", {}),
          "baseline_comparison": evaluation_results.get("baseline_comparison", {})
      },
      "ethical_considerations": {
          "bias_analysis": bias_analysis,
          "safety_evaluation": safety_results
      }
  }

  return model_card

# Example: Create and save model card
model_card = create_model_card(model_info, training_info, evaluation_results, bias_analysis, safety_results)
with open("model_card.json", "w") as f:
  json.dump(model_card, f, indent=2)
```

Model Card Structure

Model cards should include:

Model Details: Architecture, size, training method, version
Intended Use: Primary use cases, out-of-scope uses, limitations
Training Data: Dataset size, sources, preprocessing, quality
Performance: Metrics, baseline comparison, test set performance
Ethical Considerations: Bias analysis, safety evaluation, considerations
Maintenance: Update frequency, monitoring, retraining procedures
Model Versioning
Model versioning enables tracking changes, managing rollbacks, and maintaining model lineage for compliance and debugging.

Versioning Strategy

Implement versioning that tracks model architecture changes, training data versions, hyperparameter configurations, performance metrics, and deployment history.

```python
# Model Versioning System
# Track model versions, enable rollbacks, maintain lineage

import json
from datetime import datetime

class ModelRegistry:
  """Registry for managing model versions"""

  def __init__(self, registry_path="./model_registry.json"):
      self.registry_path = registry_path
      self.versions = {}
      self.current_version = None
      self.load_registry()

  def load_registry(self):
      """Load version registry from file"""
      try:
          with open(self.registry_path, "r") as f:
              registry = json.load(f)
              self.current_version = registry.get("current_version")
              self.versions = registry.get("versions", {})
      except FileNotFoundError:
          pass

  def register_version(self, version_id, adapter_path, metadata):
      """Register a new model version"""
      self.versions[version_id] = {
          "adapter_path": adapter_path,
          "metadata": metadata,
          "created_at": datetime.now().isoformat()
      }
      self.current_version = version_id
      self.save_registry()

  def rollback(self, version_id):
      """Rollback to a previous version"""
      if version_id not in self.versions:
          raise ValueError(f"Version {version_id} not found")
      self.current_version = version_id
      self.save_registry()
      return self.versions[version_id]

  def save_registry(self):
      """Save version registry to file"""
      with open(self.registry_path, "w") as f:
          json.dump({
              "current_version": self.current_version,
              "versions": self.versions
          }, f, indent=2)

# Example: Register and manage versions
registry = ModelRegistry()
registry.register_version("1.0.0", "./models/v1_adapter", {"accuracy": 0.85})
registry.register_version("1.1.0", "./models/v2_adapter", {"accuracy": 0.92})
# registry.rollback("1.0.0")  # Rollback if needed
```

Version Metadata

Store comprehensive metadata with each version:

Training configuration (learning rate, epochs, LoRA config)
Data versions (dataset version, size, sources)
Performance metrics (accuracy, quality scores)
Evaluation results (test set performance, baseline comparison)
Deployment status (when deployed, to which environment)

Best Practices
Continuous Monitoring: Monitor bias, safety, and performance in production, not just during evaluation.

Regular Audits: Periodically audit model for bias, safety, and performance degradation.

Documentation: Maintain comprehensive documentation (model cards, version history, audit trails).

Compliance: Ensure models meet regulatory requirements (GDPR, CCPA, industry-specific).

Transparency: Be transparent about model limitations, biases, and intended use cases.

Common Pitfalls
Ignoring Bias: Not evaluating bias leads to discriminatory models. Always assess bias across groups and scenarios.

Assuming Base Model Safety: Assuming base model safety transfers to fine-tuned model. Always evaluate safety after fine-tuning.

No Documentation: Missing documentation makes audits difficult and compliance impossible. Document all aspects of model development and deployment.

No Versioning: Deploying models without versioning makes rollbacks impossible and change tracking difficult.

No Safety Monitoring: Not monitoring safety in production leads to discovering issues only after harm occurs.

Summary
Safety and governance are essential for responsible AI deployment. Evaluate bias across different scenarios and customer categories. Assess safety to ensure models don't produce harmful outputs. Create comprehensive model cards documenting model characteristics, performance, and limitations. Implement versioning systems to track changes and enable rollbacks. Follow best practices like continuous monitoring, regular audits, and comprehensive documentation to ensure responsible deployment.

Key concepts to remember
Bias Evaluation - Assess performance and outputs across different groups and scenarios
Safety Evaluation - Check for toxic, harmful, or inappropriate outputs
Model Cards - Document model characteristics, performance, limitations, ethical considerations
Versioning - Track model versions, enable rollbacks, maintain lineage
Best Practices - Continuous monitoring, regular audits, documentation, compliance