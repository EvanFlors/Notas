## LLM Interaction: Parameters, Token Management, and Cost Optimization
When you call an LLM API, you are not just sending text and hoping for the best. Behind every successful AI application lies a carefully tuned set of parameters that control exactly how the model generates responses. Consider how GitHub Copilot suggests code; it uses very different parameter settings than ChatGPT writing a creative story or a customer service bot answering support questions.

But there is another critical dimension that many developers overlook until it is too late: token management.

This lesson focuses on the technical components that control LLM behavior; the parameters you can tune and the token economics that determine both cost and performance. By mastering both aspects, you will build more predictable, cost-effective, and reliable AI systems that consistently deliver the right experience for your users while staying within budget.

Core Components of LLM Interaction
Every LLM API call consists of several key components:

Input (Prompt): The text you send to the model
Generation Parameters: Settings that control output behavior
Token Management: Understanding and controlling token usage
Model Selection: Choosing the right model for your use case
Response Processing: Handling and validating the output

Think of this like operating a sophisticated camera. Your prompt is what you are photographing, but the parameters are your camera settings; aperture, shutter speed, ISO; that determine how that photo turns out. Token management is like understanding your film budget; every shot costs money, and you need to balance quality with cost. Just as professional photographers adjust settings based on lighting and subject matter, professional developers tune LLM parameters and manage tokens based on their specific use case.

Basic Prompting
While we will cover prompting in the next module, understanding the basics is essential for parameter tuning and token management. Your prompt is the primary way to communicate with the LLM, and its efficiency directly impacts both performance and cost.

Simple Effective Prompting

The most effective prompts follow a clear structure: context that establishes the AI's role, task description that explains what you want, format specification for the response structure, and constraints that set boundaries. This structure maximizes clarity while minimizing unnecessary tokens.

For example, instead of: "Hey, can you look at this code and tell me if there are any problems with it and maybe suggest some improvements?" (22 tokens), use: "You are a code reviewer. Analyze this function for potential bugs. Provide 2-3 specific issues if found." (19 tokens with better clarity).

Key Prompt Components:

Role/Context: What perspective should the model take?
Task: What specifically do you want the model to do?
Format: How should the response be structured?
Constraints: Any limits or requirements?
The quality of your prompts directly impacts how well parameter tuning works and how efficiently you use tokens. A unclear prompt can not be fixed with parameter adjustments alone and often leads to longer, more expensive responses as the model tries to guess your intent.

Understanding Tokenization
Before diving into parameters, you need to understand tokens; the fundamental units that LLMs process and that determine your costs. Unlike human reading where we see words and sentences, LLMs see sequences of tokens, which are subword units that can represent parts of words, whole words, or punctuation marks.

How Tokenization Works

Most modern LLMs use Byte Pair Encoding (BPE). GPT models typically average about 4 characters per token, but this varies significantly based on content type. Simple English text uses about 0.75 tokens per word, while code uses approximately 1.3 tokens per word due to symbols and operators. JSON and structured data can consume 1.5 tokens per word or more because of formatting overhead.

Understanding these patterns helps predict costs and optimize performance. A customer support system processing mostly plain text will have different token economics than a code analysis tool processing complex programming languages with heavy symbolic content.

Token Counting with Tiktoken

For production applications, precise token counting is essential. OpenAI provides tiktoken, a fast tokenizer library that gives exact token counts for their models. This eliminates guesswork and enables accurate cost prediction and context management.

Tiktoken supports different encodings for different model families. The newer models use the "cl100k_base" encoding, while older models like text-davinci-003 use "p50k_base". Using the correct encoding ensures your token counts match exactly what the API will charge.

Here is how to implement precise token counting:

```python
import tiktoken

class TokenCounter:
  def __init__(self, model="gpt-4o"):
      # Different models use different encodings
      self.model_encodings = {
          "gpt-4o": "o200k_base",
          "gpt-4.1-mini": "o200k_base",
          "gpt-4.1-nano": "o200k_base",
          "gpt-5": "o200k_base",
          "gpt-5-mini": "o200k_base",
          "gpt-5-nano": "o200k_base",
          "gpt-4": "cl100k_base",
          "gpt-3.5-turbo": "cl100k_base",
      }

      encoding_name = self.model_encodings.get(model, "o200k_base")
      self.encoder = tiktoken.get_encoding(encoding_name)

  def count_tokens(self, text):
      """Get exact token count for text."""
      return len(self.encoder.encode(text))

  def count_message_tokens(self, messages, model="gpt-4o"):
      """Count tokens for chat API messages including overhead."""
      tokens_per_message = 3  # Every message has overhead
      tokens_per_name = 1     # If name field is present

      num_tokens = 0
      for message in messages:
          num_tokens += tokens_per_message
          for key, value in message.items():
              num_tokens += len(self.encoder.encode(value))
              if key == "name":
                  num_tokens += tokens_per_name

      num_tokens += 3  # Every reply is primed with assistant message
      return num_tokens

# Example usage
counter = TokenCounter(model="gpt-4o")

# Count tokens in simple text
text = "Hello, how are you today?"
token_count = counter.count_tokens(text)
print(f"Text: '{text}'")
print(f"Token count: {token_count}")

# Count tokens in chat messages
messages = [
  {"role": "system", "content": "You are a helpful assistant."},
  {"role": "user", "content": "What is machine learning?"}
]
message_tokens = counter.count_message_tokens(messages)
print(f"\nChat messages token count: {message_tokens}")
print(f"  System message: 'You are a helpful assistant.'")
print(f"  User message: 'What is machine learning?'")
print(f"  Total tokens (including overhead): {message_tokens}")
```

Chat API Token Overhead:

When using chat based APIs, remember that conversation structure itself consumes tokens. Each message includes overhead for role definition and formatting. A typical message uses about 3 overhead tokens, plus additional tokens if name fields are present. Every conversation also includes priming tokens for the assistant's response.

This overhead becomes significant in multi-turn conversations. A chat session with 10 exchanges could use 60+ tokens just for structural formatting before considering actual content. For applications with long conversation histories, this overhead represents a substantial portion of token budgets.

Temperature: Controlling Creativity and Consistency
Temperature is the most important parameter for controlling model behavior. It determines how "creative" or "predictable" the model's responses will be by adjusting the probability distribution over possible next tokens.

Understanding Temperature Values:

0.0: Completely deterministic always chooses the most likely next token
0.1-0.3: Very focused and consistent, ideal for factual tasks
0.4-0.7: Balanced between creativity and coherence
0.8-1.2: Creative and varied, good for brainstorming
1.3+: Highly creative but potentially incoherent
Temperature in Production:

```python
class TaskHandler:
  def __init__(self):
      self.temperature_presets = {
          "code_generation": 0.1,      # Need precision
          "data_extraction": 0.0,      # Need consistency
          "customer_support": 0.3,     # Helpful but consistent
          "content_writing": 0.7,      # Creative but coherent
          "brainstorming": 1.0,        # Maximum creativity
          "creative_writing": 1.2      # Highly creative
      }

  def get_temperature(self, task_type):
      return self.temperature_presets.get(task_type, 0.6)  # Default
```

Temperature Impact on Costs:

Lower temperatures are often more cost-effective because they generate more predictable outputs that require less retry logic. Higher temperatures may need multiple attempts to get usable results, increasing both token usage and costs.

Top_p (Nucleus Sampling): Randomness Control
While temperature affects overall randomness, top_p provides more nuanced control. It limits the model to only consider the most probable tokens that collectively make up a specified probability mass.

How Top_p Works:

Instead of considering all possible tokens, the model only looks at tokens whose cumulative probability reaches the top_p threshold:

0.1: Only the top 10% most probable tokens (very focused)
0.5: Top 50% of probability mass (moderate variety)
0.9: Top 90% of probability mass (standard setting)
1.0: All tokens considered (no filtering)
Top_p vs Temperature:

```python
# Precise tasks - use both low temperature and low top_p
def extract_data(text):
  return llm.generate(
      prompt=f"Extract phone number from: {text}",
      temperature=0.2,
      top_p=0.1,          # Very focused token selection
      max_tokens=50
  )

# Creative tasks - higher temperature with high top_p
def generate_ideas(topic):
  return llm.generate(
      prompt=f"Brainstorm 5 innovative ideas for {topic}",
      temperature=0.9,
      top_p=0.95,         # Allow creative token choices
      max_tokens=400
  )
```

Production Best Practices:

Most production applications use top_p values between 0.7-0.9. Values below 0.5 can make responses feel robotic, while values above 0.95 may introduce unexpected words or phrases.

max_tokens: Managing Length and Cost
Max_tokens directly controls response length and API costs. This parameter requires strategic thinking because it affects both the completeness of responses and your budget. Setting max_tokens too low might truncate important information. Setting it too high allows the model to generate unnecessarily verbose responses that waste money.

Token Allocation:

Different tasks warrant different token budgets. Simple question answering might need only 50-100 tokens, while detailed analysis could justify 500-1000 tokens. Consider the value equation: does a longer response provide proportionally more value to justify the additional cost?

