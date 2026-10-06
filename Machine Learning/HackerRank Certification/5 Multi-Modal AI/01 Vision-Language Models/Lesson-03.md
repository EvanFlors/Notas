## Structured Data Extraction from Images
One of the most valuable applications of vision-language models is extracting structured data from images. Unlike simple descriptions, structured extraction produces data your application can process programmatically. This transforms images into actionable information for downstream systems.

The key to reliable structured extraction is combining precise prompts with JSON mode. By specifying exact field names, data types, and validation rules, you guide the model toward consistent, parseable output.

```python
from openai import OpenAI
from pydantic import BaseModel, Field
from typing import Optional
import json

client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

class ReceiptData(BaseModel):
  """Structured receipt information."""
  merchant_name: str = Field(description="Name of the business")
  date: str = Field(description="Transaction date in YYYY-MM-DD format")
  total_amount: float = Field(description="Total amount paid")
  currency: str = Field(description="Currency code like USD, EUR")
  items: list[dict] = Field(description="List of items with name and price")
  payment_method: Optional[str] = Field(description="How payment was made")
  tax_amount: Optional[float] = Field(description="Tax amount if shown")

def extract_receipt_data(image_url: str) -> ReceiptData:
  """Extract structured data from a receipt image."""

  extraction_prompt = """Analyze this receipt image and extract the following information.

  Return a JSON object with these fields:
  - merchant_name: The business name on the receipt
  - date: Transaction date in YYYY-MM-DD format
  - total_amount: The total amount as a number (no currency symbols)
  - currency: Currency code (USD, EUR, GBP, etc.)
  - items: Array of objects with "name" and "price" for each line item
  - payment_method: How the customer paid (card, cash, etc.) or null if not shown
  - tax_amount: Tax amount as a number, or null if not itemized

  If any field cannot be determined from the image, use null.
  Ensure all numeric values are actual numbers, not strings."""

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {"type": "text", "text": extraction_prompt},
                  {
                      "type": "image_url",
                      "image_url": {"url": image_url, "detail": "high"}
                  }
              ]
          }
      ],
      max_tokens=1000,
      response_format={"type": "json_object"}
  )

  data = json.loads(response.choices[0].message.content)
  return ReceiptData(**data)

# Example: Business card extraction
class BusinessCardData(BaseModel):
  name: str
  title: Optional[str]
  company: Optional[str]
  email: Optional[str]
  phone: Optional[str]
  address: Optional[str]

def extract_business_card(image_url: str) -> BusinessCardData:
  """Extract contact information from a business card."""

  prompt = """Extract contact information from this business card image.

  Return JSON with these fields (use null if not present):
  - name: Person's full name
  - title: Job title
  - company: Company name
  - email: Email address
  - phone: Phone number (preserve original formatting)
  - address: Physical address if shown"""

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {"type": "text", "text": prompt},
                  {"type": "image_url", "image_url": {"url": image_url, "detail": "high"}}
              ]
          }
      ],
      response_format={"type": "json_object"}
  )

  return BusinessCardData(**json.loads(response.choices[0].message.content))
```

Document Processing and OCR
Vision-language models excel at document processing because they combine text extraction with contextual understanding. Traditional OCR extracts text character by character without understanding meaning. VLMs understand document structure, can correct errors based on context, and extract semantic information.

When processing documents, high detail mode is essential for accurate text recognition. Consider the document type and structure when crafting your prompt.

