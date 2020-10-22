# Make sure to run the /certs/create-certificates.sh file first!

1. Generate your certificates from the sample application
2. Run the "aks-cluster-deploy.sh" script, which will deploy the necessary Azure resources, including:
    - Resource Group
    - AKS Cluster
    - Public IP Address
    - Application Gateway
    - DNS CNAME Record
3. Copy your "backend.pfx" certificate you generated in step 1 to this directory
4. Update the "password" secret value in "kubernetes-objects-deploy.sh" with your private key password
5. Run the "kubernetes-objects-deploy.sh" file.  This will do the following:
    - Deploy a k8s secret with your backend.pfx file
    - Deploy a k8s secret with your private key password value
    - Deploy three separate deployments of the 'sample' image for testing, with different "app-name" values
    - Deploy three separate k8s service objects, all of type ClusterIP, to match up with the above listed deployments
    - Download a YAML file for the AAD Pod Identity resources and apply it to your cluster
6. Run the "arm-aad-identity-deploy.sh" file.  This will create an Azure Managed Identity and assign it the necessary permissions.
7. Run the "agic-ingresscontroller-helm-deploy.sh" file.  This will deploy the Application Gateway Ingress Controller object via helm