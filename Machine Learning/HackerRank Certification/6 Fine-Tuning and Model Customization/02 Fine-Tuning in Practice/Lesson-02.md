## Dataset Preparation and Expansion
A well-prepared dataset is the foundation of effective fine-tuning. For your customer support chatbot, you need data that covers classification, response generation, and information extraction tasks. Many teams collect data without clear preparation principles, leading to datasets that are too small, contain quality issues, or lack diversity in critical areas.

You start with 2,000 customer support interactions collected from your ticketing system. Some examples are high quality, but many have issues: duplicates, format inconsistencies, missing fields, and imbalanced categories. You need to clean this data, validate its quality, and expand it to ensure your chatbot handles all production scenarios.

In this hands-on lesson, you will learn practical techniques to clean your customer support dataset, assess data quality, validate readiness for training, and generate synthetic examples to fill coverage gaps.

Why Dataset Quality Matters
Poor quality data directly impacts model performance in production. Models trained on low-quality datasets learn incorrect patterns, fail on edge cases, and require extensive prompt engineering to work correctly. Understanding data quality dimensions helps you identify and fix issues before they become production problems.

Five Dimensions of Data Quality

Data quality assessment requires evaluating multiple dimensions:

Completeness: All required fields are present and non-empty. Missing fields prevent models from learning complete patterns.

Accuracy: Examples demonstrate correct behavior. Incorrect labels or outputs teach models wrong patterns.

Consistency: Format and style are uniform across examples. Inconsistent formatting confuses models during training.

Relevance: Examples are relevant to your target task. Irrelevant examples waste training compute and reduce model focus.

Diversity: Dataset covers the full range of production scenarios. Homogeneous datasets produce models that fail on edge cases.

Real-World Impact of Poor Quality

In production, poor data quality manifests as models that misclassify tickets, generate inappropriate responses, or fail on common scenarios. A dataset with 80% quality might seem acceptable, but it means 20% of training examples teach incorrect behaviors. This translates to models that make mistakes on 20% of production inputs, requiring constant monitoring and manual intervention.

When to Use Quality Assessment

Run quality assessment at three stages: after initial data collection (identify issues early), after cleaning (verify fixes worked), and before training (final validation). Early assessment saves compute by catching issues before expensive training runs.

Dataset Cleaning Fundamentals
Dataset cleaning removes issues that prevent effective learning. The cleaning process involves identifying problems, applying fixes, and verifying improvements.

Common Data Issues

Real-world datasets contain several common issues:

Duplicates: Identical or near-identical examples waste training compute and can cause overfitting. Models memorize duplicate patterns instead of learning generalizable behaviors.

Missing Fields: Examples with missing required fields cannot be used for training. Instruction tuning requires instruction, input, and output fields; missing any field breaks the training pipeline.

Format Inconsistencies: Inconsistent formatting confuses models. If some examples use "Category: X" and others use "X category", the model learns inconsistent patterns.

Outliers: Examples that deviate significantly from the norm can skew training. Extremely long inputs or unusual formats may represent edge cases or data collection errors.

Cleaning Strategy

Start with the most impactful issues first. Duplicates are easy to identify and remove, providing immediate dataset improvement. Missing fields require either fixing (if data is available) or removing examples. Format inconsistencies need standardization across all examples.

Use this code to load and examine your dataset structure. Run this first to understand what data you are working with:

```python
# Step 1: Load and examine dataset structure
# Use this to understand your data format and identify issues

import json
from collections import Counter

def examine_dataset(file_path):
  """Load dataset and examine basic structure"""

  with open(file_path, "r") as f:
      data = json.load(f)

  print(f"Total examples: {len(data)}")

  # Check structure of first example
  if data:
      sample = data[0]
      print(f"\nExample structure:")
      for key, value in sample.items():
          print(f"  {key}: {type(value).__name__} (length: {len(str(value)) if isinstance(value, str) else 'N/A'})")

  # Check for missing required fields
  required_fields = ["instruction", "input", "output"]
  missing_counts = {field: 0 for field in required_fields}

  for example in data:
      for field in required_fields:
          if field not in example or not example[field]:
              missing_counts[field] += 1

  print(f"\nMissing fields:")
  for field, count in missing_counts.items():
      if count > 0:
          print(f"  {field}: {count} examples missing")

  return data

# Examine your dataset
raw_data = examine_dataset("data/customer_support_raw.json")
```

