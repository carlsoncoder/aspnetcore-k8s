# How to use this repository
- Generate your certificates for the sample application by running /certs/create-certificates.sh
   - Use the same password for all private key values!
- Update all values in the deployment/variables file as necesary
- In the directory you plan to run the scripts, create a "certs" directory, and copy the following certificate files there:
   - ca.pem
   - backend.pfx
   - frontend.pem
   - frontend-key.pem
- Run the "aks-cluster-deploy.sh" script - this will do the following:
   - Deploy a resource group
   - Deploy an AKS cluster
   - Deploy a public IP address
   - Deploy an application gateway (with root cert)
   - Deploy a DNS CNAME record
- Run the "kubernetes-objects-deploy.sh" script - this will do the following:
   - Deploy a k8s secret with your backend.pfx file
   - Deploy a k8s secret with your private key password value
   - Deploy a k8s secret with your frontend certificate files (frontend.pem and frontend-key.pem)
   - Deploy three separate deployments of the 'sample' image for testing, with different "app-name" values
   - Deploy three separate k8s service objects, all of type ClusterIP, to match up with the above listed deployments
   - Download a YAML file for the AAD Pod Identity resources and apply it to your cluster
- Run the "arm-aad-identity-deploy.sh" script - this will do the following:
   - Create an Azure Managed Identity and assign it the necessary permissions
- Run the "agic-ingresscontroller-helm-deploy.sh" script - this will do the following:
   - Update your local helm repo
   - Deploy the Application Gateway Ingress Controller helm chart

# Deleting all resources when you're done
- Ensure all values in the deployment/variables file are correct
- Run the "delete-all-resources.sh" script - this will do the following:
   - Delete the DNS CNAME zone record
   - Delete the auto-generated Kubernetes Azure resource group
   - Delete the main Azure resource group

# Other stuff to review for future improvements:
- Get the "FRONTEND_HOSTNAME" out of the create-certificates.sh file, into variables file, and move create-certificates.sh to the deployment folder
- Get the deployment/kubernetes-ingress.yaml all updated and out of .gitignore file, and update README
- Certificate Updates
   - How is it handled when certificates need to be rotated (frontend, backend CA, backend, AppGW updates via az CLI, kubernetes secret updates, etc.)
- backend-path-prefix
   - [https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#backend-path-prefix](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#backend-path-prefix)
   - This is for URL routing - for example, if you have a path-based match to "/api", you can re-route it to the "/" path so you don't need to change paths on the backend service
- appgw-ssl-certificate
   - [https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#appgw-ssl-certificate](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#appgw-ssl-certificate)
   - If we do this (assign an ssl-cert to the gateway through the az CLI), I believe we would not need to specify the entire spec.tls section in the Kubernetes ingress, or need the frontend-tls secret in kubernetes either

