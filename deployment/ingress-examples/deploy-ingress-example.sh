#!/bin/bash
DEFAULT_HOST_FQDN="test.carlsoncoder.com"
DESIRED_HOST_FQDN=""

function load_variables() {
    export $(grep -v '#.*' ../variables | xargs)
    DESIRED_HOST_FQDN=$DNS_DESIRED_HOSTNAME.$DNS_ZONE_NAME
}

function deploy_ingress_example() {
    echo "Please select an ingress example to deploy:"
    echo "1 - Multi-tenant, with single backend"
    echo "2 - Multi-tenant, with multiple backends"

    INGRESS_YAML_FILE=""

    read SELECTED_INGRESS_EXAMPLE
    case $SELECTED_INGRESS_EXAMPLE in
        1)
            INGRESS_YAML_FILE="multi-tenant-single-backend-ingress.yaml"
            ;;

        2)
            INGRESS_YAML_FILE="multi-tenant-multi-backend-ingress.yaml"
            ;;

        *)
            echo "Invalid option specified - script exiting!"
            exit 1
            ;;
    esac

    # Generate the temp YAML file so we can update it
    TEMP_YAML_FILE_NAME="$INGRESS_YAML_FILE.temp"
    cp $INGRESS_YAML_FILE $TEMP_YAML_FILE_NAME

    # Update the hostname in the file
    # Note - This "sed" command may fail on some OSX systems, but *should* work on *nix systems
    sed -i "s/${DEFAULT_HOST_FQDN}/${DESIRED_HOST_FQDN}/" $TEMP_YAML_FILE_NAME

    # Apply the objects to kubernetes
    kubectl apply -f $TEMP_YAML_FILE_NAME

    # Delete the temp file
    rm -rf $TEMP_YAML_FILE_NAME
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
deploy_ingress_example

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""