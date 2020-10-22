#!/bin/bash
# Derived from https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md

# YOU MUST SET THIS TO YOUR DESIRED FRONTEND HOSTNAME!!!
FRONTEND_HOSTNAME=""

BACKEND_CERT_NAME="backend"
KUBERNETES_BACKEND_HOSTNAME="*.svc.cluster.local"
FRONTEND_CERT_NAME="frontend"

function validation() {
  if [ -z "$FRONTEND_HOSTNAME" ]; then
    echo "Frontend hostname not defined, exiting script!"
    cd ..
    exit 1
  fi

  DIR="ca"
  if [ -d "$DIR" ]; then
    echo "Certificates have already been created, exiting script!"
    cd ..
    exit 1
  fi
}

function generate-ca() {
  cat > ca-config.json <<EOF
  {
    "signing": {
      "default": {
        "expiry": "8760h"
      },
      "profiles": {
        "kubernetes": {
          "usages": ["signing", "key encipherment", "server auth", "client auth"],
          "expiry": "8760h"
        }
      }
    }
  }
EOF

  cat > ca-csr.json <<EOF
  {
    "CN": "Kubernetes",
    "key": {
      "algo": "rsa",
      "size": 2048
    },
    "names": [
      {
        "C": "US",
        "L": "Hartford",
        "O": "Kubernetes",
        "OU": "CA",
        "ST": "Wisconsin"
      }
    ]
  }
EOF

  cfssl gencert -initca ca-csr.json | cfssljson -bare ca

  # Now we need to use the private and public key PEM files to generate a PFX file
  openssl pkcs12 -inkey ca-key.pem -in ca.pem -export -out ca.pfx
}

function move-ca-files() {
  mkdir ca

  mv ca-config.json ca/
  mv ca-csr.json ca/
  mv ca-key.pem ca/
  mv ca.csr ca/
  mv ca.pem ca/
  mv ca.pfx ca/
}

function generate-certificate() {
  # $1 - file-name-prefix, i.e., "aspnetcore-k8s"
  # $2 - CN - such as "*.svc.cluster.local"
  cat > $1-csr.json <<EOF
  {
    "CN": "$2",
    "key": {
      "algo": "rsa",
      "size": 2048
    },
    "names": [
      {
        "C": "US",
        "L": "Hartford",
        "O": "$1",
        "OU": "$2",
        "ST": "Wisconsin"
      }
    ]
  }
EOF

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=*.svc.cluster.local \
    -profile=kubernetes \
    $1-csr.json | cfssljson -bare $1

  # Now we need to use the private and public key PEM files to generate a PFX file
  # Make sure you update your Dockerfile with the appropriate password you are asked to enter for this command!
  openssl pkcs12 -inkey $1-key.pem -in $1.pem -export -out $1.pfx

  mkdir $1

  mv $1-csr.json $1/
  mv $1-key.pem $1/
  mv $1.csr $1/
  mv $1.pem $1/
  mv $1.pfx $1/
}

cd certs/

validation
generate-ca
generate-certificate $BACKEND_CERT_NAME $KUBERNETES_BACKEND_HOSTNAME
generate-certificate $FRONTEND_CERT_NAME $FRONTEND_HOSTNAME
move-ca-files

echo "Script completed successfully!"
cd ..