#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# FDE: Add Google Drive with Sensitive Data Protection to Gemini Enterprise
# End-to-End Automation Script (Tasks 1 - 6)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
PROJECT_NUM="$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")"
LOCATION="global"
APP_ID="cymbal-ge-app"
CONNECTOR_ID="cymbal-gdrive-connector"
DATA_STORE_ID="cymbal-gdrive-connector_google_drive"
POLICY_ID="cepf-drive-policy"
LABEL_ID="${1:-OiQWm4osiQYvIPl6oW6sZqALpOoNtv8zCP7RNNEbbFcb}"
POLICY_RESOURCE="projects/${PROJECT_ID}/locations/${LOCATION}/contentPolicies/${POLICY_ID}"

echo "=================================================================="
echo "Project ID     : ${PROJECT_ID}"
echo "Project Number : ${PROJECT_NUM}"
echo "Location       : ${LOCATION}"
echo "Drive Label ID : ${LABEL_ID}"
echo "=================================================================="

echo "[Step 0] Enabling required Google Cloud APIs..."
gcloud services enable \
  discoveryengine.googleapis.com \
  dlp.googleapis.com \
  drive.googleapis.com \
  docs.googleapis.com \
  drivelabels.googleapis.com \
  admin.googleapis.com \
  --project="${PROJECT_ID}"

TOKEN="$(gcloud auth print-access-token)"

# ------------------------------------------------------------------------------
# Task 1: Configure Google Identity for global location
# ------------------------------------------------------------------------------
echo "[Task 1] Configuring Google Identity (GSUITE) for global location..."
curl -s -X PATCH \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION}/aclConfig" \
  -d '{
    "idpConfig": {
      "idpType": "GSUITE"
    }
  }' > /dev/null

# ------------------------------------------------------------------------------
# Task 2: Set up Google Drive Connector (Federated + Actions)
# ------------------------------------------------------------------------------
echo "[Task 2] Setting up Google Drive connector (${CONNECTOR_ID})..."
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION}:setUpDataConnector" \
  -d "{
    \"collectionId\": \"${CONNECTOR_ID}\",
    \"collectionDisplayName\": \"${CONNECTOR_ID}\",
    \"dataConnector\": {
      \"dataSource\": \"google_drive\",
      \"entities\": [
        {
          \"entityName\": \"google_drive\"
        }
      ],
      \"connectorModes\": [
        \"FEDERATED\",
        \"ACTIONS\"
      ]
    }
  }" > /dev/null || true

echo "[Task 2] Waiting for data connector (${CONNECTOR_ID}) to become ACTIVE..."
for i in {1..30}; do
  STATE=$(curl -s -H "Authorization: Bearer ${TOKEN}" -H "X-Goog-User-Project: ${PROJECT_ID}" \
    "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/${LOCATION}/collections/${CONNECTOR_ID}/dataConnector" \
    | python3 -c "import sys, json; print(json.load(sys.stdin).get('state', ''))" 2>/dev/null || true)
  if [[ "${STATE}" == "ACTIVE" ]]; then
    echo "  Connector state is ACTIVE."
    break
  fi
  sleep 5
done

echo "[Task 2] Enabling all supported Google Drive actions on ${CONNECTOR_ID}..."
curl -s -X PATCH \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/${LOCATION}/collections/${CONNECTOR_ID}/dataConnector?updateMask=bapConfig,actionConfig" \
  -d '{
    "actionConfig": {
      "createBapConnection": true
    },
    "bapConfig": {
      "supportedConnectorModes": ["ACTIONS"],
      "enabledActions": [
        "search_drive_tool",
        "copy_file",
        "create_file",
        "download_file_content",
        "get_cell_values",
        "get_file_metadata",
        "get_file_permissions",
        "get_spreadsheet",
        "insert_dimension",
        "list_recent_files",
        "list_shared_drives",
        "read_document",
        "read_file_content",
        "read_presentation",
        "search_files",
        "share_file",
        "trash_file",
        "update_cell_values",
        "update_file",
        "update_formulas"
      ]
    }
  }' > /dev/null

