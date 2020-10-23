#!/bin/bash

# This will be defined later in the script
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

function delete_dns_cname_record() {
    # We do this separately since the DNS CNAME record will usually be tied to a separate resource group besides the ones we already created
    echo "$(date +"%Y-%m-%d %T") - Deleting CNAME DNS Record Set..."
    az network dns record-set cname delete \
      --resource-group "$DNS_RESOURCE_GROUP" \
      --name "$DNS_DESIRED_HOSTNAME" \
      --zone-name "$DNS_ZONE_NAME" \
      --yes
}

function delete_resource_groups() {
    echo "$(date +"%Y-%m-%d %T") - Deleting generated kubernetes resource group..."
    KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)
    az group delete --name "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --yes

    echo "$(date +"%Y-%m-%d %T") - Deleting primary resource group..."
    az group delete --name "$CLUSTER_RESOURCE_GROUP_NAME" --yes
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
delete_dns_cname_record
delete_resource_groups

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""