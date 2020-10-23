# Make sure to run the /certs/create-certificates.sh file first!

- Generate your certificates for the sample application by running /certs/create-certificates.sh
- Update the "password" secret value in "kubernetes-objects-deploy.sh" with your certificate private key password
- In the directory you plan to run the scripts, create a "certs" directory, and copy the following certificate files there:
   - ca.pem
   - backend.pfx
   - frontend.pem
   - frontend-key.pem
- Run the "aks-cluster-deploy.sh" script, which will deploy the necessary Azure resources, including:
   - Resource Group
   - AKS Cluster
   - Public IP Address
   - Application Gateway
   - DNS CNAME Record
- Run the "kubernetes-objects-deploy.sh" file.  This will do the following:
   - Deploy a k8s secret with your backend.pfx file
   - Deploy a k8s secret with your private key password value
   - Deploy a secret with your frontend certificate files (frontend.pem and frontend-key.pem)
   - Deploy three separate deployments of the 'sample' image for testing, with different "app-name" values
   - Deploy three separate k8s service objects, all of type ClusterIP, to match up with the above listed deployments
   - Download a YAML file for the AAD Pod Identity resources and apply it to your cluster
- Run the "arm-aad-identity-deploy.sh" file.  This will create an Azure Managed Identity and assign it the necessary permissions.
- Run the "agic-ingresscontroller-helm-deploy.sh" file.  This will deploy the Application Gateway Ingress Controller object via helm

# Update "application deployment" guidance (https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/how-tos/minimize-downtime-during-deployments.md)
    # Specifically, the "preStop lifecycle hook", "terminationGracePeriodSeconds", and "aggressive liveness probes" parts - should be in every deploy

# Look into the UPDATE cert process - when we need to update backend cert, backend CA cert, or front-end cert

# Add note on how to delete (delete main resource group, kubernetes MC resource group, and DNS record-set)

# Remove my "specific" parameter values in the files in the kubernetes/ directory, then remove them from .gitignore

# See if there is a way to have a single "parameters.json" file that is read in by the multiple bash scripts

# Create a Bash Script that runs all the individual bash scripts

# OTHER STUFF TO LOOK AT - BOTH FROM HERE: https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md

// For routing urls - if the path-based match is "/api", you can re-route it to "/" so you don't need to change paths on the backend service
appgw.ingress.kubernetes.io/backend-path-prefix: <path prefix>

// I THINK that if you do this, you don't need to specify the entire "spec.tls" section on the ingress rule (and wouldn't need the k8s secret either)
appgw.ingress.kubernetes.io/appgw-ssl-certificate: "name-of-appgw-installed-certificate"

    

