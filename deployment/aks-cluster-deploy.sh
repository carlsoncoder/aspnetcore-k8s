#!/bin/bash

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
}

function create_application_gateway() {
    KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)
    KUBERNETES_VNET_NAME=$(az network vnet list --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" -o json --query [0].name)
    KUBERNETES_VNET_NAME=${KUBERNETES_VNET_NAME:1:-1}

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

    echo "$(date +"%Y-%m-%d %T") - Assigning backend CA as root cert for application gateway..."
    az network application-gateway root-cert create \
      --name "backend-ca-tls" \
      --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" \
      --gateway-name "$APPLICATION_GATEWAY_NAME" \
      --cert-file "certs/ca.pem"
}

function create_dns_record() {
    KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)
    APPLICATION_GATEWAY_PUBLIC_IP_FQDN=$(az network public-ip show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" -o json --query dnsSettings.fqdn)
    APPLICATION_GATEWAY_PUBLIC_IP_FQDN=${APPLICATION_GATEWAY_PUBLIC_IP_FQDN:1:-1}

    echo "$(date +"%Y-%m-%d %T") - Creating empty CNAME DNS Record Set..."
    az network dns record-set cname create \
      --resource-group "$DNS_RESOURCE_GROUP" \
      --name "$DNS_DESIRED_HOSTNAME" \
      --zone-name "$DNS_ZONE_NAME" \
      --ttl 3600

    echo "$(date +"%Y-%m-%d %T") - Assigning alias value to CNAME DNS Record Set..."
    az network dns record-set cname set-record \
      --resource-group "$DNS_RESOURCE_GROUP" \
      --record-set-name "$DNS_DESIRED_HOSTNAME" \
      --zone "$DNS_ZONE_NAME" \
      --cname "$APPLICATION_GATEWAY_PUBLIC_IP_FQDN" \
      --ttl 3600
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
create_cluster
create_application_gateway
create_dns_record

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""