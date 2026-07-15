## API Fundamentals & Request Structure
You are tasked to integrate an LLM into the company's customer support system. You open the API documentation and see dozens of parameters, different model names, and various endpoint patterns. Where do you start? How do you choose between OpenAI and Anthropic? What is the difference between a chat completion and a text completion?

In this lesson, you will master the core concepts of LLM APIs by working with the two most popular providers: OpenAI and Anthropic. You will learn how to structure requests effectively, understand the subtle but important differences between platforms, and make informed decisions about which API fits your specific use case.

Understanding API Architecture Patterns

Chat Completion
Modern LLM APIs center around the "chat completion" pattern, which represents conversations as structured message arrays. This wasn't always the case; early APIs used simple text-in, text-out patterns. The chat format revolutionized how we interact with AI because it mirrors natural conversation flow while giving developers precise control over context and roles.

Think of the message array as a movie script. Each message has a role; system, user, assistant (we will deep dive in the next module) and content. The system message is like director's notes; it sets the scene and defines how the AI should behave. User and assistant messages create the dialogue back and forth.

```python
{
"model": "gpt-4",
"messages": [
    {"role": "system", "content": "You are a senior software engineer helping junior developers."},
    {"role": "user", "content": "How do I optimize this database query?"},
    {"role": "assistant", "content": "I'd be happy to help! First, let me understand your current query..."},
    {"role": "user", "content": "SELECT * FROM users WHERE created_at > '2023-01-01'"}
]
}
```

This structure enables sophisticated applications like multi-turn conversations, role-playing scenarios, and context-aware assistance that remembers previous exchanges.

OpenAI API Structure Deep Dive
OpenAI's API design emphasizes simplicity and powerful defaults. Their chat completions endpoint handles most use cases with intuitive parameter names and behavior.

Core Request Parameters:

The model parameter determines capability and cost. gpt-4.1 provides the highest quality with less costs. For production applications, start with gpt-4.1 for development and testing, then upgrade to gpt-5 only where the quality difference justifies the cost.

```python
{
    "model": "gpt-4.1",
    "messages": [...],
    "max_tokens": 150,
    "temperature": 0.7,
    "top_p": 1.0,
    "stop": ["\n\n"]
}
```

max_tokens controls response length and directly impacts cost. Setting this thoughtfully prevents runaway generation while ensuring complete responses. For customer support, 200-300 tokens typically provide comprehensive answers without excessive verbosity.

temperature and top_p work together to control creativity. Use low temperature (0.1-0.3) for factual tasks, medium (0.5-0.7) for balanced responses, and high (0.8-1.0) for creative applications. Most production chat applications work well with temperature around 0.7.

Anthropic API
Anthropic's Claude API takes a more structured approach with explicit emphasis on safety and controllability. While similar in basic structure, it includes unique features that reflect Anthropic's focus on AI alignment.

```python
{
    "model": "claude-3-sonnet-20240229",
    "max_tokens": 150,
    "messages": [
        {"role": "user", "content": "Explain quantum computing"}
    ],
    "system": "You are a physics professor explaining complex topics to undergraduate students."
}
```

Notice how Anthropic separates the system message into its own parameter rather than including it in the messages array. This design choice reflects their emphasis on clear separation between instructions and conversation content.

The API requires explicit max_tokens; there is no default. This forces developers to think about response length upfront, preventing unexpected costs from verbose responses.

Claude models tend to be more conversational and helpful by default, often requiring less prompt engineering to achieve desired behavior. However, they may be more verbose, making careful token management even more important.

Authentication and Security
Both APIs use API key authentication, but implementing this securely requires attention to detail. Never hardcode API keys in client-side code or commit them to version control.

```python

import os
from openai import OpenAI
from anthropic import Anthropic

# Secure API key management
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
anthropic_client = Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))
```

In production, use environment variables or secure secret management systems. Consider implementing API key rotation policies, especially for high-volume applications.

