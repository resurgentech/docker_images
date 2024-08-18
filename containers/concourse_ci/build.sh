#!/bin/bash

# Find the directory of this script and change to it
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

function help() {
    echo "Usage: $0 [--generate|--push|--bao-up|--bao-down]"
    exit 1
}

function check_bao_envars() {
    if [ -z "$BAO_ADDR" ]; then
       echo "BAO_ADDR is not set. Please set it to the address of the BAO server."
        exit 1
    fi
    if [ -z "$BAO_SKIP_VERIFY" ]; then
        echo "BAO_SKIP_VERIFY is not set. Please set it to true or false."
        exit 1
    fi
}

# Defaults for 
DOCKER_ORG="resurgentech"
DOCKER_HOST="dockerhost.hulbert.local"
PORTAINER_USER_GROUP="dhcpcd:hulbert"
VOLUME_PATH="/var/lib/docker/volumes/concourse_ci_keys/_data"
BAO_ENGINE_PATH="infra"

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --generate|--push|--bao-read|--bao-write)
            if [[ -n "$COMMAND" ]]; then
                echo "Only one of --generate, --push, --bao-read, or --bao-write can be specified."
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
        --bao-engine-path)
            BAO_ENGINE_PATH="$2"
            shift 2
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
    ssh-keygen -t rsa -b 4096 -m PEM -f ./session_signing_key
    ssh-keygen -t rsa -b 4096 -m PEM -f ./tsa_host_key
    ssh-keygen -t rsa -b 4096 -m PEM -f ./worker_key
    cd ..
elif [ "$COMMAND" == "push" ]; then
    echo "Pushing keys..."
    ssh $DOCKER_HOST "mkdir -p /tmp/keys"
    scp keys/session_signing_key $DOCKER_HOST:/tmp/keys
    scp keys/tsa_host_key $DOCKER_HOST:/tmp/keys
    scp keys/worker_key.pub $DOCKER_HOST:/tmp/keys

    echo "#!/bin/bash" > ./keys/fixer.sh
    echo "cp /tmp/keys/session_signing_key $VOLUME_PATH/" >> ./keys/fixer.sh
    echo "cp /tmp/keys/tsa_host_key $VOLUME_PATH/" >> ./keys/fixer.sh
    echo "cp /tmp/keys/worker_key.pub $VOLUME_PATH/" >> ./keys/fixer.sh
    echo "rm -rf $VOLUME_PATH/fixer.sh" >> ./keys/fixer.sh
    echo "rm -rf /tmp/keys" >> ./keys/fixer.sh
    echo "cat $VOLUME_PATH/worker_key.pub >> $VOLUME_PATH/authorized_worker_keys" >> ./keys/fixer.sh
    echo "rm $VOLUME_PATH/worker_key.pub" >> ./keys/fixer.sh
    echo "chown -R $PORTAINER_USER_GROUP $VOLUME_PATH/session_signing_key" >> ./keys/fixer.sh
    echo "chown -R $PORTAINER_USER_GROUP $VOLUME_PATH/tsa_host_key" >> ./keys/fixer.sh
    echo "chown -R $PORTAINER_USER_GROUP $VOLUME_PATH/authorized_worker_keys" >> ./keys/fixer.sh
    scp keys/fixer.sh $DOCKER_HOST:/tmp/keys
    rm -rf ./keys/fixer.sh
    ssh $DOCKER_HOST "chmod +x /tmp/keys/fixer.sh"
    stty -echo
    ssh $DOCKER_HOST "sudo -S /tmp/keys/fixer.sh"
    stty echo
elif [ "$COMMAND" == "bao-write" ]; then
    echo "Writing keys to openbao"
    check_bao_envars
    K1="session_signing_key"
    V1=$(cat keys/$K1)
    K2="session_signing_key.pub"
    V2=$(cat keys/$K2)
    K3="tsa_host_key"
    V3=$(cat keys/$K3)
    K4="tsa_host_key.pub"
    V4=$(cat keys/$K4)
    K5="worker_key"
    V5=$(cat keys/$K5)
    K6="worker_key.pub"
    V6=$(cat keys/$K6)
    bao write $BAO_ENGINE_PATH/concourse_ci $K1="$V1" $K2="$V2" $K3="$V3" $K4="$V4" $K5="$V5" $K6="$V6"
elif [ "$COMMAND" == "bao-read" ]; then
    echo "Reading keys from openbao"
    check_bao_envars
    KEY_LIST="session_signing_key tsa_host_key worker_key"
    mkdir -p keys
    for key in $KEY_LIST; do
        bao read -field=$key $BAO_ENGINE_PATH/concourse_ci > keys/$key
        bao read -field=$key.pub $BAO_ENGINE_PATH/concourse_ci > keys/$key.pub
    done
else
    help
fi