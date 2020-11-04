#!/bin/bash

# Set later in the script
SUBSCRIPTION_ID=""
SSH_PUBLIC_KEY=""
APPLICATION_GATEWAY_ID=""
KUBERNETES_NODEPOD_SUBNET_ID=""
KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=""

function load_variables() {
    export $(grep -v '#.*' variables | xargs)
    SSH_PUBLIC_KEY=$(<keys/ssh.pub)
}

function login() {  
    # Load the subscription ID
    echo "$(date +"%Y-%m-%d %T") - Loading subscription ID and setting active subscription..."
    SUBSCRIPTION_ID=$(az account show --subscription "$SUBSCRIPTION_NAME" --query 'id' -o tsv)

    # Set the active subscription (assumes you're already logged in, if not, run az login before running the script)
    az account set --subscription "$SUBSCRIPTION_ID"
}

function deploy_infrastructure_resource_group() {
    echo "$(date +"%Y-%m-%d %T") - Creating infrastructure resource group..."
    az group create \
      --name "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --location "$AZURE_LOCATION" \
      --tags "$CREATED_ON" "$CREATOR_EMAIL" "$OWNER" "$OWNER_EMAIL"
}

function deploy_network_security_group() {
    echo "$(date +"%Y-%m-%d %T") - Creating new network security group..."
    az network nsg create \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --name "$NSG_NAME"
}

function deploy_main_vnet_with_aks_subnet() {
    echo "$(date +"%Y-%m-%d %T") - Creating main virtual network..."
    az network vnet create \
      --name "$MAIN_VNET_NAME" \
      --location "$AZURE_LOCATION" \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --network-security-group "$NSG_NAME" \
      --address-prefixes "$MAIN_VNET_CIDR" \
      --subnet-name "$AKS_SUBNET_NAME" \
      --subnet-prefixes "$AKS_SUBNET_CIDR"

      # Determine the subnet ID of the subnet we just created
      KUBERNETES_NODEPOD_SUBNET_ID=$(az network vnet subnet show --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --vnet-name "$MAIN_VNET_NAME" --name "$AKS_SUBNET_NAME" --query 'id' -o tsv)
}

function deploy_application_gateway_subnet() {
    echo "$(date +"%Y-%m-%d %T") - Creating gateway subnet..."
    az network vnet subnet create \
      --name "$APPLICATION_GATEWAY_SUBNET_NAME" \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --vnet-name "$MAIN_VNET_NAME" \
      --address-prefix "$APPLICATION_GATEWAY_SUBNET_CIDR"
}

function deploy_management_subnet() {
    echo "$(date +"%Y-%m-%d %T") - Creating management subnet..."
    az network vnet subnet create \
      --name "$MANAGEMENT_SUBNET_NAME" \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --vnet-name "$MAIN_VNET_NAME" \
      --address-prefix "$MANAGEMENT_SUBNET_CIDR"
}

function deploy_application_gateway() {
echo "$(date +"%Y-%m-%d %T") - Creating public IP address for Application Gateway..."
    az network public-ip create \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --name "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" \
      --dns-name "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" \
      --allocation-method "Static" \
      --sku "Standard"

    echo "$(date +"%Y-%m-%d %T") - Creating Application Gateway..."
    az network application-gateway create \
      --name "$APPLICATION_GATEWAY_NAME" \
      --location "$AZURE_LOCATION" \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --vnet-name "$MAIN_VNET_NAME" \
      --subnet "$APPLICATION_GATEWAY_SUBNET_NAME" \
      --sku "Standard_v2" \
      --public-ip-address "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" \
      --private-ip-address "$APPLICATION_GATEWAY_PRIVATE_IP_ADDRESS"

    echo "$(date +"%Y-%m-%d %T") - Assigning backend CA as root-cert for application gateway..."
    az network application-gateway root-cert create \
      --name "backend-ca-tls" \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --gateway-name "$APPLICATION_GATEWAY_NAME" \
      --cert-file "certs/ca/ca.crt"

    echo "$(date +"%Y-%m-%d %T") - Assigning frontend cert as ssl-cert for application gateway..."
    az network application-gateway ssl-cert create \
      --name "frontend-tls" \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --gateway-name "$APPLICATION_GATEWAY_NAME" \
      --cert-file "certs/frontend/frontend.pfx" \
      --cert-password "$CERTIFICATE_PRIVATE_KEY_PASSWORD"

    # Load some parameters that we'll use in other sections of the script
    APPLICATION_GATEWAY_ID=$(az network application-gateway show --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --name "$APPLICATION_GATEWAY_NAME" -o tsv --query 'id')
}

