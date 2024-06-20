#!/bin/bash

ENDPOINT="https://api.openai.com/v1/chat/completions"

# Read from stdin
INPUT=$(cat)
# Define the request payload
PAYLOAD=$(jq -n --arg content "$INPUT" '{
  model: "gpt-3.5-turbo",
  messages: [
    {role: "user", content: $content}
  ]
}')


# Send the request to OpenAI API and print the response
curl -s $ENDPOINT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$PAYLOAD" | jq -r '.choices[0].message.content'
