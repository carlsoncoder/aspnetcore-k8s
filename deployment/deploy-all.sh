#!/bin/bash

# The public key value of the SSH key.  You will need the private key yourself to eventually log into the nodes via SSH
# YOU MUST SET THIS VALUE APPROPRIATELY!
SSH_PUBLIC_KEY=""

# DO NOT MODIFY anything past this line!

# Set later in the script
SUBSCRIPTION_ID=""
KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=""
KUBERNETES_VNET_NAME=""
APPLICATION_GATEWAY_ID=""
APPLICATION_GATEWAY_PUBLIC_IP_FQDN=""
IDENTITY_CLIENT_ID=""
IDENTITY_ID=""

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

function create_cluster() {
    # Create the resource group where we will be applying the cluster
    echo "$(date +"%Y-%m-%d %T") - Creating resource group where cluster will be applied..."
    az group create \
      --name "$CLUSTER_RESOURCE_GROUP_NAME" \
      --location "$AZURE_LOCATION" \
      --tags "$CREATED_ON" "$CREATOR_EMAIL" "$OWNER" "$OWNER_EMAIL"

    # Create the actual AKS cluster itself
    echo "$(date +"%Y-%m-%d %T") - Deploying AKS Cluster..."
    az aks create \
      --name "$CLUSTER_NAME" \
      --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" \
      --admin-username "$LINUX_ADMIN_USERNAME" \
      --enable-cluster-autoscaler \
      --kubernetes-version "$KUBERNETES_VERSION" \
      --load-balancer-sku "Standard" \
      --location "$AZURE_LOCATION" \
      --node-count "$NODE_POOL_COUNT" \
      --min-count "$MIN_NODE_COUNT" \
      --max-count "$MAX_NODE_COUNT" \
      --network-plugin "azure" \
      --network-policy "azure" \
      --node-vm-size "$NODE_VM_SIZE" \
      --nodepool-name "$NODEPOOL_NAME" \
      --ssh-key-value "$SSH_PUBLIC_KEY"

    # Get the credentials so we can call operations on the cluster with kubectl
    echo "$(date +"%Y-%m-%d %T") - Setting Kubernetes cluster credentials..."
    az aks get-credentials \
      --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" \
      --name "$CLUSTER_NAME" \
      --overwrite-existing

    # Load some parameters that we'll use in other sections of the script
    KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)
    KUBERNETES_VNET_NAME=$(az network vnet list --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" -o json --query [0].name)
    KUBERNETES_VNET_NAME=${KUBERNETES_VNET_NAME:1:-1}
}

function create_application_gateway() {
    echo "$(date +"%Y-%m-%d %T") - Creating public IP address for Application Gateway..."
    az network public-ip create \
      --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" \
      --name "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" \
      --dns-name "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" \
      --allocation-method "Static" \
      --sku "Standard"

    echo "$(date +"%Y-%m-%d %T") - Creating gateway subnet in Kubernetes VNET..."
    az network vnet subnet create \
      --name "$APPLICATION_GATEWAY_SUBNET_NAME" \
      --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" \
      --vnet-name "$KUBERNETES_VNET_NAME" \
      --address-prefix "$APPLICATION_GATEWAY_SUBNET_CIDR"

    echo "$(date +"%Y-%m-%d %T") - Creating Application Gateway..."
    az network application-gateway create \
      --name "$APPLICATION_GATEWAY_NAME" \
      --location "$AZURE_LOCATION" \
      --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" \
      --vnet-name "$KUBERNETES_VNET_NAME" \
      --subnet "$APPLICATION_GATEWAY_SUBNET_NAME" \
      --sku "Standard_v2" \
      --public-ip-address "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" \
      --private-ip-address "$APPLICATION_GATEWAY_PRIVATE_IP_ADDRESS"

    echo "$(date +"%Y-%m-%d %T") - Assigning backend CA as root-cert for application gateway..."
    az network application-gateway root-cert create \
      --name "backend-ca-tls" \
      --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" \
      --gateway-name "$APPLICATION_GATEWAY_NAME" \
      --cert-file "certs/ca/ca.crt"

    echo "$(date +"%Y-%m-%d %T") - Assigning frontend cert as ssl-cert for application gateway..."
    az network application-gateway ssl-cert create \
      --name "frontend-tls" \
      --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" \
      --gateway-name "$APPLICATION_GATEWAY_NAME" \
      --cert-file "certs/frontend/frontend.pfx" \
      --cert-password "$CERTIFICATE_PRIVATE_KEY_PASSWORD"

    # Load some parameters that we'll use in other sections of the script
    APPLICATION_GATEWAY_ID=$(az network application-gateway show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$APPLICATION_GATEWAY_NAME" -o json --query 'id')
    APPLICATION_GATEWAY_ID=${APPLICATION_GATEWAY_ID:1:-1}

    APPLICATION_GATEWAY_PUBLIC_IP_FQDN=$(az network public-ip show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" -o json --query dnsSettings.fqdn)
    APPLICATION_GATEWAY_PUBLIC_IP_FQDN=${APPLICATION_GATEWAY_PUBLIC_IP_FQDN:1:-1}
}

function create_arm_identity_and_assign_permissions() {
    echo "$(date +"%Y-%m-%d %T") - Creating AAD ARM Azure Identity for Application Gateway..."
    az identity create --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME"

    echo "$(date +"%Y-%m-%d %T") - Sleeping for 30 seconds to ensure AAD Identity propagation..."
    sleep 30s

    IDENTITY_CLIENT_ID=$(az identity show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "clientId")
    IDENTITY_ID=$(az identity show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "id")
    
    echo "$(date +"%Y-%m-%d %T") - Assigning permissions to AAD identity for Application Gateway..."
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

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
create_cluster
create_application_gateway
create_arm_identity_and_assign_permissions
add_update_helm_repos
install_aad_pod_identity_helm_chart
install_agic_helm_chart

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""