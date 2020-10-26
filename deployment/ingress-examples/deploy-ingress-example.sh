#!/bin/bash
DEFAULT_HOST_FQDN="test.carlsoncoder.com"
DESIRED_HOST_FQDN=""

function load_variables() {
    export $(grep -v '#.*' ../variables | xargs)
}

function deploy_ingress_example() {
    echo "Please select an ingress example to deploy:"
    echo "1 - Multi-tenant, with single backend"
    echo "2 - Multi-tenant, with multiple backends"
    echo "3 - Single-tenant, with single backend, multiple hostnames (routing at hostname level)"
    echo "4 - Single-tenant, with multiple backends, multiple hostnames (routing at hostname level)"
    echo "5 - Single-tenant, multiple backends, SINGLE hostname (routing at path level)"

    INGRESS_YAML_FILE=""

    read SELECTED_INGRESS_EXAMPLE
    case $SELECTED_INGRESS_EXAMPLE in
        1)
            INGRESS_YAML_FILE="multi-tenant-single-backend-ingress.yaml"
            echo "$(date +"%Y-%m-%d %T") - Deploying multi-tenant, single backend example..."
            deploy_multi_tenant_example $INGRESS_YAML_FILE
            ;;

        2)
            INGRESS_YAML_FILE="multi-tenant-multi-backend-ingress.yaml"
            echo "$(date +"%Y-%m-%d %T") - Deploying multi-tenant, multiple backends example..."
            deploy_multi_tenant_example $INGRESS_YAML_FILE
            ;;

        3)
            echo "$(date +"%Y-%m-%d %T") - Deploying single-tenant, single backend, multiple hostnames (routing at hostname level) example..."
            INGRESS_YAML_FILE="single-tenant-single-backend-ingress.yaml"
            deploy_single_tenant_example $INGRESS_YAML_FILE
            ;;

        4)
            echo "$(date +"%Y-%m-%d %T") - Deploying single-tenant, multiple backend, multiple hostnames (routing at hostname level) example..."
            INGRESS_YAML_FILE="single-tenant-multi-backend-ingress.yaml"
            deploy_single_tenant_example $INGRESS_YAML_FILE
            ;;

        5)
            echo "$(date +"%Y-%m-%d %T") - Deploying single-tenant, multiple backend, SINGLE hostname (routing at path level) example..."
            INGRESS_YAML_FILE="single-tenant-multi-backend-single-hostname-ingress.yaml"
            deploy_single_tenant_single_hostname_example $INGRESS_YAML_FILE
            ;;

        *)
            echo "Invalid option specified - script exiting!"
            exit 1
            ;;
    esac
}

function deploy_multi_tenant_example() {
    # $1 - Name of the YAML file to update/deploy
    INGRESS_YAML_FILE=$1

    create_kubernetes_secrets "default"
    create_dns_record "$DNS_DESIRED_HOSTNAME"

    DESIRED_HOST_FQDN=$DNS_DESIRED_HOSTNAME.$DNS_ZONE_NAME

    # Generate the temp YAML file so we can update it
    TEMP_YAML_FILE_NAME="$INGRESS_YAML_FILE.temp"
    cp $INGRESS_YAML_FILE $TEMP_YAML_FILE_NAME

    # Update the hostname in the file
    # Note - This "sed" command may fail on some OSX systems, but *should* work on *nix systems
    sed -i "s/${DEFAULT_HOST_FQDN}/${DESIRED_HOST_FQDN}/" $TEMP_YAML_FILE_NAME

    # Apply the objects to kubernetes
    echo "$(date +"%Y-%m-%d %T") - Applying kubernetes objects..."
    kubectl apply -f $TEMP_YAML_FILE_NAME

    # Delete the temp file
    rm -rf $TEMP_YAML_FILE_NAME
}

function deploy_single_tenant_example() {
    # $1 - Name of the YAML file to update/deploy
    echo "Enter first tenant code..."
    read TENANT_1

    echo "Enter second tenant code..."
    read TENANT_2

    create_deploy_tenant_resources $TENANT_1 $1
    create_deploy_tenant_resources $TENANT_2 $1
}

