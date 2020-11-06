#!/bin/bash
function install_az_cli() {
    echo "$(date +"%Y-%m-%d %T") - Installing az CLI for Ubuntu..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}

function install_kubectl() {
    echo "$(date +"%Y-%m-%d %T") - Installing kubectl at latest version..."
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
}

function install_helm() {
    echo "$(date +"%Y-%m-%d %T") - Installing helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm -rf get_helm.sh
    
    helm repo add stable https://charts.helm.sh/stable
    helm repo update
}

function az_login() {
    echo "$(date +"%Y-%m-%d %T") - Validating we can login with 'az login'..."
    az login
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

install_az_cli
install_kubectl
install_helm
az_login

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""