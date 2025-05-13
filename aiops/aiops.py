import os
import json
import urllib.parse
from flask import Flask, request, jsonify
import requests
from azure.identity import ManagedIdentityCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.keyvault.secrets import SecretClient
from msal import ConfidentialClientApplication

app = Flask(__name__)

# --- Configuration (Load from Environment Variables for Security) ---
SERVICE_NOW_ENDPOINT = os.environ.get("SERVICE_NOW_ENDPOINT", "https://iag1test.service-now.com/api/sn_em_connector/em/inbound_event?source=azuremonitor")
SN_AUTH_TENANT_ID = os.environ.get("SN_AUTH_TENANT_ID", "8bc3bb99-ff6d-42ef-9b17-1ea52c4db4ed")
AZURE_KEY_VAULT_URI = os.environ.get("AZURE_KEY_VAULT_URI") # e.g., https://yourkeyvaultname.vault.azure.net/
SN_AUTH_CLIENT_ID_SECRET_NAME = os.environ.get("SN_AUTH_CLIENT_ID_SECRET_NAME", "ServiceNowClientID") # Name of the secret for Client ID
SN_AUTH_CLIENT_SECRET_NAME = os.environ.get("SN_AUTH_CLIENT_SECRET_NAME", "ServiceNowClientSecret") # Name of the secret for Client Secret

SN_AUTH_AUDIENCE = os.environ.get("SN_AUTH_AUDIENCE", "api://fe05437f-c0ee-4c24-a034-532390fb5e2b")
SN_AUTH_AUTHORITY = f"https://login.microsoftonline.com/{SN_AUTH_TENANT_ID}"

AZURE_RM_API_VERSION = "2021-04-01"

# --- Helper Function for ServiceNow AAD Token ---
def get_servicenow_access_token():
    if not AZURE_KEY_VAULT_URI or not SN_AUTH_CLIENT_ID_SECRET_NAME or not SN_AUTH_CLIENT_SECRET_NAME:
        print("Error: AZURE_KEY_VAULT_URI, SN_AUTH_CLIENT_ID_SECRET_NAME, or SN_AUTH_CLIENT_SECRET_NAME is not set in environment variables.")
        return None

    try:
        credential = ManagedIdentityCredential()
        secret_client = SecretClient(vault_url=AZURE_KEY_VAULT_URI, credential=credential)
        
        retrieved_client_id_secret = secret_client.get_secret(SN_AUTH_CLIENT_ID_SECRET_NAME)
        sn_auth_client_id_value = retrieved_client_id_secret.value

        retrieved_client_secret = secret_client.get_secret(SN_AUTH_CLIENT_SECRET_NAME)
        sn_auth_client_secret_value = retrieved_client_secret.value

    except Exception as e:
        print(f"Error retrieving secrets from Azure Key Vault: {e}")
        return None

    if not sn_auth_client_id_value:
        print("Error: Client ID value could not be retrieved from Key Vault or is empty.")
        return None
    if not sn_auth_client_secret_value:
        print("Error: Client secret value could not be retrieved from Key Vault or is empty.")
        return None

    app_auth = ConfidentialClientApplication(
        sn_auth_client_id_value,
        authority=SN_AUTH_AUTHORITY,
        client_credential=sn_auth_client_secret_value
    )
    scopes = [f"{SN_AUTH_AUDIENCE}/.default"]
    result = app_auth.acquire_token_for_client(scopes=scopes)

    if "access_token" in result:
        return result["access_token"]
    else:
        print(f"Error acquiring token for ServiceNow: {result.get('error_description')}")
        return None

