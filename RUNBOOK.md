# Operational Runbook & Step-by-Step Guide

This runbook provides complete, step-by-step instructions to complete **FDE: Add Google Drive with Sensitive Data Protection to Gemini Enterprise — Challenge Lab**, including both **Google Cloud Console (UI)** steps and **CLI / REST API** commands.

---

## Prerequisites & Environment Setup

Before starting, set up your environment variables in Google Cloud Shell and enable the required Google Cloud APIs:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUM=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
export LOCATION="global"
export LABEL_ID="OiQWm4osiQYvIPl6oW6sZqALpOoNtv8zCP7RNNEbbFcb" # Update if your lab provides a different Label ID

# Enable required APIs
gcloud services enable \
  discoveryengine.googleapis.com \
  dlp.googleapis.com \
  drive.googleapis.com \
  docs.googleapis.com \
  drivelabels.googleapis.com \
  admin.googleapis.com \
  --project="$PROJECT_ID"
```

> **Tip:** If your Cloud Shell `gcloud` token does not yet have Google Drive scopes (for automated Google Docs creation and labeling via the API), run:
> ```bash
> gcloud auth login --enable-gdrive-access
> ```

---

## Task 1. Configure the Gemini Enterprise App

### Configuration Parameters

| Parameter | Value |
| :--- | :--- |
| **App name** | `cymbal-ge-app` |
| **Location** | `global` |
| **External company name** | `Cymbal Group` |
| **Identity provider** | `Google Identity` |

### Option A: Google Cloud Console (UI)
1. In the Google Cloud Console, navigate to **Gemini Enterprise**.
2. Go to **Settings** (or **Authentication**) for the **`global`** location.
3. Configure the identity provider and select **Google Identity**, then click **Save**.
4. Go to **Apps** > **Create App**.
5. Enter **App name**: `cymbal-ge-app`.
6. Enter **External company name**: `Cymbal Group`.
7. Select **Location**: `global` and click **Create**.

### Option B: CLI / REST API
```bash
TOKEN=$(gcloud auth print-access-token)

# 1. Configure Google Identity (GSUITE) for the global location ACL configuration
curl -s -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_ID/locations/global/aclConfig" \
  -d '{
    "idpConfig": {
      "idpType": "GSUITE"
    }
  }'

# 2. Create the Gemini Enterprise application (cymbal-ge-app)
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_ID/locations/global/collections/default_collection/engines?engineId=cymbal-ge-app" \
  -d '{
    "displayName": "cymbal-ge-app",
    "solutionType": "SOLUTION_TYPE_SEARCH",
    "industryVertical": "GENERIC",
    "appType": "APP_TYPE_INTRANET",
    "commonConfig": {
      "companyName": "Cymbal Group"
    },
    "searchEngineConfig": {
      "searchTier": "SEARCH_TIER_ENTERPRISE",
      "searchAddOns": ["SEARCH_ADD_ON_LLM"],
      "requiredSubscriptionTier": "SUBSCRIPTION_TIER_SEARCH_AND_ASSISTANT"
    }
  }'
```

---

## Task 2. Set Up a Data Connector for Google Drive

### Configuration Parameters

| Setting | Value |
| :--- | :--- |
| **Data source** | `Google Drive` (`google_drive`) |
| **Connector name** | `cymbal-gdrive-connector` |
| **Location** | `global` |
| **Modes & Actions** | Federated search + Enable all supported Google Drive actions |

### Option A: Google Cloud Console (UI)
1. If Domain-Wide Delegation or OAuth app access is required in Google Workspace Admin Console (`admin.google.com` > **Security** > **Access and data control** > **API controls**), ensure only the minimum required delegated permissions for Google Drive federated search and actions are configured.
2. In the Google Cloud Console, go to **Gemini Enterprise** > **Data stores** > **Create data store**.
3. Select **Google Drive**.
4. In the **Actions** section, select **all supported Google Drive actions**.
5. Set **Location** to `global` and **Connector name** to `cymbal-gdrive-connector`, then click **Create**.
6. Wait for the connector status to reach **Active**.

### Option B: CLI / REST API
```bash
TOKEN=$(gcloud auth print-access-token)

