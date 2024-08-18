#!/bin/bash

# Find the directory of this script and change to it
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

function help() {
    echo "Usage: $0 [--generate|--push|--build]"
    exit 1
}

# Defaults for 
DOCKER_ORG="resurgentech"
DOCKER_HOST="dockerhost.hulbert.local"
PORTAINER_USER_GROUP="dhcpcd:hulbert"
OPENSSL_SUBJ='-subj "/C=US/ST=CA/L=Cameron Park/O=Resurgent Technologies"'
VOLUME_PATH="/var/lib/docker/volumes/openbao_config/_data"

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
        --docker-host)
            DOCKER_HOST="$2"
            shift 2
            ;;
        --portainer-user-group)
            PORTAINER_USER_GROUP="$2"
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
elif [ "$COMMAND" == "push" ]; then
    echo "Pushing keys..."
    ssh $DOCKER_HOST "mkdir -p /tmp/keys"
    scp keys/full-chain.pem $DOCKER_HOST:/tmp/keys
    scp keys/private-key.pem $DOCKER_HOST:/tmp/keys
    scp downloads/config.hcl $DOCKER_HOST:/tmp/keys

    echo "#!/bin/bash" > ./keys/fixer.sh
    echo "mkdir -p $VOLUME_PATH/certs" >> ./keys/fixer.sh
    echo "cp /tmp/keys/full-chain.pem $VOLUME_PATH/certs" >> ./keys/fixer.sh
    echo "cp /tmp/keys/private-key.pem $VOLUME_PATH/certs" >> ./keys/fixer.sh
    echo "cp /tmp/keys/config.hcl $VOLUME_PATH/" >> ./keys/fixer.sh
    echo "rm -rf /tmp/keys" >> ./keys/fixer.sh
    echo "chmod 755 $VOLUME_PATH/certs/" >> ./keys/fixer.sh
    echo "chown -R $PORTAINER_USER_GROUP $VOLUME_PATH/certs/full-chain.pem" >> ./keys/fixer.sh
    echo "chmod 644 $VOLUME_PATH/certs/full-chain.pem" >> ./keys/fixer.sh
    echo "chown -R $PORTAINER_USER_GROUP $VOLUME_PATH/certs/private-key.pem" >> ./keys/fixer.sh
    echo "chmod 644 $VOLUME_PATH/certs/private-key.pem" >> ./keys/fixer.sh
    echo "chown -R $PORTAINER_USER_GROUP $VOLUME_PATH/config.hcl" >> ./keys/fixer.sh
    echo "chmod 644 $VOLUME_PATH/config.hcl" >> ./keys/fixer.sh
    scp keys/fixer.sh $DOCKER_HOST:/tmp/keys
    rm -rf ./keys/fixer.sh
    ssh $DOCKER_HOST "chmod +x /tmp/keys/fixer.sh"
    stty -echo
    ssh $DOCKER_HOST "sudo -S /tmp/keys/fixer.sh"
    stty echo
elif [ "$COMMAND" == "build" ]; then
    docker build -f Dockerfile.openbao . -t $DOCKER_ORG/openbao
fi