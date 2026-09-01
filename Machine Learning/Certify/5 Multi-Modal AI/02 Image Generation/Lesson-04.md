## Image Generation Applications
You understand how to generate images using OpenAI's Image Generation API and craft effective prompts. Now you need to build a production application that generates images at scale, handles errors gracefully, manages costs effectively, and ensures content quality. How do you architect such a system? What patterns should you follow?

Building production image generation applications requires careful consideration of architecture, cost management, content moderation, and scalability. By the end of this lesson, you will understand how to structure production image generation systems, implement cost optimization strategies, handle content moderation, and deploy applications that generate images reliably at scale.

Application Architecture Patterns
Production image generation applications require architectures that handle asynchronous processing, error recovery, and scalability.

Service Layer Architecture:

Structure your application in layers:

```python
# Layer 1: Prompt Processing
class PromptProcessor:
  """Process and optimize prompts."""

  def validate_prompt(self, prompt):
      """Validate prompt for content policy compliance."""
      pass

  def optimize_prompt(self, prompt):
      """Optimize prompt for better results."""
      pass

# Layer 2: Image Generation Service
class ImageGenerationService:
  """Handle image generation API calls."""

  def generate(self, prompt, options):
      """Generate image with retry logic."""
      pass

  def download_image(self, url):
      """Download generated image."""
      pass

# Layer 3: Storage and Delivery
class ImageStorage:
  """Handle image storage and delivery."""

  def store_image(self, image_data, metadata):
      """Store generated image."""
      pass

  def get_image_url(self, image_id):
      """Get URL for stored image."""
      pass

# Layer 4: Application Logic
class ImageGenerationApp:
  """Main application orchestrating image generation."""

  def __init__(self):
      self.prompt_processor = PromptProcessor()
      self.generation_service = ImageGenerationService()
      self.storage = ImageStorage()

  def generate_and_store(self, prompt, options):
      """Generate image and store result."""
      # Validate and optimize prompt
      processed_prompt = self.prompt_processor.optimize_prompt(prompt)

      # Generate image
      result = self.generation_service.generate(processed_prompt, options)

      # Download and store
      image_data = self.generation_service.download_image(result['url'])
      stored_image = self.storage.store_image(image_data, {
          'prompt': processed_prompt,
          'options': options
      })

      return stored_image
```

Async Processing Architecture:

Use async processing for better performance:

```python
import asyncio
from openai import AsyncOpenAI

class AsyncImageGenerator:
  """Async image generation service."""

  def __init__(self, model="gpt-image-1-mini"):
      self.client = AsyncOpenAI(
          api_key="API_KEY",
          base_url="BASE_URL",
      )
      self.model = model
      self.semaphore = asyncio.Semaphore(10)  # Limit concurrent requests

  async def generate(self, prompt, options):
      """Generate image asynchronously with concurrency control."""
      async with self.semaphore:
          try:
              params = {
                  "model": self.model,
                  "prompt": prompt,
                  "size": options.get('size', '1024x1024'),
                  "n": 1
              }

              # Only DALL-E models support response_format parameter
              if self.model.startswith("dall-e"):
                  params["response_format"] = "url"

              response = await self.client.images.generate(**params)

              # Handle different response formats
              if self.model.startswith("dall-e"):
                  return {
                      'success': True,
                      'url': response.data[0].url,
                      'revised_prompt': getattr(response.data[0], 'revised_prompt', None)
                  }
              else:
                  # GPT Image models return base64
                  return {
                      'success': True,
                      'b64_json': response.data[0].b64_json
                  }
          except Exception as e:
              return {'success': False, 'error': str(e)}

  async def generate_batch(self, prompts, options):
      """Generate multiple images concurrently."""
      tasks = [self.generate(prompt, options) for prompt in prompts]
      return await asyncio.gather(*tasks)
```

Cost Optimization Strategies
Image generation can be expensive. Implement cost optimization strategies:

Prompt Caching:

Cache generated images to avoid redundant generation:

```python
import hashlib
import json

class ImageCache:
  """Cache generated images."""

  def __init__(self, storage_backend):
      self.storage = storage_backend

  def get_cache_key(self, prompt, options):
      """Generate cache key."""
      key_data = json.dumps({
          'prompt': prompt,
          'size': options.get('size'),
          'quality': options.get('quality')
      }, sort_keys=True)
      return hashlib.sha256(key_data.encode()).hexdigest()

  def get(self, prompt, options):
      """Get cached image."""
      key = self.get_cache_key(prompt, options)
      return self.storage.get(key)

  def set(self, prompt, options, image_data):
      """Cache image."""
      key = self.get_cache_key(prompt, options)
      self.storage.set(key, image_data)
```