# 1. Initialize the Google Drive connector in FEDERATED and ACTIONS modes
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_ID/locations/global:setUpDataConnector" \
  -d '{
    "collectionId": "cymbal-gdrive-connector",
    "collectionDisplayName": "cymbal-gdrive-connector",
    "dataConnector": {
      "dataSource": "google_drive",
      "entities": [
        {
          "entityName": "google_drive"
        }
      ],
      "connectorModes": [
        "FEDERATED",
        "ACTIONS"
      ]
    }
  }'

# 2. Enable all supported Google Drive actions on the connector
curl -s -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_NUM/locations/global/collections/cymbal-gdrive-connector/dataConnector?updateMask=bapConfig,actionConfig" \
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
  }'
```

---

## Task 3. Test and Validate the Application

### 3.1 Connect Data Store to `cymbal-ge-app`

#### Google Cloud Console (UI)
1. Go to **Gemini Enterprise** > **Apps** > **`cymbal-ge-app`**.
2. Click **Connected data stores**.
3. Select **`cymbal-gdrive-connector`** and click **Connect**.

#### CLI / REST API
> Note: If `cymbal-ge-app` was created before the data store existed, recreate or link `cymbal-gdrive-connector_google_drive` in `dataStoreIds`:
```bash
TOKEN=$(gcloud auth print-access-token)

curl -s -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_ID/locations/global/collections/default_collection/engines/cymbal-ge-app"

sleep 3

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_ID/locations/global/collections/default_collection/engines?engineId=cymbal-ge-app" \
  -d '{
    "displayName": "cymbal-ge-app",
    "solutionType": "SOLUTION_TYPE_SEARCH",
    "industryVertical": "GENERIC",
    "appType": "APP_TYPE_INTRANET",
    "dataStoreIds": [
      "cymbal-gdrive-connector_google_drive"
    ],
    "commonConfig": {
      "companyName": "Cymbal Group"
    },
    "searchEngineConfig": {
      "searchTier": "SEARCH_TIER_ENTERPRISE",
      "searchAddOns": ["SEARCH_ADD_ON_LLM"],
      "requiredSubscriptionTier": "SUBSCRIPTION_TIER_SEARCH_AND_ASSISTANT"
    }
  }'
```

### 3.2 Create Sample Google Docs in Google Drive

Create three Google Docs in your Google Drive:
1. **`Cymbal_QuantumLedger`** (see [`sample-data/Cymbal_QuantumLedger.txt`](./sample-data/Cymbal_QuantumLedger.txt))
2. **`Cymbal_Public_Overview`** (see [`sample-data/Cymbal_Public_Overview.txt`](./sample-data/Cymbal_Public_Overview.txt))
3. **`Cymbal_Brand_Guidelines`** (see [`sample-data/Cymbal_Brand_Guidelines.txt`](./sample-data/Cymbal_Brand_Guidelines.txt))

#### Automated Creation via Google Drive v3 Multipart Upload API
```bash
python3 - << 'EOF'
import json, subprocess, urllib.request

token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()
project_id = subprocess.check_output(["gcloud", "config", "get-value", "project"]).decode().strip()

docs = {
    "Cymbal_QuantumLedger": open("sample-data/Cymbal_QuantumLedger.txt").read(),
    "Cymbal_Public_Overview": open("sample-data/Cymbal_Public_Overview.txt").read(),
    "Cymbal_Brand_Guidelines": open("sample-data/Cymbal_Brand_Guidelines.txt").read(),
}

for name, content in docs.items():
    boundary = "===boundary==="
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
    print(f"Created {name}: ID={resp['id']}")
