# TODO
- JUSTIN: Add something to the deploy-all.sh script that will force the user to login (like "kubectl get nodes" for example)
   - This will load up the .kubeconfig appropriately.
   - Should probably do this right before any of the "helm" calls (i.e., before the "add_update_helm_repos" function is called)

# How to use this repository
- Update all values in the deployment/variables file as necesary
- Copy your public SSH key to the deployment directory, and rename the file to "ssh.pub"
- Generate your certificates for the sample application by running the deployment/certs/create-certificates.sh script
   - Make sure to use the same password for all private key values!
   - Update the "CERTIFICATE_PRIVATE_KEY_PASSWORD" parameter in the variables file with the password you used
- Manually assign the ca.crt file as a trusted root on the machine you'll be accessing the gateway from
- Run the "deployment/deploy-all.sh" script - this will do the following:
   - Deploy a resource group
   - Deploy an AKS cluster
   - Deploy a public IP address
   - Deploy an application gateway (with root-cert (certs/ca/ca.crt) and ssl-cert (certs/frontend/frontend.pfx) set)
   - Create an Azure identity to be used by the AGIC, and assign the appropriate permissions
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
   - This will prompt you for an ingress example to deploy
   - It will deploy one or more DNS CNAME records, based on the example chosen
   - It will also deploy the kubernes Secret, Service, Deployment, and Ingress objects, based on the example chosen

# Deleting all resources when you're done
- Delete the main resource group ($CLUSTER_RESOURCE_GROUP_NAME), the auto-generated resource group (Starting with "MC_"), and any DNS CNAME records that were created as part of your ingress example chosen

# Other stuff to review for future improvements:
- "use-private-ip"
   - Look into the "use-private-ip" annotation (for the private listenter example) [here](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#use-private-ip)
- Certificate Updates - how is it handled when certificates need to be rotated (AppGW (ssl-cert and root-cert), and Kubernetes (backend.pfx))