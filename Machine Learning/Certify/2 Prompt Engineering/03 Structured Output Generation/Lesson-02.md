## XML and Alternative Formats
When developers first encounter structured output requirements, JSON often seems like the universal solution. However, production systems reveal scenarios where XML, CSV, and markdown formats provide superior solutions to specific challenges. Understanding when and how to use these alternative formats transforms good AI applications into robust systems that handle diverse data requirements with appropriate tools.

This lesson explores the practical implementation of XML, CSV, and markdown output generation, focusing on real-world scenarios where these formats excel beyond JSON capabilities. You will learn to evaluate format requirements, implement robust parsers, and handle the unique challenges each format presents in production environments.

When XML Makes Perfect Sense
XML provides hierarchical structure with rich metadata capabilities that JSON cannot match efficiently. While JSON focuses on data exchange, XML was designed for document representation with semantic meaning embedded in both structure and attributes.

Consider a document management system processing legal contracts. JSON would struggle to preserve styling information, document structure, and metadata relationships that are crucial for compliance systems. XML naturally handles these requirements through attributes, namespaces, and hierarchical relationships.

```python
# Medical records system using XML for rich metadata
from openai import OpenAI
from xml.etree import ElementTree as ET
import re

def generate_patient_record_xml(patient_data, medical_history):
  prompt = f"""
Generate a complete patient medical record in XML format.

Patient Information:
{patient_data}

Medical History:
{medical_history}

Requirements:
- Use attributes for metadata (timestamps, confidentiality levels)
- Separate structure for demographics, medical history, and current status
- Include namespace declarations for medical coding standards
- Preserve relationships between conditions and treatments

Return only valid XML with proper DOCTYPE declaration.
"""

  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
  )

  response = client.chat.completions.create(
      model="gpt-5-mini",
      messages=[{"role": "user", "content": prompt}]
  )

  return parse_and_validate_xml(response.choices[0].message.content)

def parse_and_validate_xml(xml_content):
  try:
      root = ET.fromstring(xml_content)
      # Validate against medical record schema
      return root
  except ET.ParseError as e:
      # Handle malformed XML with recovery strategies
      return repair_xml_structure(xml_content, e)

def repair_xml_structure(xml_content, error):
  """Basic XML repair for common issues"""
  print(f"XML Parse Error: {error}")
  print("Attempting to repair XML structure...")

  # Basic cleanup - remove invalid characters and fix common issues
  cleaned = re.sub(r'[^\x20-\x7E\n\r\t]', '', xml_content)
  cleaned = re.sub(r'&(?!(amp|lt|gt|quot|apos);)', '&amp;', cleaned)

  try:
      return ET.fromstring(cleaned)
  except ET.ParseError:
      print("Failed to repair XML. Returning raw content.")
      return xml_content

# Sample patient data for demonstration
sample_patient_data = "Name: John Smith, Age: 45, DOB: 1979-03-15"
sample_medical_history = "Allergies: Penicillin, Current Medications: Lisinopril 10mg daily"

# Demonstrate XML generation
xml_result = generate_patient_record_xml(sample_patient_data, sample_medical_history)
print("Generated XML:", str(xml_result)[:200] + "...")
```

XML excels in enterprise environments where document structure matters as much as data content. Healthcare systems use XML for HL7 FHIR standards, financial institutions rely on XML for regulatory reporting, and government systems require XML for data interchange standards. The verbosity that makes XML seem inefficient actually provides the semantic clarity these systems require.

The key advantage lies in XML's ability to embed context directly in the document structure. Attributes can carry metadata without affecting the core data hierarchy, namespaces prevent naming conflicts in complex integrations, and schema validation ensures document compliance with industry standards.

CSV for High-Volume Tabular Data
CSV provides optimal efficiency for tabular data with minimal parsing overhead. When dealing with large datasets, financial reports, or bulk data imports, CSV reduces both token usage and processing complexity compared to JSON alternatives.

Database export scenarios demonstrate CSV's strengths clearly. A JSON representation of 10,000 customer records includes repetitive key names that consume tokens without adding value. CSV eliminates this redundancy while maintaining perfect data integrity for tabular structures.