EOF
```

### 3.3 Validate in the Gemini Enterprise Web App
1. In **Gemini Enterprise** > **`cymbal-ge-app`** > **Integration** > **Web App**, open the web app link.
2. Click **Connectors** at the bottom of the chat window, click **Enable actions** next to Google Drive, and grant OAuth consent.
3. Enable only the **Google Drive** connector and test:
   - `List all the Drive documents.`
   - `Summarize the financial allocations for Cymbal_QuantumLedger from Google Drive and present them as a bulleted list`
   - `Summarize the details of Cymbal_Public_Overview from Google Drive`

---

## Task 4. Secure the Connected Infrastructure Using Custom Data Protection Policies

### 4.1 Apply the `Cymbal Confidential` Label to `Cymbal_QuantumLedger`

- **Label ID**: `OiQWm4osiQYvIPl6oW6sZqALpOoNtv8zCP7RNNEbbFcb` (`Cymbal Confidential`)

#### CLI / REST API
```bash
TOKEN=$(gcloud auth print-access-token)

# Look up the File ID of Cymbal_QuantumLedger
FILE_ID=$(curl -s -H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: $PROJECT_ID" \
  "https://www.googleapis.com/drive/v3/files?q=name%3D%27Cymbal_QuantumLedger%27%20and%20trashed%3Dfalse" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['files'][0]['id'])")

# Apply the Google Drive label
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://www.googleapis.com/drive/v3/files/${FILE_ID}/modifyLabels" \
  -d "{
    \"labelModifications\": [
      {
        \"labelId\": \"${LABEL_ID}\"
      }
    ]
  }"
```

### 4.2 Create the Custom SDP Content Policy (`cepf-drive-policy`)

#### Configuration Parameters

| Setting | Value |
| :--- | :--- |
| **Policy Name** | `cepf-drive-policy` |
| **Location** | `global` |
| **Custom InfoType Name** | `confidential` |
| **Custom InfoType Type** | `File Label` (`Google Drive Label`) |
| **Label ID** | `OiQWm4osiQYvIPl6oW6sZqALpOoNtv8zCP7RNNEbbFcb` |
| **Likelihood** | `Very Likely` (`VERY_LIKELY`) |
| **Sensitivity** | `Unspecified` (`SENSITIVITY_SCORE_UNSPECIFIED`) |
| **Built-in InfoTypes** | `CREDIT_CARD_NUMBER`, `CREDIT_CARD_DATA` |
| **Policy Rule Action** | `BLOCK` if any configured infoTypes match |

#### CLI / REST API
```bash
TOKEN=$(gcloud auth print-access-token)

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/global/contentPolicies?contentPolicyId=cepf-drive-policy" \
  -d "{
    \"contentPolicy\": {
      \"displayName\": \"cepf-drive-policy\",
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
  }"
```

---

## Task 5. Attach the SDP Policy to the Google Drive Connector

### 5.1 Grant `roles/dlp.user` to the Discovery Engine Service Agent
```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:service-${PROJECT_NUM}@gcp-sa-discoveryengine.iam.gserviceaccount.com" \
  --role="roles/dlp.user"
```

### 5.2 Attach `cepf-drive-policy` to `cymbal-gdrive-connector`
```bash
TOKEN=$(gcloud auth print-access-token)
POLICY_NAME="projects/$PROJECT_ID/locations/global/contentPolicies/cepf-drive-policy"

curl -s -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_NUM/locations/global/collections/cymbal-gdrive-connector/dataConnector?updateMask=dataProtectionPolicy" \
  -d "{
    \"dataProtectionPolicy\": {
      \"sensitiveDataProtectionPolicy\": {
        \"policy\": \"${POLICY_NAME}\"
      }
    }
  }"
