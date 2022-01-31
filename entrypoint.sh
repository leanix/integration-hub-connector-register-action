#!/bin/bash
set -eo pipefail # http://redsymbol.net/articles/unofficial-bash-strict-mode/

# The dictionary contains all the available regions
declare -A REGION_IDS
REGION_IDS["westeurope"]="eu"
REGION_IDS["eastus"]="us"
REGION_IDS["canadacentral"]="ca"
REGION_IDS["australiaeast"]="au"
REGION_IDS["germanywestcentral"]="de"
REGION_IDS["horizon"]="horizon" # edge-case for horizon

# The file containing the default connetor defintion from the calling repository
NEW_CONNECTOR_FILE=/github/workspace/${INPUT_CONNECTOR_DEFINITION_FILE}
echo "Reading provided connector definition from file '${NEW_CONNECTOR_FILE}' ..."

CONNECTOR_NAME=$(cat ${NEW_CONNECTOR_FILE} | jq -r '.name')
echo "Found provided config for connector ='${CONNECTOR_NAME}'"

echo "Login to Azure ..."
echo "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID"
echo "az account set -s $ARM_SUBSCRIPTION_ID"

if [[ -z "${INPUT_REGION}" ]]; then
  # use all regions
  REGIONS=${!REGION_IDS[@]}
else
  # use provided region only
  REGIONS=("${INPUT_REGION}")
fi
# hard-coded test environment
if [[ "${INPUT_ENVIRONMENT}" == "test" ]]; then
  REGIONS=( westeurope )
fi

for REGION in $REGIONS; do
  REGION_ID=${REGION_IDS[$REGION]} # e.g. 'eu' for 'westeurope'
  if [[ "${REGION}" == "horizon" ]]; then
    # edge-case for horizon
    KEY_VAULT_NAME="lxeastusprod"
    VAULT_SECRET_KEY="integration-hub-horizon-oauth-secret-horizon-svc"
    REGION_ID="app-9"
  else
    KEY_VAULT_NAME="lx${REGION}${INPUT_ENVIRONMENT}"
    VAULT_SECRET_KEY="integration-hub-oauth-secret-${REGION_ID}-svc"
  fi
  # hard-coded test environment
  if [[ "${INPUT_ENVIRONMENT}" == "test" ]]; then
    KEY_VAULT_NAME="lxwesteuropetest"
    VAULT_SECRET_KEY="integration-hub-oauth-secret-test-svc-flow-2"
    REGION_ID="test-app-flow-2"
  fi

  echo "Using key '${VAULT_SECRET_KEY}' to fetch the SYSTEM user secret from Azure Key Vault '${KEY_VAULT_NAME}' ..."
  #VAULT_SECRET_VALUE=$(az keyvault secret show --vault-name ${KEY_VAULT_NAME} --name ${VAULT_SECRET_KEY} | jq -r .value)
  VAULT_SECRET_VALUE=$MTM_CLIENT_SECRET

  echo "Fetching oauth token from ${REGION_ID}.leanix.net ..."
  TOKEN=$(curl --silent --request POST \
    --url "https://${REGION_ID}.leanix.net/services/mtm/v1/oauth2/token" \
    --header 'content-type: application/x-www-form-urlencoded' \
    --header 'User-Agent: integration-hub-connector-register-action' \
    --data client_id=integration-hub \
    --data client_secret=${VAULT_SECRET_VALUE} \
    --data grant_type=client_credentials \
    | jq -r .'access_token')

  echo "GET integration-hub/v1/connectorTemplates/${CONNECTOR_NAME} ..."
  CONNECTOR_ID=$(curl --silent --request GET \
    --url "https://${REGION_ID}.leanix.net/services/integration-hub/v1/connectorTemplates/${CONNECTOR_NAME}" \
    --header "Authorization: Bearer ${TOKEN}" \
    --header 'User-Agent: integration-hub-connector-register-action' \
    --header 'Accept: application/json' \
    | jq -r .'id')
  
  if [[ "${CONNECTOR_ID}" != "null" ]] ; then
    echo "Found connector Id: '${CONNECTOR_ID}'  for connector name='${CONNECTOR_NAME}'"
    UPSERT_RESULT=$(curl --request PUT --write-out %{http_code} --silent --output /dev/null \
    --url "https://${REGION_ID}.leanix.net/services/integration-hub/v1/connectorTemplates/${CONNECTOR_ID}" \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "Content-Type: application/json" \
    --header 'User-Agent: integration-hub-connector-register-action' \
    --header 'Accept: application/json' \
    --data-binary @${NEW_CONNECTOR_FILE})

    if [[ "${UPSERT_RESULT}" -eq 200 ]] ; then
      echo "Successfully modified connector ${CONNECTOR_NAME}"
    else
      echo "Failed to update connector Id: ${CONNECTOR_ID} . Http error code: ${UPSERT_RESULT}"
    fi
  else
    echo "No remote connector found with the name='${CONNECTOR_NAME} ' . Creating a new connector"
    CREATE_RESULT=$(curl --request POST --write-out %{http_code} --silent --output /dev/null \
    --url "https://${REGION_ID}.leanix.net/services/integration-hub/v1/connectorTemplates" \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "Content-Type: application/json" \
    --header 'User-Agent: integration-hub-connector-register-action' \
    --header 'Accept: application/json' \
    --data-binary @${NEW_CONNECTOR_FILE} \
    | jq -r '.id')

    if [[ "${UPSERT_RESULT}" -eq 200 ]] ; then
      echo "Successfully created a new connector,  Id: ${CONNECTOR_ID}"
    else
      echo "Failed to create new connector. Http error code: ${CREATE_RESULT}"
    fi
  fi
done