function deploy_aks_cluster() {
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
      --enable-managed-identity \
      --enable-private-cluster \
      --enable-aad \
      --aad-tenant-id "$AAD_TENANT_ID" \
      --aad-admin-group-object-ids "$AAD_ADMIN_GROUP_ID" \
      --dns-name-prefix "$CLUSTER_NAME" \
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
      --no-ssh-key \
      --ssh-key-value "$SSH_PUBLIC_KEY" \
      --vnet-subnet-id "$KUBERNETES_NODEPOD_SUBNET_ID"

    # When you use managed identities (-enable-managed-identity), AND you are specifying a VNET (--vnet-subnet-id), AND that VNET is in a resource group outside
    # of the auto-generated "MC_xxx_xxx" resource group, you must manually assign permimssions to the generated managed service identity, to that resource group
    echo "$(date +"%Y-%m-%d %T") - Assigning necessary permissions to the AKS managed service identity..."
    CLUSTER_MANAGED_SERVICE_IDENTITY_ID=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -o tsv --query "identity.principalId")
    SCOPES="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$INFRASTRUCTURE_RESOURCE_GROUP_NAME"

    az role assignment create \
      --assignee "$CLUSTER_MANAGED_SERVICE_IDENTITY_ID" \
      --role "Contributor" \
      --scope "$SCOPES"

    # Load some parameters that we'll use in other sections of the script
    KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)
}

# https://azure.github.io/aad-pod-identity/docs/getting-started/role-assignment/
function deploy_arm_identity_and_assign_permissions() {
    echo "$(date +"%Y-%m-%d %T") - Creating AAD ARM Azure Identity for Application Gateway..."
    az identity create --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME"

    echo "$(date +"%Y-%m-%d %T") - Sleeping for 30 seconds to ensure AAD Identity propagation..."
    sleep 30s

    IDENTITY_CLIENT_ID=$(az identity show --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "clientId")
    IDENTITY_ID=$(az identity show --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --name "$AAD_ARM_IDENTITY_NAME" -o tsv --query "id")

    echo "$(date +"%Y-%m-%d %T") - Assigning permissions to AAD identity for Application Gateway..."
    az role assignment create \
      --role "Contributor" \
      --assignee "$IDENTITY_CLIENT_ID" \
      --scope "$APPLICATION_GATEWAY_ID"

    echo "$(date +"%Y-%m-%d %T") - Assigning permissions to AAD identity for Application Gateway Resource Group..."
    az role assignment create \
      --role "Reader" \
      --assignee "$IDENTITY_CLIENT_ID" \
      --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$INFRASTRUCTURE_RESOURCE_GROUP_NAME"


    echo "$(date +"%Y-%m-%d %T") - Assigning permissions to AKS Cluster Managed Identity for Managed Identity Operator amd Virtual Machine Contributor..."
    CLUSTER_CLIENT_ID=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -o tsv --query "identityProfile.kubeletidentity.clientId")

    az role assignment create \
      --role "Managed Identity Operator" \
      --assignee "$CLUSTER_CLIENT_ID" \
      --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME"

    az role assignment create \
      --role "Virtual Machine Contributor" \
      --assignee "$CLUSTER_CLIENT_ID" \
      --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME"

    az role assignment create \
      --role "Managed Identity Operator" \
      --assignee $CLUSTER_CLIENT_ID \
      --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$INFRASTRUCTURE_RESOURCE_GROUP_NAME"
}

function deploy_jumpbox_vm() {
    echo "$(date +"%Y-%m-%d %T") - Creating jump box in management subnet..."
    
    echo "$(date +"%Y-%m-%d %T") - Accepting terms for VM image..."
    az vm image terms accept --urn "$JUMP_BOX_URN"

    echo "$(date +"%Y-%m-%d %T") - Deploying jump box VM image..."
    az vm create \
      --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" \
      --location "$AZURE_LOCATION" \
      --vnet-name "$MAIN_VNET_NAME" \
      --subnet "$MANAGEMENT_SUBNET_NAME" \
      --nsg "$NSG_NAME" \
      --image $JUMP_BOX_URN \
      --name "$JUMP_BOX_NAME" \
      --public-ip-address-dns-name "$JUMP_BOX_NAME" \
      --admin-username "$LINUX_ADMIN_USERNAME" \
      --ssh-key-values "$SSH_PUBLIC_KEY"
      
    VM_PUBLIC_IP_ADDRESS=$(az vm show -d --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --name "$JUMP_BOX_NAME" --query publicIps -o tsv)
    SSH_COMMAND="ssh -i keys/ssh.key $LINUX_ADMIN_USERNAME@$VM_PUBLIC_IP_ADDRESS"

    echo "Add a NSG rule to allow inbound port 22 for SSH to the VM, for your desired IP address..."
    echo "After completing that, you can use the following command to SSH into your VM:"
    echo $SSH_COMMAND
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
deploy_infrastructure_resource_group
deploy_network_security_group
deploy_main_vnet_with_aks_subnet
deploy_application_gateway_subnet
deploy_management_subnet
deploy_application_gateway
deploy_aks_cluster
deploy_arm_identity_and_assign_permissions
deploy_jumpbox_vm

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""