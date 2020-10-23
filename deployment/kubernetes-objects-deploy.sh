#!/bin/bash

function load_variables() {
    export $(grep -v '#.*' variables | xargs)
}

function create_kubernetes_secrets() {
    kubectl -n default create secret generic backend-wildcard-pfx --from-file="certs/backend.pfx"
    kubectl -n default create secret generic backend-wildcard-pfx-password --from-literal=password="$CERTIFICATE_PRIVATE_KEY_PASSWORD"
    kubectl -n default create secret tls frontend-tls --key "certs/frontend-key.pem" --cert "certs/frontend.pem"
}

function apply_kubernetes_objects() {
    kubectl apply -f kubernetes-definitions.yaml
}

function apply_aad_pod_identity_to_cluster() {
    curl https://raw.githubusercontent.com/Azure/aad-pod-identity/v1.6.3/deploy/infra/deployment-rbac.yaml -o aad-pod-identity.yaml
    kubectl apply -f aad-pod-identity.yaml
    rm -rf aad-pod-identity.yaml
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
create_kubernetes_secrets
apply_kubernetes_objects
apply_aad_pod_identity_to_cluster

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""