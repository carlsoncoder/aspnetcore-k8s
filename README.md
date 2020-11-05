# How to use this repository
- Update all values in the deployment/variables file as necesary
- Copy your public and private SSH key to the deployment directory, and rename the files to "ssh.pub" and "ssh.key" respectively
- Generate your certificates for the sample application by running the deployment/certs/create-certificates.sh script
   - Make sure to use the same password for all private key values!
   - Update the "CERTIFICATE_PRIVATE_KEY_PASSWORD" parameter in the variables file with the password you used
- Manually assign the ca.crt file as a trusted root on the machine you'll be accessing the gateway from
- Run the "deployment/deploy-azure-resources.sh" script - this will do the following:
   - Deploy an infrastructure resource group
   - Deploy a Network Security Group (into the infrastructure resource group)
   - Deploy a VNET (into the infrastructure resource group) with an "aks-cluster" subnet
   - Deploy an 'application gateway' subnet into the VNET
   - Deploy a 'management' subnet into the VNET
   - Deploy a public IP address
   - Deploy an application gateway (with root-cert (certs/ca/ca.crt) and ssl-cert (certs/frontend/frontend.pfx) set)
   - Deploy a resource group for the AKS cluster
   - Deploy an AKS cluster into that resource group
   - Create an Azure identity to be used by the AGIC, and assign all of the necessary Azure RBAC permissions and role assignments
   - Deploy a Linux jumpbox into the "management" subnet on the VNET
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
- Delete any CNAME records that were created as part of your ingress example chosen