```python
def process_form_document(image_url: str) -> dict:
  """
  Process a form document and extract field-value pairs.
  Handles various form layouts intelligently.
  """
  prompt = """Analyze this form document image.

  Extract all field-value pairs from the form. For each field:
  1. Identify the field label/question
  2. Extract the filled-in or selected value
  3. Note if a field appears empty or illegible

  Return JSON with this structure:
  {
      "form_title": "Title of the form if visible",
      "fields": [
          {"label": "Field name", "value": "Extracted value", "confidence": "high/medium/low"},
          ...
      ],
      "checkboxes": [
          {"label": "Option text", "checked": true/false},
          ...
      ],
      "notes": "Any observations about form completeness or legibility"
  }

  For handwritten text, extract as accurately as possible and mark confidence as medium or low.
  For illegible sections, set value to null and note in the observations."""

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {"type": "text", "text": prompt},
                  {"type": "image_url", "image_url": {"url": image_url, "detail": "high"}}
              ]
          }
      ],
      response_format={"type": "json_object"}
  )

  return json.loads(response.choices[0].message.content)

def extract_table_data(image_url: str) -> dict:
  """Extract structured data from a table in an image."""

  prompt = """This image contains a table. Extract the table data.

  Return JSON with:
  {
      "headers": ["Column 1", "Column 2", ...],
      "rows": [
          ["Value 1", "Value 2", ...],
          ...
      ],
      "table_title": "Title if present, otherwise null"
  }

  Preserve the exact order of columns and rows as they appear.
  For merged cells, repeat the value in each covered position.
  For empty cells, use empty string ""."""

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {"type": "text", "text": prompt},
                  {"type": "image_url", "image_url": {"url": image_url, "detail": "high"}}
              ]
          }
      ],
      response_format={"type": "json_object"}
  )

  return json.loads(response.choices[0].message.content)
```

Multi-Turn Visual Conversations
Vision-language models maintain context across conversation turns, enabling iterative exploration of images. You can ask follow-up questions, request clarification, or drill into specific details without resending the image.

This capability is powerful for interactive applications where users explore visual content through natural conversation. The model remembers what it has seen and discussed, building on previous analysis.

```python
class VisualConversation:
  """Manage multi-turn conversations about images."""

  def __init__(self, model: str = "gpt-4.1-mini"):
      self.client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)
      self.model = model
      self.messages = []

  def add_image(self, image_url: str, initial_prompt: str) -> str:
      """Start a conversation with an image."""
      self.messages.append({
          "role": "user",
          "content": [
              {"type": "text", "text": initial_prompt},
              {"type": "image_url", "image_url": {"url": image_url}}
          ]
      })

      response = self.client.chat.completions.create(
          model=self.model,
          messages=self.messages,
          max_tokens=1000
      )

      assistant_message = response.choices[0].message.content
      self.messages.append({"role": "assistant", "content": assistant_message})

      return assistant_message

  def ask_followup(self, question: str) -> str:
      """Ask a follow-up question about the image."""
      self.messages.append({"role": "user", "content": question})

      response = self.client.chat.completions.create(
          model=self.model,
          messages=self.messages,
          max_tokens=1000
      )

      assistant_message = response.choices[0].message.content
      self.messages.append({"role": "assistant", "content": assistant_message})

      return assistant_message

  def reset(self):
      """Clear conversation history."""
      self.messages = []

# Example usage
conversation = VisualConversation()

# Start with an architecture diagram
response = conversation.add_image(
  diagram_url,
  "Describe the main components in this system architecture diagram."
)
print(response)

# Ask follow-up questions
response = conversation.ask_followup(
  "What database technology is shown? How does it connect to the application layer?"
)
print(response)

response = conversation.ask_followup(
  "Are there any potential bottlenecks or single points of failure you can identify?"
)
print(response)
```

Specialized Analysis Patterns
Different types of visual content benefit from specialized analysis approaches. Here are patterns for common use cases:

Technical Diagrams: When analyzing flowcharts, architecture diagrams, or technical drawings, ask the model to identify components, connections, and data flows systematically.

```python
def analyze_architecture_diagram(image_url: str) -> dict:
  """Analyze a software architecture diagram."""

  prompt = """Analyze this software architecture diagram comprehensively.

  Extract and return JSON with:
  {
      "components": [
          {"name": "Component name", "type": "service/database/queue/etc", "description": "Brief description"}
      ],
      "connections": [
          {"from": "Source component", "to": "Target component", "type": "sync/async/data flow", "protocol": "HTTP/gRPC/etc if shown"}
      ],
      "external_services": ["List of external/third-party services"],
      "data_stores": ["List of databases, caches, or storage systems"],
      "potential_issues": ["Any architectural concerns like single points of failure, missing redundancy, etc"],
      "summary": "One paragraph overview of the architecture"
  }"""

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {"type": "text", "text": prompt},
                  {"type": "image_url", "image_url": {"url": image_url, "detail": "high"}}
              ]
          }
      ],
      response_format={"type": "json_object"}
  )

  return json.loads(response.choices[0].message.content)

def analyze_ui_screenshot(image_url: str) -> dict:
  """Analyze a UI screenshot for UX review."""

  prompt = """Analyze this UI screenshot from a UX perspective.

  Return JSON with:
  {
      "screen_type": "What kind of screen is this (login, dashboard, settings, etc)",
      "elements": [
          {"type": "button/input/text/image/etc", "label": "visible text", "location": "top/center/bottom + left/center/right"}
      ],
      "user_flow": "What action is the user likely trying to accomplish here",
      "accessibility_concerns": ["Any potential accessibility issues"],
      "ux_suggestions": ["Potential improvements to user experience"],
      "visual_hierarchy": "Assessment of how well the design guides user attention"
  }"""

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {"type": "text", "text": prompt},
                  {"type": "image_url", "image_url": {"url": image_url}}
              ]
          }
      ],
      response_format={"type": "json_object"}
  )

  return json.loads(response.choices[0].message.content)
```