Context-Aware Token Budgeting:

Smart applications adjust token limits based on available context window space. If a conversation has consumed most of the context window with history, reduce the max_tokens for the response to ensure the entire interaction fits within limits. This prevents request failures while maintaining conversation continuity.

Cost Calculation and Budget Management
Understanding token costs enables accurate budget planning and prevents surprise bills in production. LLM pricing follows a two-tier model where input and output tokens are priced differently, with output tokens typically costing more.

Current Pricing Landscape:

```python
class CostCalculator:
  def __init__(self):
      # Pricing per 1K tokens (as of 2025, subject to change)
      # Source: https://platform.openai.com/docs/pricing
      self.pricing = {
          "gpt-4.1-mini": {
              "input": 0.0004,   # $0.40 per 1M tokens
              "output": 0.0016   # $1.60 per 1M tokens
          },
          "gpt-4.1-nano": {
              "input": 0.0001,   # $0.10 per 1M tokens
              "output": 0.0004   # $0.40 per 1M tokens
          },
          "gpt-5-mini": {
              "input": 0.00025,  # $0.25 per 1M tokens
              "output": 0.002    # $2.00 per 1M tokens
          },
          "gpt-5-nano": {
              "input": 0.00005,  # $0.05 per 1M tokens
              "output": 0.0004   # $0.40 per 1M tokens
          }
      }

  def calculate_cost(self, input_tokens, output_tokens, model):
      """Calculate exact cost for a request."""
      if model not in self.pricing:
          raise ValueError(f"Pricing not available for model: {model}")

      rates = self.pricing[model]
      input_cost = (input_tokens / 1000) * rates["input"]
      output_cost = (output_tokens / 1000) * rates["output"]

      return {
          "input_cost": input_cost,
          "output_cost": output_cost,
          "total_cost": input_cost + output_cost
      }

# Example usage
calculator = CostCalculator()

# Calculate cost for GPT-4.1-mini
print("=== Cost Calculation Examples ===\n")

# Example 1: GPT-4.1 request
input_tokens = 150
output_tokens = 50
model = "gpt-4.1-mini"

cost = calculator.calculate_cost(input_tokens, output_tokens, model)
print(f"Model: {model}")
print(f"Input tokens: {input_tokens}")
print(f"Output tokens: {output_tokens}")
print(f"Input cost: {cost['input_cost']:.6f}")
print(f"Output cost: {cost['output_cost']:.6f}")
print(f"Total cost: {cost['total_cost']:.6f}")

# Example 2: GPT-5-mini comparison
print("\n--- Same request with GPT-5-mini ---")
model = "gpt-5-mini"
cost_mini = calculator.calculate_cost(input_tokens, output_tokens, model)
print(f"Model: {model}")
print(f"Total cost: {cost_mini['total_cost']:.6f}")
difference = cost_mini['total_cost'] - cost['total_cost']
if difference < 0:
  print(f"Cost difference: {abs(difference):.6f} cheaper")
else:
  print(f"Cost difference: {difference:.6f} more expensive")
```

Additional Key Parameters
Modern LLMs offer several other parameters that can significantly improve results:

Stop Sequences:

They control exactly where the text generation ends.

```python
def generate_function(function_name):
  return llm.generate(
      prompt=f"def {function_name}(",
      stop=["\n\ndef", "\nclass", "# End"],  # Stop at these patterns
      temperature=0.2,
      max_tokens=300
  )
```

Seed Parameter (for reproducible outputs):

To get consistent results for testing

```python
def reproducible_generation(prompt, seed=12345):
  return llm.generate(
      prompt=prompt,
      temperature=0.7,
      seed=seed,              # Same seed = same output
      max_tokens=200
  )
```

Summary
Successful LLM interaction depends on mastering both parameter tuning and token management as interconnected systems that determine both response quality and cost efficiency. Understanding how each parameter affects output behavior enables you to build predictable, reliable AI applications that consistently deliver the right experience for your users while staying within budget.

Key concepts to remember
Values from 0.0 (deterministic) to 1.2+ (creative) directly impact response consistency and cost - low values for factual tasks, higher values for creative applications.
Understanding tokenization (4 chars/token average), using tiktoken for precise counting, and accounting for chat API overhead enables accurate budget planning and prevents surprise bills.
Strategic token allocation based on task value (50-100 for simple answers, 500-1000 for analysis) prevents both truncated responses and unnecessary verbosity.
Top_p provides nuanced randomness control (0.7-0.9 for production), stop sequences control generation endpoints, and seed parameters enable reproducible testing