Model Selection Strategy
Choosing the right model involves balancing quality, speed, and cost. Here is a framework:

Development Phase: Use the fastest, cheapest models for initial development and testing. This lets you iterate quickly without burning budget.

Production Optimization: Benchmark different models on your specific use case. Create a small evaluation dataset of real user queries and compare response quality across models. Sometimes the cheaper model performs adequately for your specific domain.

Hybrid Approaches: Use different models for different tasks within the same application. Route simple questions to cheaper models and complex requests to premium models. Implement this routing logic based on query complexity, user tier, or content type.

Request Structure Best Practices
Context Management: Design your message array structure from day one. In a customer support system, you might include:

System message with company-specific guidelines
Last 3-5 exchanges for immediate context
Relevant knowledge base snippets
Current user query

```python
def build_support_request(user_query, conversation_history, kb_context):
  messages = [
      {"role": "system", "content": f"You are a helpful customer support agent for AcmeCorp. Use this context: {kb_context}"},
  ]

  # Add recent conversation history
  messages.extend(conversation_history[-5:])  # Last 5 exchanges

  # Add current query
  messages.append({"role": "user", "content": user_query})

  return messages
```

Parameter Optimization: Create parameter profiles for different use cases:

```python
PARAMETER_PROFILES = {
    "factual": {"temperature": 0.2, "max_tokens": 200, "top_p": 0.9},
    "creative": {"temperature": 0.8, "max_tokens": 400, "top_p": 0.95},
    "concise": {"temperature": 0.5, "max_tokens": 100, "top_p": 1.0}
}
```

Cross-Platform Compatibility
If you are building an application that might use multiple providers, design your code with abstraction:

```python
class LLMProvider:
  def __init__(self, provider_type, api_key):
      self.provider_type = provider_type
      if provider_type == "openai":
          self.client = OpenAI(api_key=api_key)
      elif provider_type == "anthropic":
          self.client = Anthropic(api_key=api_key)

  def generate_response(self, messages, **kwargs):
      if self.provider_type == "openai":
          return self._openai_request(messages, **kwargs)
      elif self.provider_type == "anthropic":
          return self._anthropic_request(messages, **kwargs)
```

This abstraction lets you switch providers based on availability, cost, or performance requirements without rewriting your entire application.

Common Pitfalls and Solutions
System Message Confusion
Mistake: Treating system messages as user instructions or including conversational elements in system prompts.

Solution: System messages should contain instructions for the AI, not conversation. They're like briefing documents for an employee, not part of the customer interaction.

Wrong:

```python
{
    "role": "system",
    "content": "Hi! You're going to help users with math problems. Be friendly!"
}
```

Right:

```python
{
    "role": "system",
    "content": "You are a mathematics tutor. Provide step-by-step explanations for math problems. Use clear, educational language appropriate for high school students."
}
```

Context Window Overflow
Mistake: Building up conversation history until you hit the model's context limit, causing requests to fail.

Solution: Implement intelligent context management that preserves important information while staying within limits.

Parameter Copy-Paste
Mistake: Using identical parameters across all use cases without considering the specific requirements.

Solution: Create parameter profiles tailored to different scenarios. A creative writing application needs different settings than a factual Q&A system.

Summary
Understanding LLM API fundamentals means mastering both the technical mechanics and strategic considerations of request structure. The choices you make in API design from provider selection to parameter tuning directly impact your application's performance, cost, and user experience.

Key concepts to remember
Modern APIs use message arrays with roles (system, user, assistant) that mirror natural conversation flow while providing precise control over context and AI behavior.
OpenAI emphasizes simplicity with intuitive defaults, while Anthropic separates system messages and requires explicit max_tokens, reflecting different design philosophies that affect integration patterns.
Create tailored parameter sets for different use cases (factual: low temperature, creative: high temperature) rather than using identical settings across all scenarios.