Removing Duplicates

Duplicates waste training compute and can cause overfitting. Use this function to identify and remove duplicate examples. This works for any instruction-tuning dataset where duplicates are defined by identical instruction and input pairs:

```python
# Step 2: Remove duplicate examples
# Use this when you suspect duplicate examples in your dataset
# Duplicates waste training compute and can cause overfitting

def remove_duplicates(dataset, key_fields=None):
  """
  Remove duplicate examples from dataset.

  Args:
      dataset: List of example dictionaries
      key_fields: Fields to use for duplicate detection (default: ["instruction", "input"])

  Returns:
      Tuple of (unique_examples, duplicate_count)
  """
  if key_fields is None:
      key_fields = ["instruction", "input"]

  seen = set()
  unique_examples = []
  duplicate_count = 0

  for example in dataset:
      # Create unique key from specified fields
      key_parts = [str(example.get(field, "")) for field in key_fields]
      content_key = tuple(key_parts)

      if content_key in seen:
          duplicate_count += 1
      else:
          seen.add(content_key)
          unique_examples.append(example)

  print(f"Removed {duplicate_count} duplicates ({duplicate_count/len(dataset)*100:.1f}%)")
  print(f"Dataset size: {len(dataset)} -> {len(unique_examples)}")

  return unique_examples, duplicate_count

# Remove duplicates from your dataset
cleaned_data, dup_count = remove_duplicates(raw_data)
print(f"✅ Cleaned dataset ready with {len(cleaned_data)} unique examples")
```

Data Quality Assessment
Quality assessment evaluates your dataset across multiple dimensions to identify issues before training. This process helps you understand dataset health and prioritize fixes.

Quality Dimensions Explained

Each quality dimension serves a specific purpose:

Completeness ensures models receive complete information. Missing fields create incomplete training examples that confuse models.

Accuracy ensures models learn correct patterns. Incorrect labels teach wrong behaviors that require extensive prompt engineering to override.

Consistency ensures models learn uniform patterns. Inconsistent formats force models to learn multiple ways to express the same concept, reducing efficiency.

Relevance ensures models focus on target tasks. Irrelevant examples dilute learning signal and waste training compute.

When to Use Quality Assessment

Run quality assessment after cleaning to verify fixes worked, and before training to ensure readiness. Use automated assessment for large datasets (1000+ examples) where manual review is impractical. For smaller datasets, combine automated checks with manual sample review.

Use this function to assess dataset quality. Customize the validation functions for your specific task requirements:

```python
# Step 3: Assess data quality across multiple dimensions
# Use this to identify quality issues before training
# Customize validation functions for your specific task

def assess_data_quality(dataset, validation_functions=None):
  """
  Assess dataset quality across multiple dimensions.

  Args:
      dataset: List of example dictionaries
      validation_functions: Dict of custom validation functions
          Format: {"dimension_name": lambda ex: True/False}

  Returns:
      Dictionary with quality scores and issue reports
  """
  if validation_functions is None:
      # Default validations for instruction-tuning datasets
      validation_functions = {
          "completeness": lambda ex: all(
              field in ex and ex[field]
              for field in ["instruction", "input", "output"]
          ),
          "format": lambda ex: len(ex.get("instruction", "")) >= 10,
          "relevance": lambda ex: len(ex.get("input", "")) > 0
      }

  issues = {dimension: [] for dimension in validation_functions.keys()}

  for idx, example in enumerate(dataset):
      for dimension, validate_func in validation_functions.items():
          if not validate_func(example):
              issues[dimension].append(idx)

  # Calculate quality scores
  total = len(dataset)
  quality_scores = {
      dimension: 1 - (len(issue_list) / total)
      for dimension, issue_list in issues.items()
  }

  overall_quality = sum(quality_scores.values()) / len(quality_scores)

  return {
      "quality_scores": quality_scores,
      "overall_quality": overall_quality,
      "issues": issues,
      "total_examples": total
  }

# Example: Assess quality with custom validations for customer support
def is_support_related(example):
  """Check if example is relevant to customer support"""
  input_text = example.get("input", "").lower()
  support_keywords = ["order", "ship", "return", "refund", "product", "account", "payment"]
  return any(keyword in input_text for keyword in support_keywords)

custom_validations = {
  "completeness": lambda ex: all(f in ex and ex[f] for f in ["instruction", "input", "output"]),
  "format": lambda ex: len(ex.get("instruction", "")) >= 10,
  "relevance": is_support_related
}

quality_report = assess_data_quality(cleaned_data, custom_validations)
print(f"Overall quality: {quality_report['overall_quality']:.2%}")
print(f"Quality breakdown:")
for dimension, score in quality_report["quality_scores"].items():
  print(f"  {dimension}: {score:.2%}")

if quality_report["overall_quality"] < 0.90:
  print("\n⚠️ Quality below 90% threshold. Review and fix issues before training.")
```

