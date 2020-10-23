#!/bin/bash
# Derived from: https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/setup/install-existing.md#set-up-aad-pod-identity

# This will be defined later
SUBSCRIPTION_ID=""

function load_variables() {
    export $(grep -v '#.*' .variables | xargs)
}

function login() {
    # Load the subscription ID and immediately strip off the first and last quote from the JSON response
    echo "$(date +"%Y-%m-%d %T") - Loading subscription ID and setting active subscription..."
    SUBSCRIPTION_ID=$(az account show --subscription "$SUBSCRIPTION_NAME" --query 'id' -o json)
    SUBSCRIPTION_ID=${SUBSCRIPTION_ID:1:-1}

    # Set the active subscription (assumes you're already logged in, if not, run az login before running the script)
    az account set --subscription "$SUBSCRIPTION_ID"
}

function create_identity_and_assign_permissions() {
    KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)

    echo "$(date +"%Y-%m-%d %T") - Creating AAD ARM Azure Identity for Application Gateway..."
    az identity create --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME"

    echo "$(date +"%Y-%m-%d %T") - Sleeping for 30 seconds to ensure AAD Identity propagation..."
    sleep 30s

    IDENTITY_CLIENT_ID=$(az identity show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "clientId")
    IDENTITY_ID=$(az identity show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "id")
    
    echo "$(date +"%Y-%m-%d %T") - Assigning permissions to AAD identity for Application Gateway..."
    APPLICATION_GATEWAY_ID=$(az network application-gateway show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$APPLICATION_GATEWAY_NAME" -o json --query 'id')
    APPLICATION_GATEWAY_ID=${APPLICATION_GATEWAY_ID:1:-1}

    az role assignment create \
      --role "Contributor" \
      --assignee "$IDENTITY_CLIENT_ID" \
      --scope "$APPLICATION_GATEWAY_ID"

    echo "$(date +"%Y-%m-%d %T") - Assigning permissions to AAD identity for Application Gateway Resource Group..."
    SCOPES="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME"

    az role assignment create \
      --role "Reader" \
      --assignee "$IDENTITY_CLIENT_ID" \
      --scope "$SCOPES"

    echo "$(date +"%Y-%m-%d %T") - Assigning permissions to AAD identity for Managed Identity Operator..."
    CLUSTER_CLIENT_ID=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -o tsv --query "servicePrincipalProfile.clientId")
    
    az role assignment create \
      --role "Managed Identity Operator" \
      --assignee "$CLUSTER_CLIENT_ID" \
      --scope "$IDENTITY_ID"
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
create_identity_and_assign_permissions

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""