## Using OpenAI Image Generation API
You need to integrate image generation into your application, but you are not sure how to structure API requests, craft effective prompts, or handle the asynchronous nature of image generation. You have heard that prompt quality dramatically affects results, but you do not know what makes a good prompt. How do you use OpenAI's Image Generation API effectively in production?

OpenAI's Image Generation API provides programmatic access to high-quality image generation. By the end of this lesson, you will understand how to structure image generation API requests, craft effective prompts, tune generation parameters, handle responses, and build production applications that generate images reliably.

Understanding Image Generation API Structure
The Image Generation API uses a simple request-response pattern. You send a text prompt describing the image you want, and the API returns generated images.

| Feature | DALL·E 2 | DALL·E 3 | GPT Image 1 |
|---------|-----------|-----------|--------------|
| Response Format | URL or base64 | URL or base64 | base64 only |
| Image Sizes | 256x256, 512x512, 1024x1024 | 1024x1024, 1792x1024, 1024x1792 | 1024x1024, 1536x1024, 1024x1536, auto |
| Variations | ✅ Supported | ❌ Not supported | ❌ Not supported |
| Inpainting/Editing | ✅ Supported | ❌ Not supported | ✅ Supported |
| Multiple Images (n > 1) | ✅ Up to 10 | ❌ Only n=1 | ✅ Supported |
| Quality Parameter | Not applicable | standard, hd | auto, high, medium, low |

The response_format parameter (to choose URL or base64) is only supported by DALL·E models. GPT Image models always return base64-encoded images.

Basic API Request:

```python
import openai

response = openai.Image.create(
  model="dall-e-3",
  prompt="a futuristic cityscape at sunset with flying cars",
  size="1024x1024",
  n=1,
  response_format="url"  # Only DALL-E models support this parameter
)

image_url = response.data[0].url
print(f"Generated image URL: {image_url}")
```

Try generating an image using DALL·E 2 below. This model returns a URL you can view directly:

OpenAI Image API Basic Example

```python
from openai import OpenAI

client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

response = client.images.generate(
  model="dall-e-3",
  prompt="a futuristic cityscape at sunset with flying cars",
  size="1024x1024",
  n=1,
  response_format="url"  # Only DALL-E models support this parameter
)

image_url = response.data[0].url
print(f"Generated image URL: {image_url}")
```

Output
DALL·E models return image URLs that you can download, display, or store. Images are hosted temporarily (typically for about an hour), so download them if you need persistent access. GPT Image models return base64-encoded images directly in the response.

Prompt Engineering for Image Generation
Prompt quality dramatically affects image generation results. Well-crafted prompts produce significantly better images than vague descriptions.

Effective Prompt Structure:

Good prompts include:

Subject: What is the main subject or focus?
Style: What artistic or visual style?
Composition: How should elements be arranged?
Details: Specific details about colors, lighting, mood
Context: Setting, background, environment
Example Prompts:

Poor Prompt: "a dog"

Better Prompt: "a golden retriever puppy playing in a sunny park, photorealistic, soft natural lighting, shallow depth of field"

Excellent Prompt: "a photorealistic golden retriever puppy playing fetch in a sunny park during golden hour, soft natural lighting, shallow depth of field blurring the background, vibrant green grass, blue sky with white clouds, joyful and energetic mood, high detail, professional photography style"

Prompt Engineering Best Practices:

Be Specific: Include details about style, composition, lighting, mood
Use Descriptive Language: Adjectives and descriptive phrases help guide generation
Specify Style: Mention "photorealistic", "illustration", "watercolor", etc.
Include Composition Details: "close-up", "wide angle", "centered", "rule of thirds"
Describe Lighting: "soft natural light", "dramatic shadows", "golden hour"
Set Mood: "peaceful", "energetic", "mysterious", "cheerful"

```python
def craft_image_prompt(subject, style="photorealistic", mood="neutral", details=None):
  """Craft a well-structured image generation prompt."""
  prompt_parts = [subject]

  # Add style
  prompt_parts.append(f", {style} style")

  # Add mood
  if mood != "neutral":
      prompt_parts.append(f", {mood} mood")

  # Add details
  if details:
      prompt_parts.append(f", {details}")

  # Add quality indicators
  prompt_parts.append(", high quality, detailed")

  return "".join(prompt_parts)

# Example usage
prompt = craft_image_prompt(
  subject="a modern office workspace",
  style="photorealistic",
  mood="productive and organized",
  details="natural lighting, minimalist design, plants, laptop on desk"
)
# Result: "a modern office workspace, photorealistic style, productive and organized mood, natural lighting, minimalist design, plants, laptop on desk, high quality, detailed"
```

API Parameters and Options
The Image Generation API supports several parameters that control generation. Available parameters vary by model:

Model Selection:

dall-e-2: Fast generation, supports variations and editing, returns URLs
dall-e-3: Higher quality, better prompt understanding, returns URLs
gpt-image-1: Latest model with highest quality, returns base64 only
Size Options (vary by model):

