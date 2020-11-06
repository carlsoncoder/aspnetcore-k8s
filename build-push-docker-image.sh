#!/bin/bash

# Set later in the script
REGISTRY=""
FULL_IMAGE_NAME_WITH_REGISTRY=""

function load_variables() {
    export $(grep -v '#.*' deployment/variables | xargs)
}

function login() {  
    # Load the subscription ID
    echo "$(date +"%Y-%m-%d %T") - Loading subscription ID and setting active subscription..."
    SUBSCRIPTION_ID=$(az account show --subscription "$SUBSCRIPTION_NAME" --query 'id' -o tsv)

    # Set the active subscription (assumes you're already logged in, if not, run az login before running the script)
    az account set --subscription "$SUBSCRIPTION_ID"
}

function load_registry() {
    REGISTRY=$(az acr show --resource-group "$CONTAINER_REGISTRY_RESOURCE_GROUP_NAME" --name "$CONTAINER_REGISTRY_NAME" -o tsv --query "loginServer")
    FULL_IMAGE_NAME_WITH_REGISTRY="$REGISTRY/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG"

    USERNAME=$(az acr credential show --name "$CONTAINER_REGISTRY_NAME" -o tsv --query "username")
    PASSWORD=$(az acr credential show --name "$CONTAINER_REGISTRY_NAME" -o tsv --query "passwords[0].value")

    docker login "$REGISTRY" -u "$USERNAME" -p "$PASSWORD"
}

function delete_existing_images() {
    docker rmi "$DOCKER_IMAGE_NAME" --force
    docker rmi "$FULL_IMAGE_NAME_WITH_REGISTRY" --force
}

function build_and_push_image() {
    docker build --no-cache -t $DOCKER_IMAGE_NAME .
    docker tag $DOCKER_IMAGE_NAME $FULL_IMAGE_NAME_WITH_REGISTRY
    docker push $FULL_IMAGE_NAME_WITH_REGISTRY
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
login
load_registry
delete_existing_images
build_and_push_image

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""

