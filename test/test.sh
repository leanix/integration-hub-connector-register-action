#!/bin/bash
set -e

docker run --rm \
  -e ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID \
  -e ARM_TENANT_ID=$ARM_TENANT_ID \
  -e ARM_CLIENT_ID=$ARM_CLIENT_ID \
  -e ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET \
  -e INPUT_ENVIRONMENT=test \
  -e INPUT_CONNECTOR_DEFINITION_FILE="test/integration-hub-connector-definition.json" \
  -v $(pwd):/github/workspace \
  leanixacrpublic.azurecr.io/integration-hub-connector-register-action:$1