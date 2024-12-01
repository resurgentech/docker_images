# Concourse CI container

# Self signed certificates / keys
OpenBao in production needs certificates.  These are the instructions for generating a set of self signed certificates.

This will generate a set of self signed certificates with our info
```./build.sh --generate```

# Docker Compose
I'm using portainer to manage some docker containers.  You can use the `docker-compose.yml` file to create a custom template in Portainer, then use the template to create a new container managed by Portainer.  But it will not run without adding some files into the volumes. The Portainer push section is a hack for making that happen.

# Portainer push
This will push the required files into the Portainer volumes so the container will run.
```./build.sh --push```

# Bao secrets
Because we're gonna want some of the secrets later we're gonna want to save them into openbao.

To save them into openbao we're gonna need to run the following:
```./build.sh --bao-write```

And to retreive them:
```./build.sh --bao-read```

# Bao configuration

Following this guide:
https://concourse-ci.org/vault-credential-manager.html#configuring-the-secrets-engine

- create a secrets engine at /concourse
- create RO policy for this engine
- create a token for this policy
- add "CONCOURSE_VAULT_CLIENT_TOKEN" to the Concourse Portainer stack named using the Editor under Environment Variable not the main text editor window