Diversity and Balance Analysis
Dataset diversity ensures models generalize to unseen inputs. A diverse dataset includes various input lengths, different phrasing styles, edge cases, and representative distribution of task variations.

Why Diversity Matters

Homogeneous datasets produce models that overfit to specific patterns. If all your examples are short, low-urgency shipping issues, your chatbot will fail on complex, high-urgency scenarios. Diversity ensures models learn robust patterns that work across production scenarios.

Balance for Classification Tasks

For classification tasks, imbalanced datasets lead to models favoring majority classes. If 70% of your examples are shipping issues, your model will struggle with billing or technical support. Balance ensures models learn all categories equally.

When to Analyze Diversity

Analyze diversity after cleaning to identify gaps, and before training to ensure coverage. Use diversity analysis to guide synthetic data generation by identifying underrepresented categories or scenarios.

Use this function to analyze dataset diversity. Adapt the category extraction logic for your specific classification schema:

```python
# Step 4: Analyze dataset diversity and balance
# Use this to identify gaps in coverage before generating synthetic data
# Adapt category extraction for your specific classification schema

import numpy as np
from collections import Counter

def analyze_diversity(dataset, extract_categories_func=None):
  """
  Analyze dataset diversity across multiple dimensions.

  Args:
      dataset: List of example dictionaries
      extract_categories_func: Function to extract categories from examples
          Should return list of category strings or None

  Returns:
      Dictionary with diversity metrics and balance analysis
  """
  # Length diversity
  input_lengths = [len(str(ex.get("input", ""))) for ex in dataset]
  length_stats = {
      "mean": float(np.mean(input_lengths)),
      "std": float(np.std(input_lengths)),
      "min": int(np.min(input_lengths)),
      "max": int(np.max(input_lengths)),
      "diversity_score": float(np.std(input_lengths) / np.mean(input_lengths)) if np.mean(input_lengths) > 0 else 0
  }

  # Category balance (if extraction function provided)
  category_balance = None
  is_balanced = True

  if extract_categories_func:
      categories = []
      for ex in dataset:
          cats = extract_categories_func(ex)
          if cats:
              categories.extend(cats if isinstance(cats, list) else [cats])

      if categories:
          category_counts = Counter(categories)
          total = len(categories)
          category_balance = {
              cat: count / total
              for cat, count in category_counts.items()
          }
          # Check for imbalance (any category > 60% or < 5%)
          is_balanced = all(0.05 <= ratio <= 0.60 for ratio in category_balance.values())

  # Task type distribution
  task_types = []
  for ex in dataset:
      instruction = ex.get("instruction", "").lower()
      if "classify" in instruction:
          task_types.append("classification")
      elif "generate" in instruction or "response" in instruction:
          task_types.append("generation")
      elif "extract" in instruction:
          task_types.append("extraction")

  task_distribution = dict(Counter(task_types))

  return {
      "length_diversity": length_stats,
      "category_balance": category_balance,
      "is_balanced": is_balanced,
      "task_distribution": task_distribution
  }

# Example: Extract categories for customer support classification
def extract_support_categories(example):
  """Extract category from customer support example"""
  if "classify" not in example.get("instruction", "").lower():
      return None

  output = example.get("output", "")
  categories = []
  if "Shipping Issue" in output:
      categories.append("Shipping")
  if "Billing Issue" in output:
      categories.append("Billing")
  if "Product Question" in output:
      categories.append("Product")
  if "Return Request" in output:
      categories.append("Return")
  if "Technical Support" in output:
      categories.append("Technical")

  return categories if categories else None

# Analyze diversity
diversity_report = analyze_diversity(cleaned_data, extract_support_categories)
print(f"Length diversity score: {diversity_report['length_diversity']['diversity_score']:.2f}")
print(f"Category balance: {diversity_report['category_balance']}")
print(f"Is balanced: {diversity_report['is_balanced']}")
print(f"Task distribution: {diversity_report['task_distribution']}")

if not diversity_report["is_balanced"]:
  print("\n⚠️ Dataset is imbalanced. Generate synthetic data for minority categories.")
```

