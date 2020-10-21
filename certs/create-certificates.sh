#!/bin/bash
# Derived from https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md

FILE=aspnetcore-k8s.pfx
if [ -f "$FILE" ]; then
    echo "Certificates have already been created, aborting script!"
    exit 1
fi

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

cat > aspnetcore-k8s-csr.json <<EOF
{
  "CN": "*.svc.cluster.local",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Hartford",
      "O": "aspnetcore-k8s",
      "OU": "*.svc.cluster.local",
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
  aspnetcore-k8s-csr.json | cfssljson -bare aspnetcore-k8s

# Now we need to use the private and public key PEM files to generate a PFX file
# Make sure you update your Dockerfile with the appropriate password you are asked to enter for this command!
openssl pkcs12 -inkey aspnetcore-k8s-key.pem -in aspnetcore-k8s.pem -export -out aspnetcore-k8s.pfx

mkdir other

mv aspnetcore-k8s-csr.json other/
mv aspnetcore-k8s-key.pem other/
mv aspnetcore-k8s.csr other/
mv aspnetcore-k8s.pem other/
mv ca-config.json other/
mv ca-csr.json other/
mv ca-key.pem other/
mv ca.csr other/
mv ca.pem other/