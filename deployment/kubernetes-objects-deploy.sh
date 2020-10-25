#!/bin/bash

# Set later in the script
SUBSCRIPTION_ID=""

function load_variables() {
    export $(grep -v '#.*' variables | xargs)
}

function login() {  
    # Load the subscription ID and immediately strip off the first and last quote from the JSON response
    echo "$(date +"%Y-%m-%d %T") - Loading subscription ID and setting active subscription..."
    SUBSCRIPTION_ID=$(az account show --subscription "$SUBSCRIPTION_NAME" --query 'id' -o json)
    SUBSCRIPTION_ID=${SUBSCRIPTION_ID:1:-1}

    # Set the active subscription (assumes you're already logged in, if not, run az login before running the script)
    az account set --subscription "$SUBSCRIPTION_ID"
}

function add_update_helm_repos() {
    echo "$(date +"%Y-%m-%d %T") - Adding/Updating application-gateway-kubernetes-ingress helm repo..."
    helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
    helm repo update

    echo "$(date +"%Y-%m-%d %T") - Adding/Updating aad-pod-identity helm repo..."
    helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
    helm repo update
}

function install_aad_pod_identity_helm_chart() {
    echo "$(date +"%Y-%m-%d %T") - Installing aad-pod-identity helm chart at version 2.0.2..."
    
    helm install aad-pod-identity aad-pod-identity/aad-pod-identity \
      --namespace default \
      --debug \
      --version 2.0.2
}

function install_agic_helm_chart() {
    echo "$(date +"%Y-%m-%d %T") - Installing ingress-azure helm chart at version 1.2.1..."
    
    # Load necessary parameters
    KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)
    IDENTITY_CLIENT_ID=$(az identity show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "clientId")
    IDENTITY_ID=$(az identity show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "id")
    
    helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
      --namespace default \
      --debug \
      --set appgw.name="$APPLICATION_GATEWAY_NAME" \
      --set appgw.resourceGroup="$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" \
      --set appgw.subscriptionId="$SUBSCRIPTION_ID" \
      --set appgw.usePrivateIP=false \
      --set appgw.shared=false \
      --set armAuth.type=aadPodIdentity \
      --set armAuth.identityResourceID="$IDENTITY_ID" \
      --set armAuth.identityClientID="$IDENTITY_CLIENT_ID" \
      --set rbac.enabled=true \
      --set verbosityLevel=3 \
      --set kubernetes.watchNamespace="" \
      --version 1.2.1    
}

function create_kubernetes_secrets() {
    kubectl -n default create secret generic backend-wildcard-pfx --from-file="certs/backend.pfx"
    kubectl -n default create secret generic backend-wildcard-pfx-password --from-literal=password="$CERTIFICATE_PRIVATE_KEY_PASSWORD"
}

function apply_kubernetes_objects() {
    kubectl apply -f kubernetes-definitions.yaml
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
add_update_helm_repos
install_aad_pod_identity_helm_chart
install_agic_helm_chart
create_kubernetes_secrets
apply_kubernetes_objects

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""