Synthetic Data Generation Strategies
After cleaning and analyzing your dataset, you identify gaps: insufficient examples for return requests, limited high-urgency cases, and few examples with complex multi-issue scenarios. Synthetic data generation helps fill these gaps without manual collection.

When to Use Synthetic Data

Use synthetic data when you have identified specific gaps in coverage, need to balance imbalanced categories, or want to expand dataset size without manual collection. Synthetic data is most effective when you have high-quality seed examples and clear generation requirements.

Synthetic Data Trade-offs

Synthetic data provides coverage but introduces risks. Low-quality synthetic examples teach incorrect patterns. Over-reliance on synthetic data (more than 40% of dataset) can degrade performance. Always validate synthetic examples before integration and monitor model performance when using synthetic data.

Generation Strategies

Two main strategies work for different scenarios:

Template-Based Generation: Works well for structured tasks with clear patterns. Use when you can define templates that capture the variation you need.

LLM-Guided Generation: Works well for complex scenarios that are hard to template. Use when you need diverse examples that follow natural patterns but are difficult to template.

Template-Based Generation

Template-based generation uses structured templates to create diverse examples. This approach works well when your task has clear patterns that can be captured in templates. Use this when you need to generate many examples quickly for specific categories or scenarios.

Use this template-based approach when you have clear patterns to replicate. Customize templates and variation lists for your specific task:

```python
# Template-based synthetic data generation
# Use this when you have clear patterns that can be templated
# Works well for structured tasks like classification or format conversion

import random

def generate_from_templates(templates, variation_pools, num_examples_per_template):
  """
  Generate synthetic examples using templates and variation pools.

  Args:
      templates: List of template dicts with "instruction", "input_template", "output_template"
      variation_pools: Dict mapping template variable names to lists of possible values
      num_examples_per_template: Number of examples to generate per template

  Returns:
      List of generated example dictionaries
  """
  synthetic_examples = []

  for template in templates:
      for _ in range(num_examples_per_template):
          # Fill template with random variations
          filled_input = template["input_template"]
          filled_output = template["output_template"]

          # Replace variables in templates with random values
          for var_name, values in variation_pools.items():
              value = random.choice(values)
              filled_input = filled_input.replace(f"{{{var_name}}}", str(value))
              filled_output = filled_output.replace(f"{{{var_name}}}", str(value))

          example = {
              "instruction": template["instruction"],
              "input": filled_input,
              "output": filled_output
          }
          synthetic_examples.append(example)

  return synthetic_examples

# Example: Generate return request examples
return_templates = [
  {
      "instruction": "Classify this support ticket by urgency and category.",
      "input_template": "I want to return {item} from order #{order_num}. {reason}",
      "output_template": "Urgency: {urgency}\nCategory: Return Request"
  }
]

variation_pools = {
  "item": ["a jacket", "shoes", "electronics", "books"],
  "order_num": [f"{random.randint(10000, 99999)}" for _ in range(50)],
  "reason": ["it doesn't fit", "wrong size", "defective item", "changed my mind"],
  "urgency": ["Low", "Medium", "High"]
}

synthetic_examples = generate_from_templates(
  return_templates,
  variation_pools,
  num_examples_per_template=50
)

print(f"Generated {len(synthetic_examples)} synthetic examples")
```

LLM-Guided Generation

LLM-guided generation uses a base LLM to generate diverse examples based on seed examples. This approach works well for complex scenarios where templates are insufficient. Use this when you need natural, diverse examples that are difficult to template.

Use this LLM-guided approach when templates are insufficient. This requires API access and incurs costs, but produces more natural examples:

