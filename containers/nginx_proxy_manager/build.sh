#!/bin/bash

# Find the directory of this script and change to it
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

function help() {
    echo "Usage: $0 [--generate]"
    exit 1
}

# Defaults for 
OURDOMAIN="hulbert.local"

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --generate)
            if [[ -n "$COMMAND" ]]; then
                echo "Only one of --generate."
                echo ""
                help
            fi
            COMMAND="${1#--}"
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
    openssl req -x509 -newkey rsa:4096 -keyout cert.key -out cert.crt -days 3650 -nodes -subj "/CN=$OURDOMAIN"
    openssl req -x509 -newkey rsa:4096 -keyout intermediate.key -out intermediate.crt -days 3650 -nodes -subj "/CN=Intermediate CA"
    cat cert.crt intermediate.crt > fullchain.crt
    cd ..
else
    help
fi