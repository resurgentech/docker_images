# Nginx Proxy Manager

I found this to be a very simple way to manage a reverse proxy.  I'm using it to make my docker services look like they are their own servers.

You can use the `docker-compose.yml` file to create a custom template in Portainer, then use the template to create a new container managed by Portainer.

I included a tool to enable self signed certificates.
```./build.sh --generate```

These can be used in the nginx proxy manager UI to create a custom certificate provider in the SSL Certificates tab.  This enables you to use the self signed certificates to do ssl on the reverse proxy.

This is pretty easy, the UI is pretty self explanatory.  Just remember you have to add an alias in the router.