```python
# LLM-guided synthetic data generation
# Use this when templates are insufficient for complex scenarios
# Requires API access and incurs costs, but produces natural examples

def generate_with_llm(seed_examples, num_examples, task_description, api_client):
  """
  Generate synthetic examples using LLM based on seed examples.

  Args:
      seed_examples: List of example dictionaries to use as seeds
      num_examples: Number of examples to generate
      task_description: Description of the task and requirements
      api_client: Initialized API client (OpenAI, Anthropic, etc.)

  Returns:
      List of generated example dictionaries
  """
  # Format seed examples for prompt
  seed_text = "\n\n".join([
      f"Instruction: {ex['instruction']}\nInput: {ex['input']}\nOutput: {ex['output']}"
      for ex in seed_examples[:5]  # Use first 5 as examples
  ])

  prompt = f"""Task: {task_description}

Generate {num_examples} diverse training examples similar to these seed examples:

{seed_text}

Requirements:
- Examples should be diverse in style, length, and complexity
- Follow the same instruction/input/output format
- Cover different scenarios and edge cases
- Output as JSON array of objects with 'instruction', 'input', 'output' fields
"""

  # Call LLM API (example using OpenAI format)
  response = api_client.chat.completions.create(
      model="gpt-4",
      messages=[{"role": "user", "content": prompt}],
      temperature=0.8,  # Higher temperature for diversity
      response_format={"type": "json_object"}  # Request JSON format
  )

  # Parse response (implementation depends on API)
  generated_text = response.choices[0].message.content
  # Parse JSON and extract examples
  # synthetic_examples = parse_json_response(generated_text)

  return []  # Return parsed examples

# Example usage (requires API setup)
# from openai import OpenAI
# client = OpenAI()
#
# seed_examples = [{"instruction": "...", "input": "...", "output": "..."}]
# synthetic = generate_with_llm(
#     seed_examples=seed_examples,
#     num_examples=100,
#     task_description="Customer support ticket classification",
#     api_client=client
# )
```

Validating Synthetic Data

Synthetic data must meet quality standards to be useful. Validate synthetic examples against the same quality dimensions as real data: format compliance, task relevance, correctness, diversity, and naturalness.

Use this validation function before integrating synthetic data. Customize validation rules for your specific task:

```python
# Validate synthetic data before integration
# Use this to filter out low-quality synthetic examples
# Customize validation rules for your specific task

def validate_synthetic_data(synthetic_examples, existing_dataset, validation_rules=None):
  """
  Validate synthetic examples against quality criteria.

  Args:
      synthetic_examples: List of synthetic example dictionaries
      existing_dataset: List of existing examples to check for duplicates
      validation_rules: Dict of validation functions
          Format: {"rule_name": lambda ex: True/False}

  Returns:
      Dict with validated examples and rejection reasons
  """
  if validation_rules is None:
      # Default validation rules
      validation_rules = {
          "has_required_fields": lambda ex: all(
              f in ex for f in ["instruction", "input", "output"]
          ),
          "not_duplicate": lambda ex: not any(
              ex.get("instruction") == existing.get("instruction") and
              ex.get("input") == existing.get("input")
              for existing in existing_dataset
          ),
          "sufficient_length": lambda ex: len(ex.get("input", "")) >= 20
      }

  validated = []
  rejected = []

  for example in synthetic_examples:
      issues = []
      for rule_name, validate_func in validation_rules.items():
          if not validate_func(example):
              issues.append(rule_name)

      if issues:
          rejected.append({"example": example, "issues": issues})
      else:
          validated.append(example)

  validation_rate = len(validated) / len(synthetic_examples) if synthetic_examples else 0

  return {
      "validated": validated,
      "rejected": rejected,
      "validation_rate": validation_rate
  }

# Validate synthetic examples
validation_result = validate_synthetic_data(
  synthetic_examples=synthetic_examples,
  existing_dataset=cleaned_data
)

print(f"Validation rate: {validation_result['validation_rate']:.2%}")
print(f"Validated: {len(validation_result['validated'])}")
print(f"Rejected: {len(validation_result['rejected'])}")

# Use only validated examples
validated_synthetic = validation_result["validated"]
```

Integrating Synthetic Data