Handling Ambiguous or Uncertain Results
Vision models may produce uncertain results when images are unclear, partially visible, or contain ambiguous content. Building robust applications requires acknowledging and handling this uncertainty.

```python
def analyze_with_confidence(image_url: str, task_prompt: str) -> dict:
  """
  Perform image analysis with explicit confidence assessment.

  The model reports its confidence level, enabling your application
  to handle uncertain results appropriately.
  """

  augmented_prompt = f"""{task_prompt}

Additionally, assess your confidence in the analysis:
- confidence_level: "high", "medium", or "low"
- confidence_factors: What made you certain or uncertain
- ambiguous_elements: List any parts of the image that were unclear

Include these assessments in your JSON response."""

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {"type": "text", "text": augmented_prompt},
                  {"type": "image_url", "image_url": {"url": image_url}}
              ]
          }
      ],
      response_format={"type": "json_object"}
  )

  result = json.loads(response.choices[0].message.content)

  # Application logic based on confidence
  if result.get("confidence_level") == "low":
      result["requires_human_review"] = True

  return result

def verify_extraction(image_url: str, extracted_data: dict) -> dict:
  """
  Verify previously extracted data by asking the model to confirm.
  Useful for critical data where accuracy is essential.
  """

  verification_prompt = f"""I previously extracted this data from an image:
{json.dumps(extracted_data, indent=2)}

Please look at the image again and verify each field:
1. Mark each field as "correct", "incorrect", or "uncertain"
2. For incorrect fields, provide the corrected value
3. For uncertain fields, explain what is unclear

Return JSON with:
{{
  "verifications": {{
      "field_name": {{"status": "correct/incorrect/uncertain", "corrected_value": "if incorrect", "note": "if uncertain"}}
  }},
  "overall_accuracy": "high/medium/low",
  "recommended_action": "accept/review/reject"
}}"""

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {"type": "text", "text": verification_prompt},
                  {"type": "image_url", "image_url": {"url": image_url, "detail": "high"}}
              ]
          }
      ],
      response_format={"type": "json_object"}
  )

  return json.loads(response.choices[0].message.content)
```

Common Pitfalls
Over-Trusting Text Extraction: VLMs can misread characters, especially in stylized fonts, poor quality images, or small text. Always validate critical extracted text.

Ignoring Context in Structured Extraction: Without domain context, the model may misinterpret field meanings. A "date" field could be birth date, expiration date, or transaction date. Be specific.

Large Document Processing: Very large documents or dense multi-page PDFs may exceed practical limits. Consider breaking documents into pages or sections.

Inconsistent JSON Structure: Without careful prompt engineering, JSON output structure may vary between requests. Use explicit field definitions and validation.

Summary
Advanced image understanding transforms visual content into actionable data through structured extraction, document processing, and specialized analysis patterns. Multi-turn conversations enable iterative exploration of images, while confidence assessment helps handle uncertainty in production applications.

The combination of high-detail image processing, precise prompts, and JSON mode output enables reliable extraction of structured data from receipts, forms, business cards, and technical documents. Specialized prompts tailored to specific content types like architecture diagrams or UI screenshots produce more accurate and useful analysis.

Key concepts to remember

Combine precise prompts with JSON mode for reliable structured data extraction
Use high detail mode for document processing and OCR tasks
Multi-turn conversations enable iterative image exploration without resending images
Include confidence assessment in prompts to handle uncertainty appropriately
Tailor analysis patterns to specific content types for better results
Further learning resources