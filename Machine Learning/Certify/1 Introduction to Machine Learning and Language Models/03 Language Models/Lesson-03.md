## GPT: Next-Token Language Models for Generation Tasks
Imagine you are writing an email and your phone suggests the next word as you type. That predictive text feature uses the same core principle that powers GPT models: predicting what comes next based on everything that came before. But while your phone might suggest one word, GPT can continue writing entire emails, articles, or even code with remarkable coherence.

GPT (Generative Pre-trained Transformer) revolutionized AI by showing that a simple next-token prediction task, when scaled to massive datasets and model sizes, could produce human-like text generation capabilities. Unlike BERT's bidirectional understanding approach, GPT processes text sequentially from left to right, making it naturally suited for generating coherent, contextual text.

In this lesson, you will understand how GPT's next-token prediction works, why its decoder-only architecture excels at generation tasks.

Next-Token Prediction
Next-token prediction is deceptively simple yet incredibly powerful. Given a sequence of tokens (words or subwords), the model predicts the probability distribution over all possible next tokens. This autoregressive approach enables coherent long-form generation by building text one token at a time.

How Next-Token Prediction Works
Think of next-token prediction like an extremely sophisticated autocomplete system. Given the input "The weather today is", the model might predict:

"sunny" (probability: 0.3)
"cloudy" (probability: 0.25)
"rainy" (probability: 0.2)
"beautiful" (probability: 0.15)
"terrible" (probability: 0.1)
The model does not just pick the highest probability token. Instead, it samples from this distribution, allowing for creativity and variation in generation while maintaining coherence.

Next-Token Prediction Logic
Shows how GPT calculates probabilities for the next token using simple Python logic.

```python
import random

def simulate_next_token_prediction(context, vocabulary):
  """
  Simulate how GPT predicts next token probabilities.
  Shows the core concept without loading actual models.
  """
  # Simple rule-based probability assignment (simulating neural network output)
  probabilities = {}

  if "weather" in context.lower():
      probabilities = {"sunny": 0.3, "cloudy": 0.25, "rainy": 0.2, "beautiful": 0.15, "terrible": 0.1}
  elif "cat" in context.lower():
      probabilities = {"mat": 0.4, "chair": 0.3, "floor": 0.2, "sofa": 0.1}
  else:
      # Default uniform distribution
      prob = 1.0 / len(vocabulary)
      probabilities = {word: prob for word in vocabulary}

  return probabilities

# Example usage
context = "The weather today is"
vocab = ["sunny", "cloudy", "rainy", "beautiful", "terrible"]

probs = simulate_next_token_prediction(context, vocab)
print(f"Context: '{context}'")
print("Next token probabilities:")
for token, prob in probs.items():
  print(f"  '{token}': {prob:.2f}")

# Shows how model assigns different probabilities based on context
```

Training Objective
GPT models are trained on a simple objective: given a sequence of tokens, predict the next token. During training, the model sees examples like:

![GPT Training Objective](https://hrcdn.net/ai-engineering/module-1/dark/language-models-lesson03-next-token-prediction.svg)

Input: "The cat sat on the"
Target: "mat"
Loss: Cross-entropy between predicted probability distribution and actual next token
This simple objective forces the model to learn:

Grammar and syntax (what combinations of words are valid)
Semantic relationships (what concepts relate to each other)
World knowledge (facts about how the world works)
Writing patterns (how different types of text are structured)

GPT's Decoder-Only Architecture
![GPT Architecture](https://hrcdn.net/ai-engineering/module-1/dark/language-models-lesson03-gpt-architecture.svg)

GPT uses only the decoder portion of the transformer architecture, specifically designed for sequential generation tasks. This architectural choice enables powerful text generation while maintaining computational efficiency.

Understanding Decoder-Only Design
The decoder-only architecture has several key characteristics:

Causal Masking: Each position can only attend to current and previous positions, never future positions. This prevents the model from "cheating" during training by looking ahead.

Autoregressive Generation: Text is generated one token at a time, with each new token conditioned on all previous tokens in the sequence.

Step-by-Step Text Building
Simulates how GPT builds text token by token, showing the autoregressive process.

```python
def autoregressive_generation(initial_text, max_tokens=5):
  """
  Simulate how GPT generates text step by step.
  Each new token depends on all previous tokens.
  """
  # Simple vocabulary and transition rules
  transitions = {
      "The cat": ["sat", "jumped", "ran"],
      "cat sat": ["on", "near", "beside"],
      "sat on": ["the", "a", "his"],
      "on the": ["mat", "chair", "floor"],
      "on a": ["cushion", "pillow", "rug"]
  }

  current_text = initial_text
  generation_steps = []

  print(f"Starting with: '{current_text}'")
  print("\nGeneration steps:")

  for step in range(max_tokens):
      # Look for pattern in current text
      words = current_text.split()
      context_key = " ".join(words[-2:]) if len(words) >= 2 else current_text

      # Get possible next tokens
      next_options = transitions.get(context_key, [".", "!"])
      next_token = next_options[0]  # Pick first option (could be random)

      # Add to sequence
      current_text += " " + next_token
      generation_steps.append({
          'step': step + 1,
          'context': context_key,
          'next_token': next_token,
          'full_text': current_text
      })

      print(f"Step {step + 1}: Context '{context_key}' → Next: '{next_token}'")
      print(f"         Result: '{current_text}'")

      if next_token in [".", "!"]:
          break

  return current_text

# Example autoregressive generation
final_text = autoregressive_generation("The cat")
print(f"\nFinal generated text: '{final_text}'")
```

Unified Architecture: The same model architecture handles both training (predicting next tokens in training data) and inference (generating new text).

Why Decoder-Only Works for Generation
The decoder-only design offers several advantages for generation tasks:

Natural Generation Process: The sequential processing matches how text is naturally produced and consumed by humans.

Consistent Training and Inference: The same causal masking used during training is naturally enforced during generation.

Scalability: Decoder-only models can be efficiently scaled to very large sizes without architectural complexity.

Flexibility: Can handle various generation tasks (completion, conversation, creative writing) with the same architecture.

GPT's Typical Applications: Where Generation Excels
GPT models excel at tasks that require generating coherent, contextual text. This includes Content generation, conversational AI, code generation, text completion.

Common Pitfalls and Solutions
Over-Generation and Repetition: GPT models can produce repetitive or overly verbose output. Use repetition penalties, length limits, and proper stopping criteria to control generation quality.

Inconsistent Factual Information: GPT can generate plausible-sounding but incorrect information. Implement fact-checking pipelines and human review for factual content.

Context Window Limitations: GPT models have fixed context windows (2048 tokens for GPT-2, longer for newer models). Design applications to handle context truncation gracefully.

Temperature and Sampling Complexity: Finding the right balance between creativity (high temperature) and coherence (low temperature) requires experimentation. Start with moderate values (0.7-0.8) and adjust based on use case.

Adjust temperature and top-p sliders to control how random or predictable the model's word choices are. See probability distributions update in real-time.

Experiment: Set temperature to 0.0 (model always picks "approved"), then 0.5 (more balanced), then 1.0 (maximum randomness; even nonsensical tokens like "delicious" and "quantum" become likely). Try top-p at 0.5 to filter absurd options. Low temperature ensures factual, deterministic outputs (docs, support tickets); high temperature enables creative variation (brainstorming, content generation).

Temperature Effects on Sampling
Demonstrates how temperature affects token selection, showing the creativity vs coherence trade-off.

```python
import math
import random

def apply_temperature(probabilities, temperature):
  """
  Show how temperature affects probability distribution.
  Lower temperature = more focused, higher = more random.
  """
  if temperature == 0:
      # Greedy selection - always pick highest probability
      return probabilities

  # Apply temperature scaling
  scaled_probs = {}
  for token, prob in probabilities.items():
      # Convert to logits, scale by temperature, convert back
      logit = math.log(prob + 1e-10)  # Avoid log(0)
      scaled_logit = logit / temperature
      scaled_probs[token] = math.exp(scaled_logit)

  # Normalize to sum to 1
  total = sum(scaled_probs.values())
  return {token: prob / total for token, prob in scaled_probs.items()}

def sample_with_temperature(probabilities, temperature, num_samples=5):
  """Sample tokens with different temperature settings."""
  scaled_probs = apply_temperature(probabilities, temperature)

  print(f"Temperature: {temperature}")
  print("Scaled probabilities:")
  for token, prob in scaled_probs.items():
      print(f"  {token}: {prob:.3f}")

  # Sample multiple times to show variety
  samples = []
  for _ in range(num_samples):
      rand_val = random.random()
      cumulative = 0
      for token, prob in scaled_probs.items():
          cumulative += prob
          if rand_val <= cumulative:
              samples.append(token)
              break

  print(f"Sample outputs: {samples}\n")
  return samples

# Original probabilities
base_probs = {"sunny": 0.4, "cloudy": 0.3, "rainy": 0.2, "stormy": 0.1}

print("Effect of Temperature on Token Selection:")
print("=" * 45)

# Low temperature (conservative)
sample_with_temperature(base_probs, 0.1, 5)

# Medium temperature (balanced)
sample_with_temperature(base_probs, 1.0, 5)

# High temperature (creative)
sample_with_temperature(base_probs, 2.0, 5)
```

Summary
GPT's next-token prediction approach and decoder-only architecture make it exceptionally powerful for text generation tasks. The sequential processing enables coherent long-form content creation while maintaining contextual consistency.

Key concepts to remember
GPT's autoregressive generation builds text token by token using causal attention patterns
Decoder-only architecture enables natural sequential generation while maintaining training efficiency
GPT excels at creative content, conversation, code generation, and text completion tasks
Generation parameters (temperature, top_p) critically impact output quality and creativity
Context window management and factual accuracy require careful engineering considerations