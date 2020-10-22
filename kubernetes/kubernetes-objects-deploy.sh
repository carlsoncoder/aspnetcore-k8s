#!/bin/bash
# NOTE - Copy your PFX file to the same location as this backend script, and update the password below with your appropriate private key password
kubectl -n default create secret generic backend-wildcard-pfx --from-file=backend.pfx
kubectl -n default create secret generic backend-wildcard-pfx-password --from-literal=password='P@ssw0rd'

# Apply our Kubernetes objects
kubectl apply -f kubernetes-definitions.yaml

# Apply the AAD Pod Identity into our cluster
curl https://raw.githubusercontent.com/Azure/aad-pod-identity/v1.6.3/deploy/infra/deployment-rbac.yaml -o aad-pod-identity.yaml
kubectl apply -f aad-pod-identity.yaml
rm -rf aad-pod-identity.yaml
