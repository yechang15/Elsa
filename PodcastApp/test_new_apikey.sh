#!/bin/bash

API_KEY="d79ba916-8a76-4d5e-b9e5-dce9955c973c"

echo "=== 测试新版 API Key ==="
echo ""

echo "测试1: 使用 X-Api-Key header"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -H "X-Api-Key: $API_KEY" \
  -H "X-Api-Resource-Id: seed-tts-2.0" \
  "https://openspeech.bytedance.com/api/v3/tts/bidirection"
echo ""
echo "---"
echo ""

echo "测试2: 使用 Authorization: Bearer"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -H "Authorization: Bearer $API_KEY" \
  -H "X-Api-Resource-Id: seed-tts-2.0" \
  "https://openspeech.bytedance.com/api/v3/tts/bidirection"
echo ""
echo "---"
echo ""

echo "测试3: 使用 X-Api-Access-Key"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -H "X-Api-Access-Key: $API_KEY" \
  -H "X-Api-Resource-Id: seed-tts-2.0" \
  "https://openspeech.bytedance.com/api/v3/tts/bidirection"
echo ""
echo "---"
echo ""

echo "测试4: 使用 api-key query parameter"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -H "X-Api-Resource-Id: seed-tts-2.0" \
  "https://openspeech.bytedance.com/api/v3/tts/bidirection?api-key=$API_KEY"
echo ""