# --- Flask HTTP Trigger ---
@app.route('/webhook', methods=['POST'])
def webhook_trigger():
    try:
        # 1. Receive and Parse JSON payload
        raw_payload = request.get_json()
        if not raw_payload:
            return jsonify({"error": "Invalid or missing JSON payload"}), 400
        
        parsed_alert_payload = raw_payload 
        print(f"Received and Parsed Payload: {json.dumps(parsed_alert_payload, indent=2)}")

        # 2. Initialize Variable "AffectedResource"
        affected_resource_parts = []
        alert_target_id = None # Initialize to None
        try:
            alert_target_id = parsed_alert_payload['data']['essentials']['alertTargetIDs'][0]
            affected_resource_parts = alert_target_id.split('/')
            print(f"Affected Resource Parts: {affected_resource_parts}")
        except (KeyError, IndexError, TypeError) as e:
            print(f"Warning: Could not determine affected resource ID from payload: {e}")

        # 3. Read Azure Resource Tags
        resource_tags = {}
        if alert_target_id and len(affected_resource_parts) > 8: # Check if alert_target_id is not None
            try:
                subscription_id = affected_resource_parts[2]
                # resource_group_name = affected_resource_parts[4] # Not directly needed for get_by_id

                credential = ManagedIdentityCredential()
                resource_client = ResourceManagementClient(credential, subscription_id)
                
                resource_details = resource_client.resources.get_by_id(
                    resource_id=alert_target_id,
                    api_version=AZURE_RM_API_VERSION 
                )
                if resource_details and resource_details.tags:
                    resource_tags = resource_details.tags
                print(f"Fetched Resource Tags: {resource_tags}")
            except Exception as e:
                print(f"Warning: Failed to fetch tags for resource {alert_target_id}. Error: {e}")
        elif alert_target_id: # if alert_target_id is set but parts are not enough
             print(f"Warning: Not enough parts in affected_resource_parts for {alert_target_id} to fetch tags.")
        else: # if alert_target_id was never set
            print("Warning: Affected resource ID not found in payload, cannot fetch tags.")


        # 4. Compose Alert Payload
        composed_payload = json.loads(json.dumps(parsed_alert_payload)) # Deep copy

        if 'data' not in composed_payload:
            composed_payload['data'] = {}
        
        if not isinstance(composed_payload.get('data'), dict):
            composed_payload['data'] = {} 

        current_data_content = composed_payload.get('data', {})
        new_data_content = {**current_data_content, "customProperties": resource_tags}
        composed_payload['data'] = new_data_content
        
        print(f"Composed Payload: {json.dumps(composed_payload, indent=2)}")

        # 5. Send Payload to ServiceNow
        servicenow_token = get_servicenow_access_token()
        if not servicenow_token:
            return jsonify({"error": "Failed to acquire ServiceNow access token"}), 500

        headers_to_servicenow = {
            "typ": "JWT",
            "alg": "RS256",
            "x5t": "CNv0OI3RwqlHFEVnaoMAshCH2XE",
            "kid": "CNv0OI3RwqlHFEVnaoMAshCH2XE",
            "appidacr": "2",
            "Authorization": f"Bearer {servicenow_token}",
            "Content-Type": "application/json"
        }

        try:
            response = requests.post(
                SERVICE_NOW_ENDPOINT,
                headers=headers_to_servicenow,
                json=composed_payload,
                timeout=30
            )
            response.raise_for_status() 
            print(f"Successfully sent payload to ServiceNow. Status: {response.status_code}")
            return jsonify({"status": "success", "servicenow_response_status": response.status_code}), 200
        except requests.exceptions.RequestException as e:
            print(f"Error sending payload to ServiceNow: {e}")
            error_details = str(e)
            if e.response is not None:
                error_details += f" | Response: {e.response.text}"
            return jsonify({"error": "Failed to send payload to ServiceNow", "details": error_details}), 500

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({"error": "An internal server error occurred", "details": str(e)}), 500

if __name__ == '__main__':
    if not AZURE_KEY_VAULT_URI or not SN_AUTH_CLIENT_ID_SECRET_NAME or not SN_AUTH_CLIENT_SECRET_NAME:
        print("FATAL ERROR: AZURE_KEY_VAULT_URI, SN_AUTH_CLIENT_ID_SECRET_NAME, or SN_AUTH_CLIENT_SECRET_NAME environment variable is not set. Exiting.")
    else:
        port = int(os.environ.get("PORT", 5000))
        app.run(host='0.0.0.0', port=port, debug=True)