Mix validated synthetic data with real data carefully. Start with a conservative ratio (20-30% synthetic) and monitor performance. Higher ratios can degrade performance if synthetic data quality is lower than real data.

Use this function to create a balanced training set. Adjust the synthetic ratio based on your validation results:

```python
# Integrate synthetic data with real data
# Use this to create final training dataset with controlled synthetic ratio
# Start with 20-30% synthetic and monitor performance

import random

def create_mixed_dataset(real_data, synthetic_data, synthetic_ratio=0.25):
  """
  Create training dataset mixing real and synthetic data.

  Args:
      real_data: List of real example dictionaries
      synthetic_data: List of validated synthetic examples
      synthetic_ratio: Target ratio of synthetic data (0.0 to 1.0)

  Returns:
      Mixed dataset with specified ratio
  """
  # Calculate target sizes
  total_target = len(real_data) / (1 - synthetic_ratio)
  synthetic_target = int(total_target * synthetic_ratio)

  # Use all real data
  mixed_dataset = real_data.copy()

  # Add synthetic data up to target ratio
  synthetic_to_add = min(synthetic_target, len(synthetic_data))
  mixed_dataset.extend(synthetic_data[:synthetic_to_add])

  # Shuffle to mix real and synthetic
  random.shuffle(mixed_dataset)

  return mixed_dataset

# Create final training dataset
final_dataset = create_mixed_dataset(
  real_data=cleaned_data,
  synthetic_data=validated_synthetic,
  synthetic_ratio=0.25  # 25% synthetic, 75% real
)

print(f"Final dataset: {len(final_dataset)} examples")
print(f"  Real: {len(cleaned_data)} ({len(cleaned_data)/len(final_dataset)*100:.1f}%)")
print(f"  Synthetic: {len(final_dataset) - len(cleaned_data)} ({(len(final_dataset) - len(cleaned_data))/len(final_dataset)*100:.1f}%)")
```

Dataset Validation Workflow
Before training, validate that your prepared dataset meets all requirements. A systematic validation workflow ensures readiness and catches issues before expensive training runs.

Validation Principles

Validation checks four critical dimensions:

Size: Dataset meets minimum size requirements for your task complexity. Too few examples lead to underfitting.

Quality: Overall quality score meets threshold (typically 90%+). Low quality teaches incorrect patterns.

Diversity: Dataset is balanced and diverse enough for generalization. Imbalanced or homogeneous datasets produce poor models.

Format: All examples follow expected structure. Format errors break training pipelines.

When to Run Validation

Run validation after each major preparation step: after cleaning (verify fixes), after synthetic data integration (verify quality maintained), and before training (final check). Early validation saves compute by catching issues before training.

Production Considerations

In production, validation becomes part of your data pipeline. Automate validation checks to catch issues in new data before retraining. Set up alerts when quality scores drop below thresholds to prevent training on degraded data.

Use this complete validation workflow before training. This combines all previous checks into a single validation process:

