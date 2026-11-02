from openai import OpenAI
from dotenv import load_dotenv
import os

load_dotenv()

client = OpenAI(
    base_url=os.getenv("BASE_URL"),
    api_key=os.getenv("API_KEY"),
)

input_text = input("Enter your message: ")

response = client.chat.completions.create(
    model=os.getenv("MODEL"),
    messages=[
        {
            "role": "system",
            "content": "You are a helpful assistant."
        },
        {
            "role": "user",
            "content": input_text
        }
    ],
    extra_body={"think": False}
)

print("Response from the AI:")
for choice in response.choices:
    print(choice.message.content)