Batch Optimization:

Optimize batch processing to reduce costs:

```python
class BatchOptimizer:
  """Optimize batch image generation."""

  def optimize_batch(self, prompts):
      """Optimize batch by deduplicating and caching."""
      # Check cache first
      cached_results = {}
      uncached_prompts = []

      for prompt in prompts:
          cached = self.cache.get(prompt)
          if cached:
              cached_results[prompt] = cached
          else:
              uncached_prompts.append(prompt)

      # Generate only uncached prompts
      if uncached_prompts:
          new_results = self.generate_batch(uncached_prompts)
          # Cache new results
          for prompt, result in zip(uncached_prompts, new_results):
              self.cache.set(prompt, result)
              cached_results[prompt] = result

      return cached_results
```

Quality vs. Cost Trade-offs:

Choose appropriate quality settings:

```python
def select_quality_setting(use_case, budget_constraints):
  """Select quality setting based on use case."""
  quality_map = {
      'thumbnail': {'quality': 'standard', 'size': '512x512'},
      'social_media': {'quality': 'standard', 'size': '1024x1024'},
      'print': {'quality': 'hd', 'size': '1024x1024'},
      'preview': {'quality': 'standard', 'size': '1024x1024'}
  }

  if budget_constraints == 'low':
      return {'quality': 'standard', 'size': '1024x1024'}

  return quality_map.get(use_case, {'quality': 'standard', 'size': '1024x1024'})
```

Content Moderation
Implement content moderation to ensure generated images meet quality and policy standards:

Prompt Validation:

Validate prompts before generation:

```python
class ContentModerator:
  """Moderate content before and after generation."""

  FORBIDDEN_TERMS = ['explicit', 'violence', 'hate']  # Simplified

  def validate_prompt(self, prompt):
      """Validate prompt for policy compliance."""
      prompt_lower = prompt.lower()
      for term in self.FORBIDDEN_TERMS:
          if term in prompt_lower:
              return {
                  'valid': False,
                  'reason': f'Contains forbidden term: {term}'
              }
      return {'valid': True}

  def moderate_image(self, image_url):
      """Moderate generated image."""
      # In production, use image moderation API
      # This is simplified
      return {'approved': True}
```

Post-Generation Review:

Review generated images:

```python
class ImageReviewer:
  """Review generated images."""

  def review(self, image_url, prompt):
      """Review image for quality and compliance."""
      # Check image quality
      quality_score = self.assess_quality(image_url)

      # Check compliance
      compliance = self.check_compliance(image_url, prompt)

      return {
          'approved': quality_score > 0.7 and compliance['approved'],
          'quality_score': quality_score,
          'compliance': compliance
      }
```

Error Handling and Resilience
Implement comprehensive error handling:

Retry Logic:

```python
import time
from openai import RateLimitError, APIError

class ResilientImageGenerator:
  """Image generator with error handling."""

  def generate_with_retry(self, prompt, options, max_retries=3):
      """Generate with retry logic."""
      for attempt in range(max_retries):
          try:
              return self.generate(prompt, options)
          except RateLimitError as e:
              wait_time = 2 ** attempt
              time.sleep(wait_time)
          except APIError as e:
              if e.status_code in [400, 401, 403]:
                  raise  # Don't retry on these errors
              wait_time = 2 ** attempt
              time.sleep(wait_time)

      raise Exception("Failed after retries")
```

Fallback Strategies:

Implement fallbacks when generation fails:

```python
class ImageGeneratorWithFallback:
  """Generator with fallback strategies."""

  def generate_with_fallback(self, prompt, options):
      """Generate with fallback options."""
      try:
          # Try primary generation
          return self.primary_generator.generate(prompt, options)
      except Exception as e:
          # Fallback 1: Try with simplified prompt
          try:
              simplified = self.simplify_prompt(prompt)
              return self.primary_generator.generate(simplified, options)
          except Exception:
              # Fallback 2: Use cached similar image
              similar = self.find_similar_cached(prompt)
              if similar:
                  return similar
              # Fallback 3: Return error
              raise
```

Monitoring and Observability
Monitor image generation applications:

Key Metrics:

Generation success rate
Average generation time
Cost per image
Cache hit rate
Error rates by type
Logging:

```python
import logging
import time

logger = logging.getLogger(__name__)

class MonitoredImageGenerator:
  """Image generator with monitoring."""

  def generate_with_monitoring(self, prompt, options):
      """Generate with logging and metrics."""
      start_time = time.time()

      try:
          result = self.generate(prompt, options)

          latency = time.time() - start_time
          logger.info(f"Image generated successfully: {latency:.2f}s")

          # Record metrics
          self.record_metric('success', 1)
          self.record_metric('latency', latency)
          self.record_metric('cost', self.calculate_cost(options))

          return result

      except Exception as e:
          latency = time.time() - start_time
          logger.error(f"Image generation failed: {e} ({latency:.2f}s)")

          self.record_metric('error', 1)
          self.record_metric('error_type', type(e).__name__)

          raise
```

Deployment Strategies
Queue-Based Processing:

Use queues for high-volume generation:

```python
from queue import Queue
import threading

class ImageGenerationQueue:
  """Queue-based image generation."""

  def __init__(self, worker_count=5):
      self.queue = Queue()
      self.workers = []
      for _ in range(worker_count):
          worker = threading.Thread(target=self._worker)
          worker.start()
          self.workers.append(worker)

  def _worker(self):
      """Worker processes queue items."""
      while True:
          item = self.queue.get()
          if item is None:
              break
          try:
              result = self.generate(item['prompt'], item['options'])
              item['callback'](result)
          except Exception as e:
              item['error_callback'](e)
          finally:
              self.queue.task_done()

  def enqueue(self, prompt, options, callback, error_callback):
      """Add generation task."""
      self.queue.put({
          'prompt': prompt,
          'options': options,
          'callback': callback,
          'error_callback': error_callback
      })
```

Webhook Notifications:

Notify when generation completes:

```python
import requests

class WebhookNotifier:
  """Notify via webhook when generation completes."""

  def notify_completion(self, webhook_url, result):
      """Send webhook notification."""
      try:
          requests.post(webhook_url, json={
              'status': 'completed',
              'image_url': result['url'],
              'prompt': result['prompt']
          })
      except Exception as e:
          logger.error(f"Webhook notification failed: {e}")
```

Real-World Application Examples
E-commerce Product Image Generation:

```python
class ProductImageGenerator:
  """Generate product images for e-commerce."""

  def generate_product_image(self, product):
      """Generate product image."""
      prompt = self.build_product_prompt(product)

      # Validate prompt
      if not self.moderator.validate_prompt(prompt)['valid']:
          raise ValueError("Invalid prompt")

      # Generate with caching
      cached = self.cache.get(prompt, {'size': '1024x1024'})
      if cached:
          return cached

      # Generate new image
      result = self.generator.generate(prompt, {
          'size': '1024x1024',
          'quality': 'standard'
      })

      # Download and store
      image_data = self.download_image(result['url'])
      stored = self.storage.store(image_data, {
          'product_id': product['id'],
          'prompt': prompt
      })

      # Cache result
      self.cache.set(prompt, {'size': '1024x1024'}, stored)

      return stored
```

Social Media Content Generation:

```python
class SocialMediaImageGenerator:
  """Generate social media images."""

  def generate_for_post(self, post_content, platform):
      """Generate image for social media post."""
      prompt = self.build_social_prompt(post_content, platform)

      # Generate asynchronously
      result = await self.async_generator.generate(prompt, {
          'size': self.get_platform_size(platform),
          'quality': 'standard'
      })

      # Store and return
      return self.storage.store_and_get_url(result['url'])
```

Summary
Building production image generation applications requires careful architecture, cost optimization, content moderation, and error handling. By structuring applications in layers, implementing caching and batch optimization, moderating content, and handling errors gracefully, you can build reliable image generation systems.

Monitoring, logging, and deployment strategies ensure applications scale and remain reliable in production environments.

Key concepts to remember
Layer your architecture - Separate prompt processing, generation, storage, and application logic
Handle model differences - DALL·E models return URLs, GPT Image models return base64
Optimize costs - Cache results, batch process, choose appropriate quality settings
Moderate content - Validate prompts and review generated images
Handle errors gracefully - Implement retries, fallbacks, and comprehensive error handling
Monitor and observe - Track metrics, log comprehensively, monitor costs and performance
Further learning resources