# ------------------------------------------------------------------------------
# Task 1 & Task 3: Create Gemini Enterprise App & Connect Data Store
# ------------------------------------------------------------------------------
echo "[Task 1 & 3] Creating Gemini Enterprise app (${APP_ID}) connected to ${DATA_STORE_ID}..."
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION}/collections/default_collection/engines?engineId=${APP_ID}" \
  -d "{
    \"displayName\": \"${APP_ID}\",
    \"solutionType\": \"SOLUTION_TYPE_SEARCH\",
    \"industryVertical\": \"GENERIC\",
    \"appType\": \"APP_TYPE_INTRANET\",
    \"dataStoreIds\": [
      \"${DATA_STORE_ID}\"
    ],
    \"commonConfig\": {
      \"companyName\": \"Cymbal Group\"
    },
    \"searchEngineConfig\": {
      \"searchTier\": \"SEARCH_TIER_ENTERPRISE\",
      \"searchAddOns\": [\"SEARCH_ADD_ON_LLM\"],
      \"requiredSubscriptionTier\": \"SUBSCRIPTION_TIER_SEARCH_AND_ASSISTANT\"
    }
  }" > /dev/null || true

# ------------------------------------------------------------------------------
# Task 3 & Task 4: Create Sample Google Docs & Apply Confidential Drive Label
# ------------------------------------------------------------------------------
echo "[Task 3 & 4] Creating sample Google Docs in Google Drive and applying confidential label..."
python3 - "${REPO_ROOT}" "${PROJECT_ID}" "${LABEL_ID}" << 'EOF'
import json, os, subprocess, sys, urllib.request

repo_root, project_id, label_id = sys.argv[1], sys.argv[2], sys.argv[3]
token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()

docs = {
    "Cymbal_QuantumLedger": os.path.join(repo_root, "sample-data", "Cymbal_QuantumLedger.txt"),
    "Cymbal_Public_Overview": os.path.join(repo_root, "sample-data", "Cymbal_Public_Overview.txt"),
    "Cymbal_Brand_Guidelines": os.path.join(repo_root, "sample-data", "Cymbal_Brand_Guidelines.txt"),
}

created_ids = {}
for name, path in docs.items():
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    q = urllib.parse.quote(f"name = '{name}' and trashed = false")
    list_req = urllib.request.Request(
        f"https://www.googleapis.com/drive/v3/files?q={q}&fields=files(id,name)",
        headers={"Authorization": f"Bearer {token}", "X-Goog-User-Project": project_id},
    )
    existing = json.loads(urllib.request.urlopen(list_req).read().decode()).get("files", [])
    if existing:
        file_id = existing[0]["id"]
        print(f"  Found existing {name}: {file_id}")
    else:
        boundary = "===cymbal_doc_boundary==="
        metadata = json.dumps({"name": name, "mimeType": "application/vnd.google-apps.document"})
        body = (
            f"--{boundary}\r\n"
            f"Content-Type: application/json; charset=UTF-8\r\n\r\n"
            f"{metadata}\r\n"
            f"--{boundary}\r\n"
            f"Content-Type: text/plain; charset=UTF-8\r\n\r\n"
            f"{content}\r\n"
            f"--{boundary}--\r\n"
        ).encode("utf-8")
        req = urllib.request.Request(
            "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
            data=body,
            headers={
                "Authorization": f"Bearer {token}",
                "X-Goog-User-Project": project_id,
                "Content-Type": f"multipart/related; boundary={boundary}",
            },
            method="POST",
        )
        resp = json.loads(urllib.request.urlopen(req).read().decode())
        file_id = resp["id"]
        print(f"  Created {name}: {file_id}")
    created_ids[name] = file_id

# Apply Google Drive label to Cymbal_QuantumLedger
ql_id = created_ids["Cymbal_QuantumLedger"]
label_body = json.dumps({"labelModifications": [{"labelId": label_id}]}).encode("utf-8")
label_req = urllib.request.Request(
    f"https://www.googleapis.com/drive/v3/files/{ql_id}/modifyLabels",
    data=label_body,
    headers={
        "Authorization": f"Bearer {token}",
        "X-Goog-User-Project": project_id,
        "Content-Type": "application/json",
    },
    method="POST",
)
urllib.request.urlopen(label_req).read()
print(f"  Applied Drive Label ({label_id}) to Cymbal_QuantumLedger ({ql_id}).")
EOF

