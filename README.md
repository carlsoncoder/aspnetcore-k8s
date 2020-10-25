# How to use this repository
- Update your certificate config files
   - certs/conf/backend.conf - Set the "DNS.2" value under the "[ alt names ]" section to the wildcard of your externally availavbe DNS entry, such as "*.carlsoncoder.com"
   - certs/conf/frontend.conf - Set the "DNS.2" value under the "[ alt names ]" section to the wildcard of your externally availavbe DNS entry, such as "*.carlsoncoder.com"
- Generate your certificates for the sample application by running create-certificates.sh
   - Use the same password for all private key values!
- Update all values in the deployment/variables file as necesary
- In the directory you plan to run the scripts, create a "certs" directory, and copy the following certificate files there:
   - ca.crt
   - backend.pfx
   - frontend.pfx
- Manually assign the ca.crt file as a trusted root on the machine you'll be accessing the gateway from
- Manually update the "SSH_PUBLIC_KEY" parameter at the top of the "deployment/deploy-all.sh" script
- Run the "deployment/deploy-all.sh" script - this will do the following:
   - Deploy a resource group
   - Deploy an AKS cluster
   - Deploy a public IP address
   - Deploy an application gateway (with root-cert and ssl-cert)
   - Deploy a DNS CNAME record
   - Create an Azure identity to be used by the AGIC, and assign the appropriate permissions
   - Deploy a k8s secret with your backend.pfx file
   - Deploy a k8s secret with your private key password value
   - Update your local helm repo
   - Deploy the AAD Pod Identity helm chart
   - Deploy the Application Gateway Ingress Controller helm chart
- Ensure that the ingress controller pod is up and running successfully before the next step - You can do that with the following commands:
```
# Get the name of the pod
kubectl get pods | grep ingress-azure
# Use it to see the logs
kubectl logs POD_NAME_FROM_ABOVE
```
- Deploy the Kubernetes Deployment/Service objects
```
kubectl apply -f kubernetes-definitions.yaml
```
- Determine which ingress example you want to deploy (from the deployment/ingress-examples folder) and deploy it
```
kubectl apply -f ingress-examples/name-of-file.yaml
```

# Deleting all resources when you're done
- Delete the main resource group ($CLUSTER_RESOURCE_GROUP_NAME), the auto-generated resource group (Starting with "MC_"), and the DNS CNAME record

# Other stuff to review for future improvements:
- Update all the /deployment/ingress-examples example YAML files and add some detail (also update README.md and .gitignore files)
- Look into the "use-private-ip" annotation (for the private listenter example) - https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#use-private-ip
- Certificate Updates - how is it handled when certificates need to be rotated (frontend, backend CA, backend, AppGW updates via az CLI, kubernetes secret updates, etc.)