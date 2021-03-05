#!/bin/bash

# Set later in the script
SUBSCRIPTION_ID=""

function load_variables() {
    export $(grep -v '#.*' variables | xargs)
}

function login() {  
    # Load the subscription ID
    echo "$(date +"%Y-%m-%d %T") - Loading subscription ID and setting active subscription..."
    SUBSCRIPTION_ID=$(az account show --subscription "$SUBSCRIPTION_NAME" --query 'id' -o tsv)

    # Set the active subscription (assumes you're already logged in, if not, run az login before running the script)
    az account set --subscription "$SUBSCRIPTION_ID"
}

function obtain_kubernetes_admin_credentials() {
    # We pull down the admin credentials for the cluster to make the rest of the script able to run unattended
    echo "$(date +"%Y-%m-%d %T") - Obtaining administrative cluster credentials..."
    az aks get-credentials \
      --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" \
      --name "$CLUSTER_NAME" \
      --admin \
      --overwrite-existing
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

    # Load necessary values from the az CLI
    IDENTITY_CLIENT_ID=$(az identity show --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "clientId")
    IDENTITY_ID=$(az identity show --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "id")
    APPLICATION_GATEWAY_SUBNET_ID=$(az network vnet subnet show --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --vnet-name "$MAIN_VNET_NAME" --name "$APPLICATION_GATEWAY_SUBNET_NAME" --query "id" -o tsv)

    helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
      --namespace default \
      --debug \
      --set appgw.name="$APPLICATION_GATEWAY_NAME" \
      --set appgw.subnetName="$APPLICATION_GATEWAY_SUBNET_NAME" \
      --set appgw.subnetID="$APPLICATION_GATEWAY_SUBNET_ID" \
      --set appgw.resourceGroup="$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --set appgw.subscriptionId="$SUBSCRIPTION_ID" \
      --set appgw.usePrivateIP=false \
      --set appgw.shared=false \
      --set armAuth.type=aadPodIdentity \
      --set armAuth.identityResourceID="$IDENTITY_ID" \
      --set armAuth.identityClientID="$IDENTITY_CLIENT_ID" \
      --set rbac.enabled=true \
      --set verbosityLevel=3 \
      --set kubernetes.watchNamespace="" \
      --set nodeSelector."kubernetes\\.io/os"=linux \
      --version 1.2.1
}

function apply_aad_pod_identity_mic_exception() {
    echo "$(date +"%Y-%m-%d %T") - Installing AAD Pod Identity MIC exception..."
    curl https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/mic-exception.yaml -o mic-exception.yaml
    kubectl apply -f mic-exception.yaml
    rm -rf mic-exception.yaml
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
obtain_kubernetes_admin_credentials
add_update_helm_repos
install_aad_pod_identity_helm_chart
install_agic_helm_chart
apply_aad_pod_identity_mic_exception

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""