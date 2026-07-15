## Transformer Architectures
You now understand how attention mechanisms work and how transformer blocks process information. You have also explored two key transformer patterns in Module 1.3: BERT's encoder-only architecture (lesson 1.3.2) excels at understanding tasks through bidirectional attention, while GPT's decoder-only design (lesson 1.3.3) generates text using causal attention. But here is the key insight: the same building blocks can be arranged in fundamentally different ways to create models optimized for different tasks.

Think of transformer architectures like different factory layouts using the same machinery. An assembly line optimized for inspecting products (encoder-only) looks very different from one optimized for manufacturing new products (decoder-only), and both differ from a factory that inspects raw materials before manufacturing finished goods (encoder-decoder). Each layout uses the same transformer blocks you learned about, but arranges them to excel at specific types of work.

By the end of this lesson, you will learn how attention flows differently in each architecture and how to choose the right architectural pattern for your specific use case.

Encoder-Only Architecture: Deep Bidirectional Understanding
Encoder-only models like BERT process text by allowing every token to attend to every other token in both directions simultaneously (as discussed in the previous submodule). This creates rich, contextual representations perfect for understanding tasks.

![Encoder-Only Architecture](https://hrcdn.net/ai-engineering/module-1/dark/transformers-lesson03-architecture-comparison.svg)

```python
# Input: "The software engineer debugged the authentication bug"
# Every token can attend to every other token:

"software" can attend to: ["The", "software", "engineer", "debugged", "the", "authentication", "bug"]
"debugged" can attend to: ["The", "software", "engineer", "debugged", "the", "authentication", "bug"]
"bug" can attend to: ["The", "software", "engineer", "debugged", "the", "authentication", "bug"]
```

This bidirectional attention enables sophisticated understanding. When processing "debugged," the model can simultaneously consider both the subject ("software engineer") that comes before and the object ("authentication bug") that comes after. This comprehensive context awareness makes encoder models excellent at:

Determining if a code review comment is positive or negative requires understanding the entire comment's context, not just processing it left-to-right.
Identifying that "AWS" refers to a cloud service requires understanding both the technical context before it and any clarifying information after it.
Finding the answer to "What authentication method is used?" requires understanding the entire document context, not just sequential processing.

Decoder-Only Architecture
Decoder-only models like GPT process text sequentially, with each token only able to attend to previous tokens. This constraint, called causal masking, prevents the model from "cheating" by looking ahead during training, making these models natural text generators.

How Attention Flows in Decoders:

```python
# Input: "The software engineer debugged"
# Each token can only attend to previous tokens:

"The" can attend to: ["The"]
"software" can attend to: ["The", "software"]
"engineer" can attend to: ["The", "software", "engineer"]
"debugged" can attend to: ["The", "software", "engineer", "debugged"]
```

This left-to-right processing creates models that naturally predict what comes next, making them perfect for text generation tasks. When generating the next word after "debugged," the model considers the full context of "The software engineer debugged" but cannot peek ahead to see what the intended completion should be.

Generation Process in Detail: Decoder-only models generate text autoregressively—they produce one token at a time, feeding each generated token back as input for generating the next token:

```python
# Step 1: Input "Write a function to"
# Output: "validate"

# Step 2: Input "Write a function to validate"
# Output: "user"

# Step 3: Input "Write a function to validate user"
# Output: "credentials"
```

This sequential process explains several important characteristics of decoder-only models:

Coherence Over Long Sequences: Because each token is generated considering all previous context, decoder models maintain consistency across long generated texts.
Inference Latency: Generation requires multiple forward passes (one per token), making decoder models slower than encoder models for understanding tasks.
Memory Growth: The context grows with each generated token, eventually hitting context window limits.

Encoder-Decoder Architecture: The Best of Both Worlds
Encoder-decoder models combine both architectures in sequence: an encoder processes and understands the input, then a decoder generates the output while attending to the encoder's representations. This architecture originated with translation tasks but works well for any input-to-output transformation.

How Information Flows in Encoder-Decoder Models:

Stage 1 - Encoding: The encoder processes the input bidirectionally, creating rich representations of the source content:

```python
# Input: "def authenticate_user(token):"
# Encoder creates bidirectional representations understanding:
# - "def" indicates function definition
# - "authenticate_user" is the function name
# - "token" is the parameter
# - The overall structure is a function signature
```

Stage 2 - Decoding: The decoder generates output sequentially, but with a crucial difference from decoder-only models—it can attend to both previous generated tokens AND all encoder representations:

```python
# Generating documentation for the function:
# "This function" attends to: previous tokens + full encoder representations
# "validates user" attends to: previous tokens + full encoder representations
# "authentication" attends to: previous tokens + full encoder representations
```

When to Choose Encoder-Decoder: Use encoder-decoder models when you need to transform input text into significantly different output text, especially when the input and output have different structures, lengths, or even languages.

Translation: Understand source language text, generate target language text
Summarization: Understand long document, generate concise summary
Code Documentation: Understand code structure, generate explanatory text
Data-to-Text: Understand structured data, generate natural language descriptions

Attention Pattern Comparisons
Understanding how attention patterns differ between architectures helps explain their strengths and optimal use cases:

![Attention Patterns](https://hrcdn.net/ai-engineering/module-1/light/transformers-lesson03-attention-patterns-comparison.svg)

Encoder-Only Attention Patterns:

Full Bidirectionality: Every position can attend to every other position
Symmetric: Attention flows equally in all directions
Global Context: Each token sees the complete input context
Parallel Processing: All positions processed simultaneously
Decoder-Only Attention Patterns:

Causal Masking: Each position can only attend to previous positions
Asymmetric: Information flows only left-to-right
Growing Context: Context expands as generation progresses
Sequential Processing: One token generated at a time
Encoder-Decoder Attention Patterns:

Encoder: Bidirectional attention within input
Decoder Self-Attention: Causal masking within generated output
Cross-Attention: Decoder can attend to all encoder positions
Hybrid Processing: Parallel encoding, sequential decoding

Attention Flow Comparison
Shows how information flows differently through encoder-only, decoder-only, and encoder-decoder architectures.

```python
def demonstrate_attention_patterns():
  """
  Visualize how attention works differently across transformer architectures.
  Shows the core differences that make each architecture suited for different tasks.
  """

  sentence = ["The", "software", "engineer", "debugged", "the", "bug"]
  length = len(sentence)

  print("Attention Patterns Across Transformer Architectures")
  print("=" * 60)
  print(f"Input: {' '.join(sentence)}")
  print()

  # Encoder-Only (BERT-style) - Bidirectional attention
  print("🔍 ENCODER-ONLY (BERT): Bidirectional Attention")
  print("Each word can attend to ALL other words")
  print("Perfect for understanding tasks")
  print()

  for i, word in enumerate(sentence):
      attention_mask = "✓ " * length  # Can attend to all positions
      print(f"{word:>10} can attend to: {attention_mask}")

  print(f"\nResult: Rich understanding from full context")
  print("Use for: Classification, QA, sentiment analysis")
  print()

  # Decoder-Only (GPT-style) - Causal attention
  print("📝 DECODER-ONLY (GPT): Causal Attention")
  print("Each word can only attend to PREVIOUS words")
  print("Perfect for generation tasks")
  print()

  for i, word in enumerate(sentence):
      attention_mask = "✓ " * (i + 1) + "✗ " * (length - i - 1)
      print(f"{word:>10} can attend to: {attention_mask}")

  print(f"\nResult: Natural text generation, one word at a time")
  print("Use for: Text completion, chatbots, creative writing")
  print()

  # Encoder-Decoder (T5-style) - Hybrid attention
  print("🔄 ENCODER-DECODER (T5): Hybrid Attention")
  print("Encoder: bidirectional, Decoder: causal + cross-attention")
  print("Perfect for transformation tasks")
  print()

  # Show encoder phase
  print("Phase 1 - Encoder (understanding input):")
  for i, word in enumerate(sentence[:3]):  # First 3 words as input
      attention_mask = "✓ " * 3  # Can attend to all input positions
      print(f"  {word:>10} can attend to: {attention_mask}")

  print("\nPhase 2 - Decoder (generating output):")
  output_words = ["This", "function", "fixes"]
  for i, word in enumerate(output_words):
      # Can attend to previous output + all encoder states
      decoder_mask = "✓ " * (i + 1) + "✗ " * (len(output_words) - i - 1)
      encoder_mask = "✓ " * 3  # All encoder positions
      print(f"  {word:>10} attends to prev: {decoder_mask} + encoder: {encoder_mask}")

  print(f"\nResult: Transform input to different output")
  print("Use for: Translation, summarization, code documentation")

demonstrate_attention_patterns()
```

Summary
Transformer architectures represent different arrangements of the same building blocks, each optimized for specific types of language tasks. Encoder-only models excel at understanding through bidirectional attention, decoder-only models master generation through causal attention, and encoder-decoder models combine both capabilities for transformation tasks.

Key concepts to remember
Bidirectional attention (encoder-only) enables deep understanding, causal attention (decoder-only) enables coherent generation, and cross-attention (encoder-decoder) enables input-output transformation.
Models like BERT use bidirectional attention where every token can see every other token, making them perfect for classification, Q&A, and sentiment analysis tasks.
Models like GPT use causal masking where tokens only see previous tokens, enabling natural autoregressive text generation one token at a time with maintained coherence.
Models like T5 combine bidirectional encoding of input with causal decoding plus cross-attention, making them ideal for translation, summarization, and any input-to-output transformation tasks.