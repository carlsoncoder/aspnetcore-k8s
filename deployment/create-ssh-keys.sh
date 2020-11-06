#!/bin/bash
function validate_existing() {
    FILE=keys/ssh.key
    if test -f "$FILE"; then
        echo "The SSH keys have already been created - exiting script!"
        exit 1
    fi
}

function generate_keypair() {
    OUTPUT_FILE="$(pwd)/ssh"
    ssh-keygen -t rsa -b 4096 -f $OUTPUT_FILE

    rm -rf keys/
    mkdir keys
    mv ssh keys/ssh.key
    mv ssh.pub keys/ssh.pub
}

echo "$(date +"%Y-%m-%d %T") - Script starting..."

validate_existing
generate_keypair

echo "$(date +"%Y-%m-%d %T") - Script completed successfully!"
echo ""

