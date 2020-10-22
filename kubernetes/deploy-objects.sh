#!/bin/bash
# NOTE - Copy your PFX file to the same location as this backend script, and update the password below with your appropriate private key password
kubectl -n default create secret generic backend-wildcard-pfx --from-file=aspnetcore-k8s.pfx
kubectl -n default create secret generic backend-wildcard-pfx-password --from-literal=password='P@ssw0rd'

kubectl apply -f kubernetes-objects.yaml