```

### 5.3 Validate Connector Restrictions in Web App
- Query: `Retrieve the summary for Cymbal_QuantumLedger.` -> **Blocked / Refused by SDP policy**.
- Query: `Retrieve the summary for Cymbal_Public_Overview.` -> **Allowed (returns summary)**.

---

## Task 6. Apply SDP to Assistant and Gemini Notebook

### 6.1 Attach `cepf-drive-policy` to Assistant (`default_assistant`) and Gemini Notebook (`notebooklmConfig`)
```bash
TOKEN=$(gcloud auth print-access-token)
POLICY_NAME="projects/$PROJECT_ID/locations/global/contentPolicies/cepf-drive-policy"

# 1. Apply to Assistant (default_assistant on cymbal-ge-app)
curl -s -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_NUM/locations/global/collections/default_collection/engines/cymbal-ge-app/assistants/default_assistant?updateMask=customerPolicy" \
  -d "{
    \"customerPolicy\": {
      \"dataProtectionPolicy\": {
        \"sensitiveDataProtectionPolicy\": {
          \"policy\": \"${POLICY_NAME}\"
        }
      }
    }
  }"

# 2. Apply to Gemini Notebook (Project-level notebooklmConfig)
curl -s -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_NUM?updateMask=customerProvidedConfig.notebooklmConfig.dataProtectionPolicy" \
  -d "{
    \"customerProvidedConfig\": {
      \"notebooklmConfig\": {
        \"dataProtectionPolicy\": {
          \"sensitiveDataProtectionPolicy\": {
            \"policy\": \"${POLICY_NAME}\"
          }
        }
      }
    }
  }"
```

### 6.2 Validate Assistant & Gemini Notebook SDP Blocking
1. **Assistant Drive Upload Validation**:
   - In the Web App chat prompt, click **+** > **Add from Drive**:
     - Selecting `Cymbal_QuantumLedger` is **blocked** by the SDP policy.
     - Selecting `Cymbal_Public_Overview` succeeds.
2. **Gemini Notebook Pasted Text Validation**:
   - In the Web App, click **Gemini Notebook** > **Create a new notebook** > **Paste text** (`Copied text`) and paste the contents of [`sample-data/credit_card_sample.txt`](./sample-data/credit_card_sample.txt) (or run the API call below).
   - Confirm that the source fails with `SOURCE_STATUS_ERROR` (`policyCheckFailed`).

```bash
# Optional API test for Gemini Notebook SDP enforcement
NB_RESP=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_NUM/locations/global/notebooks" \
  -d '{"title": "Cymbal Notebook"}')

NB_NAME=$(echo "$NB_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('name', ''))")

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/${NB_NAME}/sources:batchCreate" \
  -d "{
    \"userContents\": [
      {
        \"textContent\": {
          \"sourceName\": \"Pasted Text\",
          \"content\": $(python3 -c 'import json; print(json.dumps(open("sample-data/credit_card_sample.txt").read()))')
        }
      }
    ]
  }"
```

---

## Troubleshooting

| Symptom / Error | Cause | Resolution |
| :--- | :--- | :--- |
| `403 SERVICE_DISABLED` on Discovery Engine or DLP API | APIs are not enabled in the project | Run `gcloud services enable discoveryengine.googleapis.com dlp.googleapis.com` |
| `403 accessNotConfigured` on Google Drive v3 API | Missing quota project header | Add `-H "X-Goog-User-Project: $PROJECT_ID"` to all Drive API requests |
| `400 Engines with multiple data stores can not remove data stores such that <2 data stores remain linked` | `cymbal-ge-app` was created with empty `dataStoreIds` and defaulted to `BLENDED` mode | Delete `cymbal-ge-app` and recreate it with `"dataStoreIds": ["cymbal-gdrive-connector_google_drive"]` |
| `Cymbal_QuantumLedger` is not blocked when queried | Missing `roles/dlp.user` on Discovery Engine Service Agent or label ID mismatch | Verify `service-${PROJECT_NUM}@gcp-sa-discoveryengine.iam.gserviceaccount.com` has `roles/dlp.user` and wait 1–2 minutes for policy propagation |
