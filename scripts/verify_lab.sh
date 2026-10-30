#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Verification Script for FDE: Add Google Drive with Sensitive Data Protection
# to Gemini Enterprise — Challenge Lab
# ==============================================================================

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
PROJECT_NUM="$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")"
TOKEN="$(gcloud auth print-access-token)"

echo "=== 1. Global ACL Configuration (Task 1) ==="
curl -s -H "Authorization: Bearer ${TOKEN}" -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/aclConfig"
echo -e "\n"

echo "=== 2. Gemini Enterprise App: cymbal-ge-app (Task 1 & 3) ==="
curl -s -H "Authorization: Bearer ${TOKEN}" -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/collections/default_collection/engines/cymbal-ge-app"
echo -e "\n"

echo "=== 3. Google Drive Data Connector: cymbal-gdrive-connector (Task 2 & 5) ==="
curl -s -H "Authorization: Bearer ${TOKEN}" -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/collections/cymbal-gdrive-connector/dataConnector"
echo -e "\n"

echo "=== 4. Sensitive Data Protection Content Policy: cepf-drive-policy (Task 4) ==="
curl -s -H "Authorization: Bearer ${TOKEN}" -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://dlp.googleapis.com/v2/projects/${PROJECT_ID}/locations/global/contentPolicies/cepf-drive-policy"
echo -e "\n"

echo "=== 5. Discovery Engine Service Agent DLP Role (Task 5) ==="
gcloud projects get-iam-policy "${PROJECT_ID}" \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/dlp.user AND bindings.members:service-${PROJECT_NUM}@gcp-sa-discoveryengine.iam.gserviceaccount.com" \
  --format="table(bindings.role, bindings.members)"
echo ""

echo "=== 6. Assistant SDP Configuration (Task 6) ==="
curl -s -H "Authorization: Bearer ${TOKEN}" -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/global/collections/default_collection/engines/cymbal-ge-app/assistants/default_assistant"
echo -e "\n"

echo "=== 7. Gemini Notebook (NotebookLM) SDP Configuration (Task 6) ==="
curl -s -H "Authorization: Bearer ${TOKEN}" -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}"
echo -e "\n"