```python
from openai import OpenAI
import csv
import io

# Financial reporting system generating CSV outputs
def generate_quarterly_report_csv(financial_data, metrics):
  prompt = f"""
Generate a quarterly financial report in CSV format.

Financial Data: {financial_data}
Required Metrics: {metrics}

Format Requirements:
- First row must contain column headers
- Use consistent date formatting (YYYY-MM-DD)
- Handle decimal places consistently (2 places for currency)

Return only the CSV content, no additional text.
"""

  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
  )

  response = client.chat.completions.create(
      model="gpt-5-mini",
      messages=[{"role": "user", "content": prompt}]
  )

  return validate_csv_structure(response.choices[0].message.content)

def validate_csv_structure(csv_content):
  try:
      reader = csv.reader(io.StringIO(csv_content))
      rows = list(reader)
      return csv_content if len(rows) > 1 else "Invalid CSV"
  except csv.Error:
      return "CSV parsing failed"

# Sample data
financial_data = "Q3 2024: Revenue $150K, Expenses $120K, Profit $30K"
metrics = "Revenue, Expenses, Profit, Profit Margin"

# Generate and display CSV report
csv_result = generate_quarterly_report_csv(financial_data, metrics)
print("Generated CSV Report:")
print(csv_result)
```

CSV handling requires careful attention to delimiter management, quote escaping, and field consistency. Models sometimes struggle with proper escaping when text fields contain commas or quotes, leading to parsing errors in downstream systems. Successful CSV implementation includes validation for consistent column counts, proper header formatting, and appropriate data type representation.

The format proves particularly valuable for data science workflows, bulk imports, and reporting systems where human readability combines with machine processing efficiency. Modern applications often generate CSV for Excel compatibility while maintaining programmatic access for automated processing.

```python
from openai import OpenAI

# Technical documentation generator using markdown
def generate_api_documentation_markdown(api_spec, examples):
  prompt = f"""
Generate API documentation in markdown format.

API Specification: {api_spec}
Code Examples: {examples}

Structure Requirements:
- Use hierarchical headings (# ## ###) for organization
- Include code blocks with syntax highlighting
- Create tables for parameter descriptions

Return properly formatted markdown with consistent styling.
"""

  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
  )

  response = client.chat.completions.create(
      model="gpt-5-mini",
      messages=[{"role": "user", "content": prompt}]
  )

  return validate_markdown_structure(response.choices[0].message.content)

def validate_markdown_structure(markdown_content):
  # Basic validation for headings
  has_headings = any(line.startswith('#') for line in markdown_content.split('\n'))
  return markdown_content if has_headings else "Invalid markdown structure"

# Sample data
api_spec = "GET /users/{id} - Retrieve user information by ID"
examples = "curl -X GET https://api.example.com/users/123"

# Generate and display markdown documentation
markdown_result = generate_api_documentation_markdown(api_spec, examples)
print("Generated API Documentation:")
print(markdown_result[:300] + "...")
```

Markdown excels in scenarios requiring both automated processing and human editing. Blog platforms generate markdown for content management, project documentation uses markdown for version control compatibility, and reporting systems leverage markdown for readable output that converts to multiple formats.

The format's strength lies in its semantic simplicity combined with extensibility. Basic markdown provides structure for automated parsing while extended syntax supports advanced features like tables, code blocks, and metadata headers. This flexibility makes markdown ideal for content workflows that span human and machine processing.

Choosing the Right Format for Your Use Case
Format selection depends on specific requirements that extend beyond simple data representation. Metadata richness, relationship complexity, human readability needs, validation capabilities, and integration requirements all influence the optimal choice.

XML suits scenarios requiring rich metadata, complex relationships, industry standard compliance, and sophisticated validation. Financial reporting, healthcare records, and government data interchange benefit from XML's semantic capabilities and validation frameworks.

CSV optimizes for high-volume tabular data, minimal parsing overhead, Excel compatibility, and bulk processing workflows. Analytics platforms, financial reports, and data import systems leverage CSV's efficiency for large-scale data movement.

Markdown serves content management, documentation workflows, human-readable reports, and systems requiring dual-purpose output. Technical documentation, blog platforms, and collaborative content creation workflows benefit from markdown's readability and processing capabilities.

Common Pitfalls and Solutions
XML generation often produces malformed documents due to improper attribute quoting, missing closing tags, or invalid character encoding. Implement robust validation using XML parsers that provide specific error locations, enable recovery strategies for common malformation patterns, and use schema validation for complex document structures.