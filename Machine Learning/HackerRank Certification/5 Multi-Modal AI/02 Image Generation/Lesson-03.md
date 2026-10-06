## Prompt Engineering for Images
You have generated images using OpenAI's Image Generation API, but results are inconsistent. Some prompts produce excellent images while others generate disappointing results. You notice that small changes in wording dramatically affect output quality. How do you systematically craft prompts that produce the images you want?

Prompt engineering for image generation is both an art and a science. Effective prompts guide the model to generate images that match your vision, while poor prompts produce generic or incorrect results. By the end of this lesson, you will understand systematic approaches to prompt engineering, techniques for controlling style and composition, and strategies for optimizing prompts for specific use cases.

The Anatomy of Effective Image Prompts
Effective image prompts follow a structured approach that guides the model through multiple dimensions of image generation.

Core Components:

Subject: What is the main focus or subject?
Style: What artistic or visual style?
Composition: How are elements arranged?
Details: Specific details about colors, lighting, mood, setting
Quality Indicators: Terms that signal desired quality level
Example Breakdown:

Subject: "a golden retriever puppy"

Style: "photorealistic, professional photography"

Composition: "close-up portrait, centered composition, shallow depth of field"

Details: "playing in sunny park, soft natural lighting, golden hour, vibrant green grass, blue sky"

Quality: "high detail, sharp focus, professional quality"

Combined Prompt: "a photorealistic golden retriever puppy, close-up portrait, centered composition, shallow depth of field, playing in sunny park during golden hour, soft natural lighting, vibrant green grass, blue sky with white clouds, high detail, sharp focus, professional photography quality"

Style Control Techniques
Controlling style is crucial for generating images that match your brand, use case, or aesthetic preferences.

Photographic Styles:

"photorealistic, professional photography"
"documentary photography style"
"cinematic lighting, film photography"
"studio photography, clean lighting"
"street photography, candid style"
Artistic Styles:

"watercolor painting, soft colors"
"oil painting, rich textures"
"digital art, vibrant colors"
"minimalist illustration, clean lines"
"sketch style, pencil drawing"
Design Styles:

"modern graphic design, clean composition"
"vintage poster design, retro colors"
"futuristic design, sci-fi aesthetic"
"minimalist design, simple composition"

```python
def apply_style_to_prompt(base_prompt, style):
  """Apply style to base prompt."""
  style_map = {
      "photorealistic": "photorealistic, professional photography, high detail",
      "artistic": "artistic illustration, creative composition, vibrant colors",
      "minimalist": "minimalist design, clean lines, simple composition",
      "cinematic": "cinematic lighting, dramatic composition, film photography style"
  }

  style_description = style_map.get(style, style)
  return f"{base_prompt}, {style_description}"

# Usage
base = "a modern office workspace"
styled = apply_style_to_prompt(base, "photorealistic")
# Result: "a modern office workspace, photorealistic, professional photography, high detail"
```

Composition and Layout Control
Controlling composition helps you generate images with specific layouts and arrangements.

Composition Terms:

"centered composition"
"rule of thirds"
"symmetrical composition"
"asymmetric layout"
"close-up view"
"wide angle view"
"bird's eye view"
"low angle view"
Layout Descriptions:

"horizontal layout"
"vertical composition"
"diagonal composition"
"foreground and background separation"
"layered composition"
Framing:

"tight framing"
"loose framing"
"negative space"
"filled frame"

```python
def add_composition_to_prompt(base_prompt, composition):
  """Add composition guidance to prompt."""
  composition_map = {
      "centered": "centered composition, balanced layout",
      "rule_of_thirds": "rule of thirds composition, dynamic layout",
      "close_up": "close-up view, tight framing, shallow depth of field",
      "wide": "wide angle view, expansive composition, deep depth of field"
  }

  comp_description = composition_map.get(composition, composition)
  return f"{base_prompt}, {comp_description}"

# Usage
base = "a cat"
composed = add_composition_to_prompt(base, "close_up")
# Result: "a cat, close-up view, tight framing, shallow depth of field"
```

Lighting and Mood Control
Lighting and mood dramatically affect image feel and quality.

