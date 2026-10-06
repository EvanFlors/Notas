## Quiz: Image Generation

Image Generation
You are building a product visualization platform for an e-commerce company. The system generates product images for marketing campaigns, creates variations of existing product photos, and edits images to show products in different settings. You use OpenAI's gpt-image-1-mini API and need to handle 500 image generation requests per hour while maintaining brand consistency and quality.


A seller wants to show their white sneaker on a beach background instead of the studio white background. The original product photo is high quality. What approach should you use?

Generate a completely new image with gpt-image-1-mini describing sneakers on a beach

Use image editing with a mask to replace only the background

Create a variation of the original image

Use gpt-4.1-mini to describe the sneaker, then generate from that description
Correct Answer!
Editing preserves the exact product while changing only the masked background area.

Your prompt 'product photo of headphones' generates inconsistent results. Some images show earbuds, some show over-ear headphones, with varying styles. How do you improve consistency?

Add 'high quality' and 'professional' to the prompt

Specify exact details: 'over-ear wireless headphones, matte black, cushioned ear cups, on white background, product photography lighting'

Generate 10 images and pick the best one

Lower the temperature to reduce randomness
Correct Answer!
Specific details (type, color, features, setting, lighting) reduce ambiguity and improve consistency.

You want to use OpenAI's image editing API to add a logo to a product image. What are the technical requirements for the mask?

The mask should be a JPEG highlighting the logo area in red

The mask must be a PNG with transparent regions indicating where to edit

No mask needed - just describe where to place the logo in the prompt

The mask should be the same size as the logo you want to add
Correct Answer!
OpenAI's image editing API requires PNG masks where transparent pixels mark the editable area.

You need to generate both artistic marketing banners and realistic product mockups. How should you configure the style parameter?

Always use 'vivid' style for more eye-catching results

Always use 'natural' style for more professional results

Use 'vivid' for marketing banners, 'natural' for product mockups

Style doesn't affect output quality, only prompt wording matters
Correct Answer!
Match style to use case: vivid for artistic impact, natural for realistic representation.

Your generation request fails with a content policy violation for a legitimate product (kitchen knives). What is the best production approach?

Retry the same request - content filtering is probabilistic

Rephrase the prompt to emphasize culinary context: 'chef's kitchen knife set for cooking, professional culinary equipment'

Use a different API that doesn't have content restrictions

Remove the product from your catalog since it can't be generated
Correct Answer!
Adding context (culinary, professional) helps the model understand legitimate use.