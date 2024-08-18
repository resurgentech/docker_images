#!/bin/bash

# Find the directory this script lives in and cd to it
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$script_dir"


# Use ./keys.sh --generate to generate keys for the Concourse CI web and worker nodes.
# Use ./keys.sh --push to push the keys to the Concourse CI web.

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --generate)
            GENERATE=true
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -n "$GENERATE" ]]; then
    echo "Generating keys..."
    mkdir -p ./keys
    cd ./keys
    ssh-keygen -t rsa -b 4096 -m PEM -f ./session_signing_key
    ssh-keygen -t rsa -b 4096 -m PEM -f ./tsa_host_key
    ssh-keygen -t rsa -b 4096 -m PEM -f ./worker_key
    cd ..
elif [[ -n "$PUSH" ]]; then
    echo "Pushing keys..."
    ssh dockerhost.hulbert.local "mkdir -p /tmp/keys"
    scp keys/session_signing_key dockerhost.hulbert.local:/tmp/keys
    scp keys/tsa_host_key dockerhost.hulbert.local:/tmp/keys
    scp keys/worker_key.pub dockerhost.hulbert.local:/tmp/keys

    echo "#!/bin/bash" > ./keys/fixer.sh
    echo "cp /tmp/keys/* /var/lib/docker/volumes/concourse_ci_keys/_data/" >> ./keys/fixer.sh
    echo "rm -rf /var/lib/docker/volumes/concourse_ci_keys/_data/fixer.sh" >> ./keys/fixer.sh
    echo "rm -rf /tmp/keys" >> ./keys/fixer.sh
    echo "cat /var/lib/docker/volumes/concourse_ci_keys/_data/worker_key.pub >> /var/lib/docker/volumes/concourse_ci_keys/_data/authorized_worker_keys" >> ./keys/fixer.sh
    echo "rm /var/lib/docker/volumes/concourse_ci_keys/_data/worker_key.pub" >> ./keys/fixer.sh
    echo "chown -R dhcpcd:hulbert /var/lib/docker/volumes/concourse_ci_keys/_data/session_signing_key" >> ./keys/fixer.sh
    echo "chown -R dhcpcd:hulbert /var/lib/docker/volumes/concourse_ci_keys/_data/tsa_host_key" >> ./keys/fixer.sh
    echo "chown -R dhcpcd:hulbert /var/lib/docker/volumes/concourse_ci_keys/_data/authorized_worker_keys" >> ./keys/fixer.sh
    scp keys/fixer.sh dockerhost.hulbert.local:/tmp/keys
    rm -rf ./keys/fixer.sh
    ssh dockerhost.hulbert.local "chmod +x /tmp/keys/fixer.sh"
    stty -echo
    ssh dockerhost.hulbert.local "sudo -S /tmp/keys/fixer.sh"
    stty echo
else
    echo "Usage: $0 [--generate|--push]"
    exit 1
fi

