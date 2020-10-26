# How to use this repository
- Update all values in the deployment/variables file as necesary
- Generate your certificates for the sample application by running the deployment/certs/create-certificates.sh script
   - Make sure to use the same password for all private key values!
   - Update the "CERTIFICATE_PRIVATE_KEY_PASSWORD" parameter in the variables file with the password you used
- Manually assign the ca.crt file as a trusted root on the machine you'll be accessing the gateway from
- Manually update the "SSH_PUBLIC_KEY" parameter at the top of the "deployment/deploy-all.sh" script
- Run the "deployment/deploy-all.sh" script - this will do the following:
   - Deploy a resource group
   - Deploy an AKS cluster
   - Deploy a public IP address
   - Deploy an application gateway (with root-cert (certs/ca/ca.crt) and ssl-cert (certs/frontend/frontend.pfx) set)
   - Deploy a DNS CNAME record
   - Create an Azure identity to be used by the AGIC, and assign the appropriate permissions
   - Deploy a k8s secret with your certs/backend/backend.pfx file
   - Deploy a k8s secret with your private key password value for the certs/backend/backend.pfx certificate
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
- Deploy an ingress example by running the deployment/ingress-examples/deploy-ingress-example.sh script
   - This will prompt you for an ingress example to deploy, and then deploy the Service, Deployment, and Ingress objects into Kubernetes


# Deleting all resources when you're done
- Delete the main resource group ($CLUSTER_RESOURCE_GROUP_NAME), the auto-generated resource group (Starting with "MC_"), and the DNS CNAME record

# Other stuff to review for future improvements:
- Look into the "use-private-ip" annotation (for the private listenter example) - https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#use-private-ip
- Certificate Updates - how is it handled when certificates need to be rotated (frontend, backend CA, backend, AppGW updates via az CLI, kubernetes secret updates, etc.)