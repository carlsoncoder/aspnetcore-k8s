#!/bin/bash

function generate_ca() {
    echo "$(date +"%Y-%m-%d %T") - Generating Root CA certificate..."
    openssl genrsa -aes256 -out ca.key
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt -config certs/conf/ca.conf

    openssl pkcs12 -export -out ca.pfx -inkey ca.key -in ca.crt
    openssl x509 -inform pem -in ca.crt -outform der -out ca.cer
    openssl x509 -inform der -in ca.cer -out ca.pem
}

function generate_frontend_certificate() {
    echo "$(date +"%Y-%m-%d %T") - Generating frontend certificate..."
    openssl genrsa -aes256 -out frontend.key 2048
    openssl req -new -key frontend.key -out frontend.csr -config certs/conf/frontend.conf
    openssl x509 -req -in frontend.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out frontend.crt -days 365 -sha256 -extensions v3_ext -extfile certs/conf/frontend.conf
    openssl pkcs12 -export -out frontend.pfx -inkey frontend.key -in frontend.crt
    openssl x509 -inform pem -in frontend.crt -outform der -out frontend.cer
}

function generate_backend_certificate() {
    echo "$(date +"%Y-%m-%d %T") - Generating backend certificate..."
    openssl genrsa -aes256 -out backend.key 2048
    openssl req -new -key backend.key -out backend.csr -config certs/conf/backend.conf
    openssl x509 -req -in backend.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out backend.crt -days 365 -sha256 -extensions v3_ext -extfile certs/conf/backend.conf
    openssl pkcs12 -export -out backend.pfx -inkey backend.key -in backend.crt
    openssl x509 -inform pem -in backend.crt -outform der -out backend.cer
}

function move_all() {
    rm -rf certs/ca/
    rm -rf certs/backend/
    rm -rf certs/frontend/

    mkdir certs/ca
    mv ca.cer certs/ca/
    mv ca.crt certs/ca/
    mv ca.key certs/ca/
    mv ca.pem certs/ca/
    mv ca.pfx certs/ca/
    mv ca.srl certs/ca/

    mkdir certs/frontend
    mv frontend.cer certs/frontend/
    mv frontend.crt certs/frontend/
    mv frontend.csr certs/frontend/
    mv frontend.key certs/frontend/
    mv frontend.pfx certs/frontend/

    mkdir certs/backend
    mv backend.cer certs/backend/
    mv backend.crt certs/backend/
    mv backend.csr certs/backend/
    mv backend.key certs/backend/
    mv backend.pfx certs/backend/
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

generate_ca
generate_frontend_certificate
generate_backend_certificate
move_all

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""