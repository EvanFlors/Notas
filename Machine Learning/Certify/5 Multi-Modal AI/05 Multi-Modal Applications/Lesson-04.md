## What Are Multi-Modal Agents

Multi-modal agents extend traditional AI agents by enabling them to perceive and act across different modalities. While text-based agents process and generate text, multi-modal agents can see images, hear audio, generate visual content, and speak responses. This broader perception and action space enables solving problems that require multiple senses.

Consider a home automation agent. A text-only agent can turn lights on or off when asked. A multi-modal agent can look at a camera feed to see if anyone is home, listen for sounds indicating activity, and generate spoken alerts. It perceives and acts more like a human assistant.

Multi-Modal Agent Capabilities:

Perception: Understanding inputs from multiple modalities. Analyzing images, transcribing speech, watching video streams.

Reasoning: Combining information across modalities to make decisions. Understanding that a crying sound plus an empty baby monitor image requires action.

Action: Producing outputs in multiple modalities. Speaking responses, generating images, creating videos.

Tool Use: Calling tools that operate on different modalities. Image generation APIs, speech synthesis, visual search.

Multi-modal agent architecture showing perception inputs from vision, audio, and text feeding into reasoning, which produces actions across multiple modalities

![Multi-modal agents perceive, reason, and act across text, images, and audio](https://hrcdn.net/ai-engineering/module-5/light/multimodal-lesson04-agent-architecture.svg)

```python
# Multi-modal agent capabilities:

# Perception
image_understanding = agent.see(camera_feed)
audio_understanding = agent.hear(microphone_input)
text_understanding = agent.read(document)

# Reasoning across modalities
situation = agent.reason(
  visual=image_understanding,
  audio=audio_understanding,
  context=text_understanding
)

# Multi-modal action
agent.speak("I notice the package has arrived")
agent.generate_image("Annotated view of package location")
agent.send_notification("Package delivered", include_photo=True)
Building a Multi-Modal Agent
Here is a framework for building agents that work across modalities:

multimodal_agent.py
python
from dataclasses import dataclass
from typing import Any, Callable, Optional
from enum import Enum
import json

class Modality(Enum):
  TEXT = "text"
  IMAGE = "image"
  AUDIO = "audio"
  VIDEO = "video"

@dataclass
class Perception:
  """Agent's perception of input."""
  modality: Modality
  content: Any
  understanding: str
  confidence: float

@dataclass
class AgentAction:
  """Action the agent wants to take."""
  action_type: str
  modality: Modality
  parameters: dict

class MultiModalAgent:
  """
  Agent that perceives and acts across multiple modalities.
  """

  def __init__(self, client, system_prompt: str = None):
      self.client = client
      self.system_prompt = system_prompt or self._default_system_prompt()
      self.tools = {}
      self.conversation_history = []

  def _default_system_prompt(self) -> str:
      return """
        You are a multi-modal AI agent capable of:
        - Analyzing images and describing what you see
        - Understanding audio through transcription
        - Generating images when needed
        - Speaking responses as audio
        - Combining information from multiple sources

        When responding, consider all available modalities and choose the most appropriate
        way to help the user. You can use tools to generate images or speech.
      """

  def register_tool(
      self,
      name: str,
      function: Callable,
      description: str,
      input_modality: Modality = None,
      output_modality: Modality = None
  ):
      """Register a tool the agent can use."""
      self.tools[name] = {
          "function": function,
          "description": description,
          "input_modality": input_modality,
          "output_modality": output_modality
      }

  def perceive_image(self, image_path: str) -> Perception:
      """Perceive and understand an image."""
      with open(image_path, "rb") as f:
          import base64
          base64_image = base64.standard_b64encode(f.read()).decode()

      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[
              {
                  "role": "user",
                  "content": [
                      {"type": "text", "text": "Describe what you see in detail."},
                      {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
                  ]
              }
          ],
          max_tokens=500
      )

      understanding = response.choices[0].message.content

      return Perception(
          modality=Modality.IMAGE,
          content=image_path,
          understanding=understanding,
          confidence=0.9
      )

  def perceive_audio(self, audio_path: str) -> Perception:
      """Perceive and understand audio."""
      with open(audio_path, "rb") as f:
          transcript = self.client.audio.transcriptions.create(
              model="whisper-1",
              file=f
          )

      return Perception(
          modality=Modality.AUDIO,
          content=audio_path,
          understanding=f"Audio transcript: {transcript.text}",
          confidence=0.85
      )

  def think(
      self,
      user_message: str,
      perceptions: list[Perception] = None
  ) -> dict:
      """
      Process user message with any perceptions and decide on action.
      """
      messages = [{"role": "system", "content": self.system_prompt}]

      # Add conversation history
      messages.extend(self.conversation_history)

      # Build current message with perceptions
      content = [{"type": "text", "text": user_message}]

      if perceptions:
          for p in perceptions:
              if p.modality == Modality.IMAGE:
                  with open(p.content, "rb") as f:
                      import base64
                      base64_img = base64.standard_b64encode(f.read()).decode()
                  content.append({
                      "type": "image_url",
                      "image_url": {"url": f"data:image/jpeg;base64,{base64_img}"}
                  })
              else:
                  content.append({
                      "type": "text",
                      "text": f"[{p.modality.value} perception]: {p.understanding}"
                  })

      messages.append({"role": "user", "content": content})

      # Define available tools
      tools = [
          {
              "type": "function",
              "function": {
                  "name": name,
                  "description": info["description"],
                  "parameters": {"type": "object", "properties": {}, "required": []}
              }
          }
          for name, info in self.tools.items()
      ]

      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=messages,
          tools=tools if tools else None,
          max_tokens=1000
      )

      message = response.choices[0].message

      # Update history
      self.conversation_history.append({"role": "user", "content": user_message})
      self.conversation_history.append({"role": "assistant", "content": message.content})

      return {
          "response": message.content,
          "tool_calls": message.tool_calls if hasattr(message, 'tool_calls') else None
      }

  def act(self, action: AgentAction) -> Any:
      """Execute an action."""
      if action.action_type in self.tools:
          tool = self.tools[action.action_type]
          return tool["function"](**action.parameters)

      raise ValueError(f"Unknown action: {action.action_type}")
```


Adding Multi-Modal Tools
Agents become more capable with tools that operate on different modalities:

```python
def create_multimodal_agent(client) -> MultiModalAgent:
  """Create an agent with multi-modal tools."""
  agent = MultiModalAgent(client)

  # Image generation tool
  def generate_image(prompt: str, style: str = "natural") -> str:
      response = client.images.generate(
          model="gpt-image-1-mini",
          prompt=prompt,
          size="1024x1024",
          style=style
      )

      # Download and save
      import httpx
      import uuid

      image_url = response.data[0].url
      image_response = httpx.get(image_url)

      output_path = f"generated_{uuid.uuid4().hex[:8]}.png"
      with open(output_path, "wb") as f:
          f.write(image_response.content)

      return output_path

  agent.register_tool(
      name="generate_image",
      function=generate_image,
      description="Generate an image from a text description",
      input_modality=Modality.TEXT,
      output_modality=Modality.IMAGE
  )

  # Text-to-speech tool
  def speak(text: str, voice: str = "nova") -> str:
      response = client.audio.speech.create(
          model="tts-1",
          voice=voice,
          input=text
      )

      import uuid
      output_path = f"speech_{uuid.uuid4().hex[:8]}.mp3"
      response.stream_to_file(output_path)

      return output_path

  agent.register_tool(
      name="speak",
      function=speak,
      description="Convert text to spoken audio",
      input_modality=Modality.TEXT,
      output_modality=Modality.AUDIO
  )

  # Image analysis tool
  def analyze_image(image_path: str, question: str) -> str:
      with open(image_path, "rb") as f:
          import base64
          base64_image = base64.standard_b64encode(f.read()).decode()

      response = client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[
              {
                  "role": "user",
                  "content": [
                      {"type": "text", "text": question},
                      {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
                  ]
              }
          ],
          max_tokens=500
      )

      return response.choices[0].message.content

  agent.register_tool(
      name="analyze_image",
      function=analyze_image,
      description="Analyze an image and answer questions about it",
      input_modality=Modality.IMAGE,
      output_modality=Modality.TEXT
  )

  return agent

# Usage example
async def demo_multimodal_agent():
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)
  agent = create_multimodal_agent(client)

  # User shows an image and asks a question
  perception = agent.perceive_image("product_photo.jpg")

  result = agent.think(
      "What is this product and can you create a marketing image for it?",
      perceptions=[perception]
  )

  print(result["response"])

  # If agent decided to generate an image, execute that
  if result.get("tool_calls"):
      for tool_call in result["tool_calls"]:
          if tool_call.function.name == "generate_image":
              args = json.loads(tool_call.function.arguments)
              generated_path = agent.act(AgentAction(
                  action_type="generate_image",
                  modality=Modality.IMAGE,
                  parameters=args
              ))
              print(f"Generated image: {generated_path}")
```

Multi-Modal Agent Patterns
Common patterns for multi-modal agents:

```python
class AssistantAgent(MultiModalAgent):
  """
  Personal assistant agent with multi-modal capabilities.
  """

  def __init__(self, client):
      system_prompt = """
        You are a personal assistant with the ability to:
        - See and understand images the user shares
        - Listen to and transcribe audio
        - Generate images when the user needs visual content
        - Speak responses when audio output is preferred

        Be helpful, concise, and proactive in using multi-modal capabilities
        when they would better serve the user.
      """

      super().__init__(client, system_prompt)
      self._register_assistant_tools()

  def _register_assistant_tools(self):
      # Tools specific to assistant functionality
      pass

  async def process_request(
      self,
      text: str = None,
      images: list[str] = None,
      audio: str = None,
      prefer_audio_response: bool = False
  ) -> dict:
      """
      Process a user request with multiple input modalities.
      """
      perceptions = []

      if images:
          for img_path in images:
              perceptions.append(self.perceive_image(img_path))

      if audio:
          perceptions.append(self.perceive_audio(audio))

      user_message = text or "Please analyze the provided content."

      result = self.think(user_message, perceptions)

      response = {"text": result["response"]}

      if prefer_audio_response and result["response"]:
          audio_path = self.tools["speak"]["function"](result["response"])
          response["audio"] = audio_path

      return response

class MonitoringAgent(MultiModalAgent):
  """
  Agent that monitors visual feeds and alerts on events.
  """

  def __init__(self, client, alert_callback: Callable):
      system_prompt = """
        You are a monitoring agent. Analyze visual feeds and:
        - Detect significant events (people entering, unusual activity)
        - Track changes over time
        - Alert when predefined conditions are met
        - Maintain awareness of normal vs abnormal patterns
      """

      super().__init__(client, system_prompt)
      self.alert_callback = alert_callback
      self.baseline_understanding = None

  def establish_baseline(self, image_path: str):
      """Establish what 'normal' looks like."""
      perception = self.perceive_image(image_path)
      self.baseline_understanding = perception.understanding

  def check_frame(self, image_path: str) -> dict:
      """Analyze a frame and check for events."""
      perception = self.perceive_image(image_path)

      if self.baseline_understanding:
          prompt = f"""
            Compare current view to baseline:

            BASELINE: {self.baseline_understanding}

            CURRENT: {perception.understanding}

            Identify any significant changes or events. Report:
            1. What changed
            2. Severity (low/medium/high)
            3. Whether to alert
          """

          result = self.think(prompt, [perception])

          # Check if alert needed
          if "alert" in result["response"].lower() and "high" in result["response"].lower():
              self.alert_callback({
                  "type": "visual_event",
                  "analysis": result["response"],
                  "image": image_path
              })

          return result

      return self.think("Describe what you see", [perception])
```

Production Considerations
Multi-modal agents have unique production requirements:

```python
class ProductionMultiModalAgent:
  """
  Production-ready multi-modal agent with safety and efficiency.
  """

  def __init__(self, client, config: dict):
      self.client = client
      self.config = config
      self.rate_limiter = RateLimiter(
          max_requests_per_minute=config.get("rate_limit", 60)
      )
      self.cost_tracker = CostTracker(
          daily_budget=config.get("daily_budget", 100)
      )

  async def safe_perceive(self, content_path: str, modality: str) -> Optional[Perception]:
      """Perceive with safety checks."""
      # Check rate limit
      if not self.rate_limiter.allow():
          return None

      # Check budget
      estimated_cost = self._estimate_perception_cost(modality)
      if not self.cost_tracker.can_spend(estimated_cost):
          return None

      try:
          if modality == "image":
              # Content safety check before processing
              if not await self._is_safe_image(content_path):
                  return None

              perception = self._perceive_image(content_path)

          elif modality == "audio":
              perception = self._perceive_audio(content_path)

          else:
              return None

          self.cost_tracker.record(estimated_cost)
          return perception

      except Exception as e:
          logging.error(f"Perception failed: {e}")
          return None

  async def _is_safe_image(self, image_path: str) -> bool:
      """Check image for safety before processing."""
      # Could use content moderation API
      return True

  def _estimate_perception_cost(self, modality: str) -> float:
      """Estimate cost of perception operation."""
      # gpt-4.1-mini: $0.40/1M input, $1.60/1M output tokens
      # Image at high detail ~765 tokens + ~500 output = ~$0.001-0.002
      # Whisper: $0.006 per minute
      costs = {
          "image": 0.002,  # ~$0.002 per image with gpt-4.1-mini (high detail)
          "audio": 0.006  # ~$0.006 per minute for Whisper
      }
      return costs.get(modality, 0.002)

class RateLimiter:
  """Simple rate limiter."""

  def __init__(self, max_requests_per_minute: int):
      self.max_requests = max_requests_per_minute
      self.requests = []

  def allow(self) -> bool:
      import time
      now = time.time()
      self.requests = [t for t in self.requests if now - t < 60]

      if len(self.requests) >= self.max_requests:
          return False

      self.requests.append(now)
      return True

class CostTracker:
  """Track API costs."""

  def __init__(self, daily_budget: float):
      self.daily_budget = daily_budget
      self.daily_spend = 0.0

  def can_spend(self, amount: float) -> bool:
      return self.daily_spend + amount <= self.daily_budget

  def record(self, amount: float):
      self.daily_spend += amount
```

Common Pitfalls
Unbounded Multi-Modal Calls: Each modality costs money and time. Limit which modalities to engage based on context.

No Content Safety: User-provided images or audio may contain harmful content. Implement safety checks.

Conversation Explosion: Multi-modal history grows fast. Summarize or truncate conversation history.

Tool Overload: Too many tools confuse the agent. Provide focused, relevant tools.

Missing Fallbacks: When image generation fails, have a text description fallback.

Summary
Multi-modal agents perceive, reason, and act across text, images, audio, and video. By registering tools for different modalities, agents can generate images, speak responses, and analyze visual content. This broader action space enables solving problems that require multiple senses.

Production multi-modal agents need rate limiting, cost tracking, content safety checks, and graceful fallbacks. Common patterns include personal assistants that adapt their output modality to user preference and monitoring agents that analyze visual feeds for events.

Key concepts to remember
Multi-modal agents perceive and act across text, images, audio, and video
Tools enable agents to generate images, speak responses, and analyze visual content
Production agents need rate limiting, cost tracking, and content safety checks
Choose output modality based on user context and preference
Implement fallbacks when multi-modal operations fail