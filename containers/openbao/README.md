# Openbao container

# Docker image for openbao
Couldn't find a decent container for a simple single host with the ui build in.

Our Dockerfile.openbao is largely adapted from the openbao github repo

## First, set up the downloads/ dir:

### downloads/bao
We need a hand built bao binary from the openbao github repo.

### downloads/release.docker/docker-entrypoint.sh
This is copied from the openbao github repo.

### downloads/config.hcl
This config file is an opinionated config file.  Coordinated to the included docker-compose.yml and Portainer push scripting.

## Second, build the container:
You can just use the build script:
```./build.sh --build```

## Optionally, push
If you want to push the container to the docker hub, go for it.

# Self signed certificates / keys
OpenBao in production needs certificates.  These are the instructions for generating a set of self signed certificates.

This will generate a set of self signed certificates with our info
```./build.sh --generate```

If you want to set your own info, you can do so with the following:
```./build.sh --generate --manual-openssl-subj```

# Docker Compose
I'm using portainer to manage some docker containers.  You can use the `docker-compose.yml` file to create a custom template in Portainer, then use the template to create a new container managed by Portainer.  But it will not run without adding some files into the volumes. The Portainer push section is a hack for making that happen.

# Portainer push
This will push the required files into the Portainer volumes so the container will run.
```./build.sh --push```

# Setup
The following are notes for how to set up openbao for basic home lab use.

Using the web ui you will have an intro asking for number of shares and the threshold.  HYou can just do 1 share and 1 threshold.  Look it up  if you want to know what that means.

Next you will get an opportunity to download the initial root token and the initial shamir unsealing key. You'll need to download these and save them somewhere safe.

I like to enable userpass authentication and create a user at this point.  Then I add a Group, add an entity (our user) to the group.

Next you will want to create a new secrets engine.  cubbyhole is only per user, doesn't share among users.  kv seems to be the best general purpose secrets engine.  Not KV v2 doesn't work with the easy cli tools so I use KV v1.  You assign the new engine a path.

Now you need to set up a policy that includes the new secret engine such as the following:
```
path "secrets-engine-path/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```
Then you add that policy to the group you created and added the user to.

# Using the bao client

You can use the cli arguments to set this but it's easier to set the environment variables.
The skip verify is to avoid the ssl cert verification, which is needed for self signed certs.
```
export BAO_ADDR="https://openbao.hulbert.local"
export BAO_SKIP_VERIFY=true
```