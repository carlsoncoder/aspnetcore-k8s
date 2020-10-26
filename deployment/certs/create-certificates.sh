#!/bin/bash

DEFAULT_WILDCARD_HOSTNAME="*.carlsoncoder.com"

# Will be set later in the script
WILDCARD_HOST_NAME=""

function load_variables() {
    export $(grep -v '#.*' ../variables | xargs)
    WILDCARD_HOST_NAME="*.$DNS_ZONE_NAME"
}

function validate_existing() {
    FILE=ca/ca.key
    if test -f "$FILE"; then
        echo "The certificates have already been created - exiting script!"
        exit 1
    fi
}

function generate_ca() {
    echo "$(date +"%Y-%m-%d %T") - Generating Root CA certificate..."
    openssl genrsa -aes256 -out ca.key
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt -config conf/ca.conf

    openssl pkcs12 -export -out ca.pfx -inkey ca.key -in ca.crt
    openssl x509 -inform pem -in ca.crt -outform der -out ca.cer
    openssl x509 -inform der -in ca.cer -out ca.pem
}

function generate_certificate() {
    # $1 - boolean - if true generate backend certs, otherwise generate frontend certs
    FILE_PREFIX="frontend"
    if [ "$1" = true ]; then
        FILE_PREFIX="backend"
        echo "$(date +"%Y-%m-%d %T") - Generating backend certificate..."
    else
        echo "$(date +"%Y-%m-%d %T") - Generating frontend certificate..."
    fi

    # Generate the conf temp file so we can update it
    CONF_TEMP_FILE_NAME="conf/$FILE_PREFIX.temp.conf"
    cp "conf/$FILE_PREFIX.conf" $CONF_TEMP_FILE_NAME

    # Update the wildcard hostname in the temp file
    sed -i "" "s/${DEFAULT_WILDCARD_HOSTNAME}/${WILDCARD_HOST_NAME}/" $CONF_TEMP_FILE_NAME

    openssl genrsa -aes256 -out $FILE_PREFIX.key 2048
    openssl req -new -key $FILE_PREFIX.key -out $FILE_PREFIX.csr -config $CONF_TEMP_FILE_NAME
    openssl x509 -req -in $FILE_PREFIX.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out $FILE_PREFIX.crt -days 365 -sha256 -extensions v3_ext -extfile $CONF_TEMP_FILE_NAME
    openssl pkcs12 -export -out $FILE_PREFIX.pfx -inkey $FILE_PREFIX.key -in $FILE_PREFIX.crt
    openssl x509 -inform pem -in $FILE_PREFIX.crt -outform der -out $FILE_PREFIX.cer

    # Delete the temp conf file
    rm -rf $CONF_TEMP_FILE_NAME
}

function move_all() {
    rm -rf ca/
    rm -rf backend/
    rm -rf frontend/

    mkdir ca
    mv ca.cer ca/
    mv ca.crt ca/
    mv ca.key ca/
    mv ca.pem ca/
    mv ca.pfx ca/
    mv ca.srl ca/

    mkdir frontend
    mv frontend.cer frontend/
    mv frontend.crt frontend/
    mv frontend.csr frontend/
    mv frontend.key frontend/
    mv frontend.pfx frontend/

    mkdir backend
    mv backend.cer backend/
    mv backend.crt backend/
    mv backend.csr backend/
    mv backend.key backend/
    mv backend.pfx backend/
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

load_variables
validate_existing
generate_ca
generate_certificate true
generate_certificate false
move_all

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""