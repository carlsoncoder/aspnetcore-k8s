#!/bin/bash

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

function deploy_ingress_example() {
    echo "Please select an ingress example to deploy:"
    echo "1 - Multi-tenant, with multiple backends"
    echo "2 - Single-tenant, with multiple backends, multiple hostnames (routing at hostname level)"

    read SELECTED_INGRESS_EXAMPLE
    case $SELECTED_INGRESS_EXAMPLE in
        1)
            echo "$(date +"%Y-%m-%d %T") - Deploying multi-tenant, multiple backends example..."
            deploy_multi_tenant_example
            ;;

        2)
            echo "$(date +"%Y-%m-%d %T") - Deploying single-tenant, multiple backend, multiple hostnames (routing at hostname level) example..."
            deploy_single_tenant_example
            ;;

        *)
            echo "Invalid option specified - script exiting!"
            exit 1
            ;;
    esac
}

function deploy_multi_tenant_example() {
    deploy_tenant_resources "$DNS_DESIRED_HOSTNAME"
}

function deploy_single_tenant_example() {
    echo "Enter first tenant code..."
    read TENANT_1

    echo "Enter second tenant code..."
    read TENANT_2

    deploy_tenant_resources $TENANT_1
    deploy_tenant_resources $TENANT_2
}

function deploy_tenant_resources() {
    # $1 = Tenant code (such as "abcd1234")
    DESIRED_HOST_FQDN=$1.$DNS_ZONE_NAME
    create_dns_record "$1"
    
    # Eventually it would be nice to do the kubernetes namespace creation, and PFX certificate secret creation via helm
    KUBERNETES_NAMESPACE="$1"
    create_kubernetes_namespace "$KUBERNETES_NAMESPACE"
    create_kubernetes_certificate_secret "$KUBERNETES_NAMESPACE"

    CHART_NAME="multi-service-backend-$KUBERNETES_NAMESPACE"

    ORIGINAL_DIR=$(pwd)
    cd helm/

    helm install $CHART_NAME \
      multi-service-backend/ \
      --namespace "$KUBERNETES_NAMESPACE" \
      --set image.repository="carlsoncoder/aspnetcore-k8s" \
      --set image.tag="v5" \
      --set certificatePassword="$CERTIFICATE_PRIVATE_KEY_PASSWORD" \
      --set ingress.backendHostName="$DESIRED_HOST_FQDN" \
      --set ingress.listenerHostName="$DESIRED_HOST_FQDN"

    cd "$ORIGINAL_DIR"
}

function create_dns_record() {
    # $1 = Tenant code (such as "abcd1234"), or application name (such as "calc1" (as in calc1.domain.com))
    APPLICATION_GATEWAY_PUBLIC_IP_FQDN=$(az network public-ip show --resource-group "$INFRASTRUCTURE_RESOURCE_GROUP_NAME" --name "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" -o tsv --query dnsSettings.fqdn)

    echo "$(date +"%Y-%m-%d %T") - Creating empty CNAME DNS Record Set..."
    az network dns record-set cname create \
      --resource-group "$DNS_RESOURCE_GROUP" \
      --name "$1" \
      --zone-name "$DNS_ZONE_NAME" \
      --ttl 3600

    echo "$(date +"%Y-%m-%d %T") - Assigning alias value to CNAME DNS Record Set..."
    az network dns record-set cname set-record \
      --resource-group "$DNS_RESOURCE_GROUP" \
      --record-set-name "$1" \
      --zone "$DNS_ZONE_NAME" \
      --cname "$APPLICATION_GATEWAY_PUBLIC_IP_FQDN" \
      --ttl 3600
}

function create_kubernetes_namespace() {
    # $1 = Tenant code (such as "abcd1234")
    echo "$(date +"%Y-%m-%d %T") - Creating kubernetes namespace..."
    kubectl create ns "$1"
}

function create_kubernetes_certificate_secret() {
    # $1 = Tenant code (such as abcd1234)
    echo "$(date +"%Y-%m-%d %T") - Creating kubernetes secrets..."
    kubectl -n "$1" create secret generic backend-wildcard-pfx-cert --from-file="certs/backend/backend.pfx"
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
deploy_ingress_example

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""