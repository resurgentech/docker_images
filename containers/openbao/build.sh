#!/bin/bash

# Find the directory of this script and change to it
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

function help() {
    echo "Usage: $0 [--generate|--push|--build]"
    exit 1
}

DOCKER_ORG="resurgentech"
OPENSSL_SUBJ='-subj "/C=US/ST=CA/L=Cameron Park/O=Resurgent Technologies"'

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --generate|--push|--build)
            if [[ -n "$COMMAND" ]]; then
                echo "Only one of --generate, --push, or --build can be specified."
                echo ""
                help
            fi
            COMMAND="${1#--}"
            shift
            ;;
        --docker-org)
            DOCKER_ORG="$2"
            shift 2
            ;;
        --manual-openssl-subj)
            # Set OPENSSL_SUBJ to an empty string to disable the default subject
            OPENSSL_SUBJ=""
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done



if [ "$COMMAND" == "generate" ]; then
    echo "Generating keys..."
    if [ -d ./keys ]; then
        echo "Keys already exist. Skipping generation."
        echo "Do you want to overwrite them? (y/n)"
        read -r overwrite
        if [ "$overwrite" != "y" ]; then
            echo "Overwriting keys..."
            rm -rf ./keys
        else
            echo "Not overwriting keys. Exiting."
            exit 1
        fi
    fi
    mkdir -p ./keys
    cd ./keys
    openssl genpkey -algorithm RSA -out private-key.pem
    CMD="openssl req -new $OPENSSL_SUBJ -key private-key.pem -out cert.csr"
    eval "$CMD"
    openssl x509 -req -days 365 -in cert.csr -signkey private-key.pem -out full-chain.pem

    FKEYMD5=$(openssl x509 -noout -modulus -in full-chain.pem | openssl md5)
    PKEYMD5=$(openssl rsa -noout -modulus -in private-key.pem | openssl md5)
    if [ "$FKEYMD5" != "$PKEYMD5" ]; then
        echo "Error: public key and private key do not match."
    else
        echo "Public key and private key match. $FKEYMD5 $PKEYMD5"
    fi
    cd ..
elif [ "$COMMAND" == "build" ]; then
    docker build -f Dockerfile.openbao . -t $DOCKER_ORG/openbao
fi