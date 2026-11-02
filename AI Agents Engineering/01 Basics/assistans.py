from openai import OpenAI
from dotenv import load_dotenv
import os

load_dotenv()

client = OpenAI(
    base_url=os.getenv("BASE_URL"),
    api_key=os.getenv("API_KEY")
)

print("-" * 50)
print("     Welcome to the AI Chatbot!")
print("-" * 50)

while True:

    input_text = input("You (or type 'exit' to quit): ")

    if input_text.lower() == 'exit':
        print("Exiting the chatbot. Goodbye!")
        break

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

    print(f"AI: {response.choices[0].message.content}")