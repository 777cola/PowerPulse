#!/bin/bash
cd "$(dirname "$0")"

TOKEN="***REDACTED***"
REPO="777cola/PowerPulse"

echo "Creating release..."
RELEASE_JSON=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/releases" \
  -d @release_body.json)

RELEASE_ID=$(echo "$RELEASE_JSON" | jq -r '.id')
UPLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.upload_url' | sed 's/{.*}//')

echo "Release ID: $RELEASE_ID"
echo "Upload URL: $UPLOAD_URL"

if [ "$RELEASE_ID" = "null" ] || [ -z "$RELEASE_ID" ]; then
  echo "Failed to create release:"
  echo "$RELEASE_JSON" | jq .
  exit 1
fi

echo ""
echo "Uploading DMG..."
UPLOAD_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/octet-stream" \
  "${UPLOAD_URL}?name=PowerPulse-Installer.dmg" \
  --data-binary @PowerPulse-Installer.dmg)

echo "$UPLOAD_RESPONSE" | jq '.name, .state, .browser_download_url'

echo ""
echo "Done!"
