# How to use this repository
- Update all values in the "deployment/variables" file as necesary
- Run the "deployment/create-ssh-keys.sh" script to create the public/private keypair
   - _NOTE: If you already have your own keypair, you can skip this script, and just move your files into the "deployment/keys" folder, named "ssh.pub" and "ssh.key" respectively for the public and private keys_
- Generate your certificates for the sample application by running the "deployment/certs/create-certificates.sh" script
   - Make sure to use the same password for all private key values!
   - Update the "CERTIFICATE_PRIVATE_KEY_PASSWORD" parameter in the "deployment/variables" file with the password you used
- Manually assign the ca.crt file as a trusted root on the machine you'll be accessing the gateway from (necessary since we are using self-signed certs, otherwise your browser will not trust the certificate)
- Run the "deployment/deploy-azure-resources.sh" script - this will do the following:
   - Deploy an infrastructure resource group with the following resources:
      - Network Security Group
      - VNET with three separate subnets (aks-subnet, appGWSubnet, management)
      - Public IP Address (for the Application Gateway)
      - Application Gateway (v2 SKU) (Also assigns ssl-cert and root-cert)
      - Linux VM Jumpbox
      - Managed Identity to use for the AGIC
   - Deploy a resource group with the following resources:
      - Azure Container Registry   
   -  Deploy a cluster resource group with the following resources:
      - AKS (Azure Kubernetes Service) Cluster
- Run the "build-push-docker-image.sh" script to build the docker image and push it to your newly created container registry
- Go into the Azure portal and then to the NSG tied to the jumpbox VM, and assign a new Inbound rule to allow port 22 (SSH) from your IP address
- Zip up the entire "deployment" directory:
   - tar -czvf deployment.tar.gz deployment/
- Copy the deployment file to your jumpbox with scp:
   - scp -i keys/ssh.key deployment.tar.gz VM_USERNAME@VM_IP_ADDRESS:/home/VM_USERNAME
- SSH into the jumpbox VM using your private key:
   - ssh -i keys/ssh.key VM_USERNAME@VM_IP_ADDRESS
- Extract the deployment.tar.gz file:
   - tar -xzvf deployment.tar.gz
- Run the "deployment/setup-jumpbox-vm.sh" script on the jumpbox VM - this will do the following:
   - Install the az CLI tool
   - Install kubectl at latest version
   - Install helm at latest 3.x version
- Run the "deployment/deploy-aad-agic.sh" script on the jumpbox VM - this will do the following:
   - Pull down the AKS admin credentials for your cluster (.kubeconfig)
   - Update your local helm repo
   - Deploy the AAD Pod Identity helm chart
   - Deploy the Application Gateway Ingress Controller helm chart
   - Apply the AAD Pod Identity MIC exceptions YAML file
- Ensure that the ingress controller pod is up and running successfully before the next step - You can do that with the following commands:
```
# Get the name of the pod
kubectl get pods | grep ingress-azure
# Use it to see the logs
kubectl logs POD_NAME_FROM_ABOVE
```
- Deploy an ingress example by running the deployment/deploy-ingress-example.sh script
   - This will prompt you for an ingress example to deploy
   - It will deploy one or more DNS CNAME records, based on the example chosen
   - It will also deploy the kubernes Secret, Service, Deployment, and Ingress objects via local Helm charts, based on the example chosen


# Deleting all resources when you're done
- Delete the auto-generated Kubernetes resource group (MC_xxx_xxx)
- Delete the AKS resource group ($CLUSTER_RESOURCE_GROUP_NAME)
- Delete the infrastructure resource group ($INFRASTRUCTURE_RESOURCE_GROUP_NAME)
- Delete the container registry resource group ($CONTAINER_REGISTRY_RESOURCE_GROUP_NAME)
- Delete any CNAME records that were created as part of your ingress example chosen


# TODO - FUTURE
- Look into seeing if we need to specify "--service-cidr" and "--dns-service-ip" in the "az aks create" command (is a new subnet needed too?)
- Update the backend certificate generation to use the "kubernetes.domain.com" instead of the wildcard it's using now
- Add a new helm chart for the single-tenant routing by path name (instead of hostname) example