DALL·E 2: 256x256, 512x512, 1024x1024
DALL·E 3: 1024x1024, 1792x1024, 1024x1792
GPT Image 1: 1024x1024, 1536x1024, 1024x1536, auto
Quality Settings:

DALL·E 3: standard, hd
GPT Image 1: auto, high, medium, low
Number of Images:

DALL·E 2: n=1 to 10
DALL·E 3: n=1 only
GPT Image 1: n=1 or more

```python
def generate_image_with_options(prompt, size="1024x1024", model="dall-e-3"):
  """Generate image with specific options."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  # Build request parameters based on model
  params = {
      "model": model,
      "prompt": prompt,
      "size": size,
      "n": 1
  }

  # Add response_format only for DALL-E models (not GPT Image models)
  if model.startswith("dall-e"):
      params["response_format"] = "url"

  response = client.images.generate(**params)

  # DALL-E models return URL, GPT Image models return base64
  if model.startswith("dall-e"):
      return response.data[0].url
  else:
      return response.data[0].b64_json  # Base64 encoded image
```

Handling API Responses
Image Generation API responses include image data and metadata. The response format differs by model:

Response Structure:

```python
# DALL-E models return URLs (when response_format="url")
response = client.images.generate(
  model="dall-e-3",
  prompt="a sunset over mountains",
  size="1024x1024",
  response_format="url"
)
print(response.data[0].url)           # Image URL (temporary, ~1 hour)
print(response.data[0].revised_prompt) # How DALL-E 3 interpreted your prompt
print(response.created)                # Timestamp

# GPT Image models always return base64
response = client.images.generate(
  model="gpt-image-1-mini",
  prompt="a sunset over mountains",
  size="1024x1024"
)
print(response.data[0].b64_json)  # Base64 encoded image data
```

Saving Images:

DALL·E URLs are temporary (~1 hour). GPT Image returns base64 directly. Here is how to save both:

```python
import requests
import base64
from pathlib import Path

def save_image_from_url(image_url, save_path):
  """Download and save image from URL (for DALL-E models)."""
  response = requests.get(image_url)
  response.raise_for_status()

  Path(save_path).parent.mkdir(parents=True, exist_ok=True)
  with open(save_path, 'wb') as f:
      f.write(response.content)
  return save_path

def save_image_from_base64(b64_data, save_path):
  """Save base64 encoded image (for GPT Image models)."""
  image_data = base64.b64decode(b64_data)

  Path(save_path).parent.mkdir(parents=True, exist_ok=True)
  with open(save_path, 'wb') as f:
      f.write(image_data)
  return save_path

# Usage with DALL-E (returns URL)
image_url = generate_image_with_options("a cat in space", model="dall-e-3")
save_image_from_url(image_url, "generated_images/cat_space.png")
```

Error Handling:

Handle API errors gracefully:

```python
from openai import OpenAI, APIError, RateLimitError
import time
import logging

logger = logging.getLogger(__name__)

def generate_with_retry(prompt, model="dall-e-3", max_retries=3):
  """Generate image with retry logic."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  for attempt in range(max_retries):
      try:
          params = {
              "model": model,
              "prompt": prompt,
              "size": "1024x1024",
              "n": 1
          }
          # Only DALL-E models support response_format
          if model.startswith("dall-e"):
              params["response_format"] = "url"

          response = client.images.generate(**params)

          # Return appropriate format based on model
          if model.startswith("dall-e"):
              return {"success": True, "url": response.data[0].url}
          else:
              return {"success": True, "b64_json": response.data[0].b64_json}

      except RateLimitError as e:
          wait_time = 2 ** attempt  # Exponential backoff
          logger.warning(f"Rate limit hit, waiting {wait_time}s")
          time.sleep(wait_time)

      except APIError as e:
          if e.status_code in [400, 401, 403]:
              return {"success": False, "error": f"API error: {e.message}"}
          wait_time = 2 ** attempt
          logger.warning(f"API error, retrying in {wait_time}s")
          time.sleep(wait_time)

      except Exception as e:
          return {"success": False, "error": f"Unexpected error: {str(e)}"}

  return {"success": False, "error": "Failed after retries"}
```

Image Variations and Editing
The Image Generation API supports generating variations of existing images:

Three-panel diagram showing an original image, a mask highlighting the editable region, and the edited result
![Mask-based editing changes only a selected region while keeping the rest of the image consistent](https://hrcdn.net/ai-engineering/module-5/light/image-generation-lesson02-mask-based-editing.svg)

Creating Variations:

```python
def create_image_variations(image_path, n=4):
  """Create variations of an existing image."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  with open(image_path, "rb") as image_file:
      response = client.images.create_variation(
          image=image_file,
          n=n,
          size="1024x1024"
      )

  return [item.url for item in response.data]
Image Editing:

Edit specific parts of images using masks:

python
def edit_image(image_path, mask_path, prompt):
  """Edit image using a mask."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  with open(image_path, "rb") as image_file, open(mask_path, "rb") as mask_file:
      response = client.images.edit(
          image=image_file,
          mask=mask_file,
          prompt=prompt,
          n=1,
          size="1024x1024"
      )

  return response.data[0].url
```

Production Implementation Patterns
Building production image generation applications requires careful architecture:

Async Processing:

Image generation takes time. Use async processing:

```python
import asyncio
from openai import AsyncOpenAI

async def generate_image_async(prompt, model="dall-e-3"):
  """Generate image asynchronously."""
  client = AsyncOpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  params = {
      "model": model,
      "prompt": prompt,
      "size": "1024x1024",
      "n": 1
  }
  if model.startswith("dall-e"):
      params["response_format"] = "url"

  response = await client.images.generate(**params)

  if model.startswith("dall-e"):
      return response.data[0].url
  return response.data[0].b64_json

# Process multiple prompts concurrently
async def generate_multiple_images(prompts, model="dall-e-3"):
  """Generate multiple images concurrently."""
  tasks = [generate_image_async(prompt, model) for prompt in prompts]
  return await asyncio.gather(*tasks)
```

Caching:

Cache generated images to avoid redundant API calls:

```python
import hashlib
import json

class ImageGenerationCache:
  """Cache generated images."""

  def __init__(self, cache_backend=None):
      self.cache_backend = cache_backend or {}

  def get_cache_key(self, prompt, size, quality):
      """Generate cache key."""
      key_data = f"{prompt}:{size}:{quality}"
      return hashlib.sha256(key_data.encode()).hexdigest()

  def get(self, prompt, size, quality):
      """Get cached image URL."""
      key = self.get_cache_key(prompt, size, quality)
      return self.cache_backend.get(key)

  def set(self, prompt, size, quality, image_url):
      """Cache image URL."""
      key = self.get_cache_key(prompt, size, quality)
      self.cache_backend[key] = image_url
```

Queue System:

Use queues for high-volume generation:

```python
from queue import Queue
import threading

class ImageGenerationQueue:
  """Queue system for image generation."""

  def __init__(self, worker_count=3):
      self.queue = Queue()
      self.workers = []
      for _ in range(worker_count):
          worker = threading.Thread(target=self._worker)
          worker.start()
          self.workers.append(worker)

  def _worker(self):
      """Worker thread processes queue items."""
      while True:
          item = self.queue.get()
          if item is None:
              break
          try:
              result = generate_with_retry(item['prompt'])
              item['callback'](result)
          except Exception as e:
              item['error_callback'](e)
          finally:
              self.queue.task_done()

  def enqueue(self, prompt, callback, error_callback):
      """Add generation task to queue."""
      self.queue.put({
          'prompt': prompt,
          'callback': callback,
          'error_callback': error_callback
      })
```

Real-World Application Examples
Product Image Generation:

Generate product images for e-commerce:

```python
def generate_product_image(product_name, product_description, style="lifestyle"):
  """Generate product image for e-commerce."""
  prompt = f"""
  {style} product photography of {product_name}.
  {product_description}
  Professional product photography, clean white background,
  studio lighting, high quality, detailed, commercial photography style.
  """

  return generate_with_retry(prompt)

# Usage
image_url = generate_product_image(
  "wireless headphones",
  "modern design, black color, premium materials",
  style="lifestyle"
)
```

Social Media Graphics:

Generate social media graphics:

```python
def generate_social_media_graphic(topic, style="modern", platform="instagram"):
  """Generate social media graphic."""
  size_map = {
      "instagram": "1024x1024",
      "facebook": "1200x630",
      "twitter": "1200x675"
  }

  prompt = f"""
  Social media graphic about {topic}.
  {style} design style, vibrant colors, engaging composition,
  suitable for {platform}, professional graphic design.
  """

  return generate_image_with_options(prompt, size=size_map.get(platform, "1024x1024"))
```

Common Pitfalls and Solutions
Pitfall 1: Vague Prompts

Vague prompts produce generic images. Solution: Include specific details about style, composition, lighting, and mood.

Pitfall 2: Ignoring Revised Prompts

The image generation model revises prompts. Review revised prompts to understand what the model interpreted. Use revised prompts to improve future prompts.

Pitfall 3: Not Handling Rate Limits

Rate limits can cause failures. Solution: Implement retry logic with exponential backoff.

Pitfall 4: Not Downloading Images

Images are hosted temporarily. Solution: Download images immediately for persistent storage.

Pitfall 5: Ignoring Content Policies

Some prompts violate content policies. Solution: Validate prompts before sending, handle policy violations gracefully.

Summary
OpenAI's Image Generation API enables programmatic image generation from text prompts. Effective prompt engineering, proper parameter tuning, and robust error handling enable you to build production applications that generate images reliably.

Understanding API structure, response handling, and production patterns helps you integrate image generation into your applications effectively.

Key concepts to remember
Choose the right model - DALL·E models return URLs, GPT Image models return base64
Use response_format only with DALL·E - This parameter is not supported by GPT Image models
Prompt quality dramatically affects results - Well-crafted prompts with specific details produce better images
Handle responses properly - Download URL images immediately (temporary), decode base64 for GPT Image
Implement retry logic - Rate limits and errors require retry mechanisms
Use async processing - Image generation takes time, use async for better performance