function deploy_single_tenant_single_hostname_example() {
    # $1 - Name of the YAML file to update/deploy
    echo "Enter first tenant code..."
    read TENANT_1

    echo "Enter second tenant code..."
    read TENANT_2

    create_kubernetes_secrets "default"
    create_dns_record "$DNS_DESIRED_HOSTNAME"

    DESIRED_HOST_FQDN=$DNS_DESIRED_HOSTNAME.$DNS_ZONE_NAME

    # Generate the temp YAML file so we can update it
    TEMP_YAML_FILE_NAME="$INGRESS_YAML_FILE.temp"
    cp $INGRESS_YAML_FILE $TEMP_YAML_FILE_NAME

    # Update the Tenant tokens in the file
    # Note - This "sed" command may fail on some OSX systems, but *should* work on *nix systems
    sed -i "s/TENANT_1/${TENANT_1}/" $TEMP_YAML_FILE_NAME
    sed -i "s/TENANT_2/${TENANT_2}/" $TEMP_YAML_FILE_NAME

    # Update the hostname in the file
    # Note - This "sed" command may fail on some OSX systems, but *should* work on *nix systems
    sed -i "s/${DEFAULT_HOST_FQDN}/${DESIRED_HOST_FQDN}/" $TEMP_YAML_FILE_NAME

    # Apply the objects to kubernetes
    echo "$(date +"%Y-%m-%d %T") - Applying kubernetes objects..."
    kubectl apply -f $TEMP_YAML_FILE_NAME

    # Delete the temp file
    rm -rf $TEMP_YAML_FILE_NAME
}

create_deploy_tenant_resources() {
    # $1 = Tenant code (such as "abcd1234")
    # $2 = The name of the YAML file to update/deploy    
    create_dns_record $1
    create_kubernetes_namespace $1
    create_kubernetes_secrets $1

    INGRESS_YAML_FILE=$2
    
    DESIRED_HOST_FQDN=$1.$DNS_ZONE_NAME

    # Generate the temp YAML file so we can update it
    TEMP_YAML_FILE_NAME="$INGRESS_YAML_FILE.temp"
    cp $INGRESS_YAML_FILE $TEMP_YAML_FILE_NAME
    
    # Update the TENANT_NAMESPACE in the file
    # Note - This "sed" command may fail on some OSX systems, but *should* work on *nix systems
    sed -i "s/TENANT_NAMESPACE/${1}/" $TEMP_YAML_FILE_NAME

    # Update the hostname in the file
    # Note - This "sed" command may fail on some OSX systems, but *should* work on *nix systems
    sed -i "s/${DEFAULT_HOST_FQDN}/${DESIRED_HOST_FQDN}/" $TEMP_YAML_FILE_NAME

    # Apply the objects to kubernetes
    echo "$(date +"%Y-%m-%d %T") - Applying kubernetes objects..."
    kubectl apply -f $TEMP_YAML_FILE_NAME

    # Delete the temp file
    rm -rf $TEMP_YAML_FILE_NAME
}

function create_dns_record() {
    # $1 = Tenant code (such as "abcd1234"), or application name (such as "calc1" (as in calc1.domain.com))
    KUBERNETES_GENERATED_RESOURCE_GROUP_NAME=$(az aks show --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" --query nodeResourceGroup -o tsv)
    APPLICATION_GATEWAY_PUBLIC_IP_FQDN=$(az network public-ip show --resource-group "$KUBERNETES_GENERATED_RESOURCE_GROUP_NAME" --name "$APPLICATION_GATEWAY_PUBLIC_IP_NAME" -o json --query dnsSettings.fqdn)
    APPLICATION_GATEWAY_PUBLIC_IP_FQDN=${APPLICATION_GATEWAY_PUBLIC_IP_FQDN:1:-1}

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

function create_kubernetes_secrets() {
    # $1 = Tenant code (such as abcd1234)
    echo "$(date +"%Y-%m-%d %T") - Creating kubernetes secrets..."
    kubectl -n "$1" create secret generic backend-wildcard-pfx --from-file="certs/backend/backend.pfx"
    kubectl -n "$1" create secret generic backend-wildcard-pfx-password --from-literal=password="$CERTIFICATE_PRIVATE_KEY_PASSWORD"
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
deploy_ingress_example

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""