```python
# Complete dataset validation workflow
# Use this before training to ensure dataset readiness
# Combines size, quality, diversity, and format checks

def validate_dataset_for_training(dataset, min_size=2000, quality_threshold=0.90):
  """
  Complete validation workflow before training.

  Args:
      dataset: List of example dictionaries
      min_size: Minimum dataset size for task complexity
      quality_threshold: Minimum quality score (0.0 to 1.0)

  Returns:
      Dict with validation results and readiness status
  """
  results = {
      "size_check": None,
      "quality_check": None,
      "diversity_check": None,
      "format_check": None,
      "ready_for_training": False
  }

  # 1. Size validation
  size = len(dataset)
  results["size_check"] = {
      "size": size,
      "meets_minimum": size >= min_size,
      "passed": size >= min_size
  }

  # 2. Quality validation (reuse previous function)
  quality_report = assess_data_quality(dataset)
  results["quality_check"] = {
      "overall_quality": quality_report["overall_quality"],
      "passed": quality_report["overall_quality"] >= quality_threshold
  }

  # 3. Diversity validation (reuse previous function)
  diversity_report = analyze_diversity(dataset, extract_support_categories)
  results["diversity_check"] = {
      "is_balanced": diversity_report["is_balanced"],
      "length_diversity": diversity_report["length_diversity"]["diversity_score"],
      "passed": diversity_report["is_balanced"] and diversity_report["length_diversity"]["diversity_score"] > 0.3
  }

  # 4. Format validation
  format_errors = sum(
      1 for ex in dataset
      if not all(field in ex for field in ["instruction", "input", "output"])
  )
  results["format_check"] = {
      "format_errors": format_errors,
      "error_rate": format_errors / size if size > 0 else 0,
      "passed": format_errors == 0
  }

  # Overall readiness
  all_passed = all([
      results["size_check"]["passed"],
      results["quality_check"]["passed"],
      results["diversity_check"]["passed"],
      results["format_check"]["passed"]
  ])
  results["ready_for_training"] = all_passed

  return results

# Run complete validation
validation = validate_dataset_for_training(final_dataset)

print("Dataset Validation Results:")
print(f"  Size: {'✅' if validation['size_check']['passed'] else '❌'} "
    f"({validation['size_check']['size']} examples)")
print(f"  Quality: {'✅' if validation['quality_check']['passed'] else '❌'} "
    f"({validation['quality_check']['overall_quality']:.2%})")
print(f"  Diversity: {'✅' if validation['diversity_check']['passed'] else '❌'}")
print(f"  Format: {'✅' if validation['format_check']['passed'] else '❌'}")

if validation["ready_for_training"]:
  print("\n✅ Dataset is ready for fine-tuning!")
else:
  print("\n⚠️ Validation failed. Fix issues before training.")
```

Common Pitfalls
Insufficient Dataset Size: Training with too few examples leads to underfitting. Your customer support chatbot needs at least 2,000 examples for moderate complexity tasks. If you have fewer, generate synthetic data to reach the minimum. In production, monitor model performance to determine if you need more data.

Poor Data Quality: Low-quality examples teach incorrect behaviors. A dataset with 80% quality will produce a poor model. Always assess and fix quality issues before training. In production, set up automated quality checks to catch issues in new data.

Lack of Diversity: Homogeneous datasets produce models that overfit. If all your examples are short, low-urgency shipping issues, your chatbot will fail on complex, high-urgency scenarios. Ensure diversity across categories, urgency levels, and message styles. Use diversity analysis to identify gaps.

Imbalanced Categories: For classification tasks, imbalanced datasets lead to models favoring majority classes. If 70% of your examples are shipping issues, your model will struggle with billing or technical support. Balance categories or use techniques like oversampling. Generate synthetic data for minority categories.

Synthetic Data Without Validation: Adding unvalidated synthetic data can degrade performance. Always validate synthetic examples for format, relevance, correctness, and diversity before integration. Monitor model performance when using synthetic data to ensure it improves rather than degrades results.

Over-Reliance on Synthetic Data: Using too much synthetic data (more than 40%) relative to real data can degrade performance. Start with 20-30% synthetic and monitor performance. If performance degrades, reduce synthetic ratio or improve synthetic data quality.

Summary
Preparing your customer support dataset involves cleaning raw data, assessing quality, analyzing diversity, generating synthetic examples to fill gaps, and validating readiness for training. You learned to remove duplicates, assess quality across multiple dimensions, analyze diversity to identify gaps, generate synthetic examples using templates or LLMs, validate synthetic data, and run a complete validation workflow.

Your final dataset contains 2,500+ examples (2,000 real + 500 synthetic) with 90%+ quality, balanced categories, and diverse scenarios covering all production use cases. This dataset is ready for fine-tuning your customer support chatbot.

The techniques you learned apply to any fine-tuning task. Adapt the validation functions, category extraction logic, and generation templates for your specific use case. In production, automate these checks to maintain dataset quality as you collect new data.

Key concepts to remember
Data Quality Dimensions - Assess completeness, accuracy, consistency, relevance, and diversity
Cleaning Strategy - Remove duplicates first, then fix missing fields and format inconsistencies
Quality Assessment - Use automated checks for large datasets, combine with manual review for small datasets
Diversity Analysis - Identify gaps in coverage to guide synthetic data generation
Synthetic Data - Use templates for structured tasks, LLMs for complex scenarios; validate before integration
Validation Workflow - Check size, quality, diversity, and format before training
Production Practices - Automate validation checks and monitor quality scores for new data