Lighting Types:

"soft natural lighting"
"dramatic lighting, strong shadows"
"golden hour lighting"
"blue hour lighting"
"studio lighting, even illumination"
"rim lighting, edge glow"
"backlit, silhouette effect"
Mood Descriptors:

"peaceful and serene"
"energetic and dynamic"
"mysterious and moody"
"cheerful and bright"
"dramatic and intense"
"calm and relaxed"
Color Temperature:

"warm tones"
"cool tones"
"neutral colors"
"vibrant colors"
"muted colors"
"high contrast"
"low contrast"

```python
def add_lighting_and_mood(base_prompt, lighting, mood):
  """Add lighting and mood to prompt."""
  lighting_map = {
      "natural": "soft natural lighting, even illumination",
      "dramatic": "dramatic lighting, strong shadows, high contrast",
      "golden": "golden hour lighting, warm tones",
      "studio": "studio lighting, professional illumination"
  }

  mood_map = {
      "peaceful": "peaceful and serene mood",
      "energetic": "energetic and dynamic mood",
      "mysterious": "mysterious and moody atmosphere",
      "cheerful": "cheerful and bright mood"
  }

  lighting_desc = lighting_map.get(lighting, lighting)
  mood_desc = mood_map.get(mood, mood)

  return f"{base_prompt}, {lighting_desc}, {mood_desc}"

# Usage
base = "a mountain landscape"
enhanced = add_lighting_and_mood(base, "golden", "peaceful")
# Result: "a mountain landscape, golden hour lighting, warm tones, peaceful and serene mood"
```

Try experimenting with different prompts to see how style, composition, and lighting affect image generation:

Interactive Prompt Engineering
```python
from openai import OpenAI

client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

# Build your prompt using these components:
subject = "a cozy coffee shop interior"
style = "photorealistic, professional photography"
composition = "wide angle view, rule of thirds"
lighting = "warm natural lighting from large windows"
mood = "peaceful and inviting atmosphere"
details = "wooden furniture, plants, steaming coffee cups"

# Combine components into a full prompt
prompt = f"{subject}, {style}, {composition}, {lighting}, {mood}, {details}"
print(f"Generated prompt:\n{prompt}\n")

# Generate the image (using DALL-E 2 for URL response)
response = client.images.generate(
  model="dall-e-3",
  prompt=prompt,
  size="1024x1024",
  n=1,
  response_format="url"
)

print(f"Image URL: {response.data[0].url}")
```

Use Case-Specific Prompt Patterns
Different use cases require different prompt patterns:

E-commerce Product Images:

Focus on clarity, professional presentation, and product details:

```python
def generate_product_prompt(product_name, product_type, style="lifestyle"):
  """Generate prompt for e-commerce product image."""
  if style == "lifestyle":
      return f"""
      {style} product photography of {product_name}.
      {product_type} shown in natural use context.
      Professional product photography, clean composition,
      natural lighting, high detail, commercial photography style.
      """
  elif style == "studio":
      return f"""
      Studio product photography of {product_name}.
      Clean white background, professional studio lighting,
      product centered, high detail, commercial photography.
      """
  else:
      return f"{product_name}, {style} style, professional photography"
```

Social Media Graphics:

Focus on engagement, brand consistency, and platform optimization:

```python
def generate_social_media_prompt(topic, brand_style, platform):
  """Generate prompt for social media graphic."""
  return f"""
  Social media graphic about {topic}.
  {brand_style} design style, engaging composition,
  vibrant colors, suitable for {platform},
  modern graphic design, professional quality.
  """
```

Concept Visualization:

Focus on clarity, abstraction, and educational value:

```python
def generate_concept_visualization_prompt(concept, style="illustration"):
  """Generate prompt for concept visualization."""
  return f"""
  {style} visualization of {concept}.
  Clear and educational, simplified composition,
  easy to understand, professional illustration style.
  """
```

Advanced Prompt Techniques
Negative Prompts:

Some models support negative prompts that specify what to avoid:

"no text"
"no watermark"
"no blur"
"no distortion"
Iterative Refinement:

Refine prompts based on results:

Start with basic prompt
Generate image
Identify what worked and what did not
Refine prompt based on results
Repeat until satisfied
Prompt Templates:

Create reusable templates for common use cases:

```python
class PromptTemplate:
  """Reusable prompt templates."""

  PRODUCT_PHOTOGRAPHY = """
  {subject}, {style} product photography.
  {composition}, {lighting}, {mood}.
  Professional quality, high detail, commercial photography.
  """

  SOCIAL_MEDIA = """
  Social media graphic about {topic}.
  {style} design, {composition}, {colors}.
  Engaging, {platform}-optimized, professional design.
  """

  @classmethod
  def format(cls, template_name, **kwargs):
      """Format template with variables."""
      template = getattr(cls, template_name)
      return template.format(**kwargs)

# Usage
prompt = PromptTemplate.format(
  "PRODUCT_PHOTOGRAPHY",
  subject="wireless headphones",
  style="lifestyle",
  composition="centered, close-up",
  lighting="natural",
  mood="modern and sleek"
)
```

Common Prompt Mistakes
Mistake 1: Too Vague

Bad: "a dog" Good: "a golden retriever puppy playing in a sunny park, photorealistic, soft natural lighting"

Mistake 2: Too Many Conflicting Instructions

Bad: "a cat that is both realistic and cartoon style, daytime and nighttime, close-up and wide angle" Good: "a photorealistic cat, close-up portrait, daytime, natural lighting"

Mistake 3: Ignoring Style Consistency

Bad: "a modern office, vintage style, futuristic design" Good: "a modern office workspace, contemporary design, minimalist style"

Mistake 4: Not Specifying Quality

Bad: "a landscape" Good: "a mountain landscape, photorealistic, high detail, professional photography quality"

Mistake 5: Overcomplicating

Bad: "a very detailed, extremely high quality, professional, studio-lit, perfectly composed, award-winning photograph of..." Good: "a professional studio photograph of [subject], high detail, clean lighting"

Prompt Optimization Workflow
Systematic prompt optimization improves results:

Step 1: Start Simple

Begin with a basic prompt describing your subject.

Step 2: Add Style

Add style descriptors to guide visual aesthetic.

Step 3: Refine Composition

Specify composition and layout preferences.

Step 4: Enhance Details

Add lighting, mood, and specific details.

Step 5: Test and Iterate

Generate images, evaluate results, refine prompt.

Step 6: Create Variations

Generate multiple variations to find best results.

```python
class PromptOptimizer:
  """Systematic prompt optimization."""

  def optimize(self, base_subject, iterations=5):
      """Iteratively optimize prompt."""
      current_prompt = base_subject
      best_result = None
      best_score = 0

      for i in range(iterations):
          # Generate image
          result = self.generate_image(current_prompt)

          # Evaluate (simplified - use actual evaluation in production)
          score = self.evaluate_result(result)

          if score > best_score:
              best_score = score
              best_result = result
              # Refine prompt based on what worked
              current_prompt = self.refine_prompt(current_prompt, result)

      return best_result, current_prompt

  def refine_prompt(self, prompt, result):
      """Refine prompt based on result."""
      # Analyze what worked and enhance those aspects
      # This is simplified - actual implementation would analyze image
      return f"{prompt}, enhanced details, improved composition"
```

Summary
Effective prompt engineering for image generation requires understanding how to structure prompts, control style and composition, and optimize for specific use cases. Systematic approaches to prompt crafting produce significantly better results than ad-hoc descriptions.

Key techniques include specifying subject, style, composition, lighting, mood, and quality indicators. Use case-specific patterns help you generate appropriate images for different applications.

Key concepts to remember
Structure prompts systematically - Include subject, style, composition, details, and quality indicators
Control style explicitly - Specify photographic, artistic, or design styles
Guide composition - Use composition terms to control layout and framing
Set lighting and mood - Lighting and mood dramatically affect image feel
Iterate and refine - Test prompts, evaluate results, and refine based on what works
Test across models - DALL·E 3 may interpret prompts differently than DALL·E 2 or GPT Image models
Further learning resources