# ------------------------------------------------------------------------------
# Task 4: Create Custom SDP Content Policy (cepf-drive-policy)
# ------------------------------------------------------------------------------
echo "[Task 4] Creating Sensitive Data Protection content policy (${POLICY_ID})..."
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://dlp.googleapis.com/v2/projects/${PROJECT_ID}/locations/${LOCATION}/contentPolicies?contentPolicyId=${POLICY_ID}" \
  -d "{
    \"contentPolicy\": {
      \"displayName\": \"${POLICY_ID}\",
      \"contentPolicyConfig\": {
        \"infoTypeConfigs\": [
          {
            \"infoType\": {
              \"name\": \"confidential\",
              \"sensitivityScore\": {
                \"score\": \"SENSITIVITY_SCORE_UNSPECIFIED\"
              }
            },
            \"minLikelihood\": \"VERY_LIKELY\"
          },
          {
            \"infoType\": {
              \"name\": \"CREDIT_CARD_NUMBER\",
              \"sensitivityScore\": {
                \"score\": \"SENSITIVITY_SCORE_HIGH\"
              }
            },
            \"minLikelihood\": \"LIKELY\"
          },
          {
            \"infoType\": {
              \"name\": \"CREDIT_CARD_DATA\",
              \"sensitivityScore\": {
                \"score\": \"SENSITIVITY_SCORE_HIGH\"
              }
            },
            \"minLikelihood\": \"LIKELY\"
          }
        ],
        \"customInfoTypes\": [
          {
            \"infoType\": {
              \"name\": \"confidential\",
              \"sensitivityScore\": {
                \"score\": \"SENSITIVITY_SCORE_UNSPECIFIED\"
              }
            },
            \"likelihood\": \"VERY_LIKELY\",
            \"fileLabelType\": {
              \"driveLabelType\": {
                \"labelId\": \"${LABEL_ID}\"
              }
            }
          }
        ],
        \"policyRules\": [
          {
            \"condition\": {
              \"anyInfoType\": {}
            },
            \"action\": \"BLOCK\"
          }
        ],
        \"defaultAction\": \"ALLOW\"
      }
    }
  }" > /dev/null || true

# ------------------------------------------------------------------------------
# Task 5: Grant DLP User Role & Attach SDP Policy to Google Drive Connector
# ------------------------------------------------------------------------------
echo "[Task 5] Granting roles/dlp.user to Discovery Engine Service Agent..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:service-${PROJECT_NUM}@gcp-sa-discoveryengine.iam.gserviceaccount.com" \
  --role="roles/dlp.user" \
  --quiet > /dev/null

echo "[Task 5] Attaching ${POLICY_ID} to Google Drive connector (${CONNECTOR_ID})..."
curl -s -X PATCH \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/${LOCATION}/collections/${CONNECTOR_ID}/dataConnector?updateMask=dataProtectionPolicy" \
  -d "{
    \"dataProtectionPolicy\": {
      \"sensitiveDataProtectionPolicy\": {
        \"policy\": \"${POLICY_RESOURCE}\"
      }
    }
  }" > /dev/null

# ------------------------------------------------------------------------------
# Task 6: Apply SDP Policy to Assistant and Gemini Notebook
# ------------------------------------------------------------------------------
echo "[Task 6] Attaching ${POLICY_ID} to Assistant (default_assistant)..."
curl -s -X PATCH \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}/locations/${LOCATION}/collections/default_collection/engines/${APP_ID}/assistants/default_assistant?updateMask=customerPolicy" \
  -d "{
    \"customerPolicy\": {
      \"dataProtectionPolicy\": {
        \"sensitiveDataProtectionPolicy\": {
          \"policy\": \"${POLICY_RESOURCE}\"
        }
      }
    }
  }" > /dev/null

echo "[Task 6] Attaching ${POLICY_ID} to Gemini Notebook (notebooklmConfig)..."
curl -s -X PATCH \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUM}?updateMask=customerProvidedConfig.notebooklmConfig.dataProtectionPolicy" \
  -d "{
    \"customerProvidedConfig\": {
      \"notebooklmConfig\": {
        \"dataProtectionPolicy\": {
          \"sensitiveDataProtectionPolicy\": {
            \"policy\": \"${POLICY_RESOURCE}\"
          }
        }
      }
    }
  }" > /dev/null

echo "=================================================================="
echo "All tasks (Tasks 1 - 6) have been successfully configured!"
echo "Run ./scripts/verify_lab.sh to inspect the deployed state."
echo "=================================================================="
