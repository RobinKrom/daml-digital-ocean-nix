Deploy your DAML projects in the cloud
======================================

This repository helps you deploy a React/DAML/Auth0 project on a Digital Ocean droplet. The
deployment consists of a DAML sandbox backed by a PostgreSQL database, a DAML JSON API service and a
nginx webserver. All authentication is done via auth0.com.

Check out https://github.com/RobinKrom/dbay.git for an example React/DAML application.

Check out https://www.projectdabl.com for a managed DAML deployment offering.

Prerequisites
-------------

- A https://auth0.com acccount
- A https://www.digitalocean.com account with a little bit of funding

Configure Authentication by Auth0
---------------------------------

I assume that all authentication for your project is handled by auth0.com. In auth0.com you will
need to create one single page application and one machine to machine authorization for this
application (by creating an API). The machine-to-machine authorization is needed to authorize the
DAML JSON API service to the sandbox.

Create your DAML droplet
------------------------

Get the Nix package manager:

``` bash
curl https://nixos.org/nix/install | sh
```

Then, install `nixops` and optionally `curl` and `jq` if you don't already have it on your system:

``` bash
nix-channel --update
nix-env -i nixops #curl jq
```

Generate a Digital Ocean personal access token (https://cloud.digitalocean.com/account/api) and
export it:

``` bash
export DIGITAL_OCEAN_AUTH_TOKEN=<your-token>
```

Clone this repo and edit the file `project-config.nix` to specify the auth0 m2m
client-id/client-secret and a few other configuration options like your DAML ledger identity. Then
fire up your droplet:

```
git clone ssh://git@github.com/RobinKrom/daml-digital-ocean-nix.git
vim project-config.nix
cd daml-digital-ocean-nix.git
nixops create -d sandbox daml-sandbox-postgres.nix
nixops deploy -d sandbox
```

Go grab a :coffee: ...

Wait 5 minutes till the machine has spun up, then proceed to deploy your UI/DAML build artefacts as
described in the next section.

Deploy your DAML project
------------------------

First, make sure that the callback urls of you auth0 application point to the IP address of your
newly created droplet.

Change to your DAML project directory and run

```
daml build
```

Change to the front end directory and run

```
yarn build
```

Get your m2m access token from auth0:

```
echo -n 'Bearer ' > m2m.token
curl --request POST --url 'https://dev-8xkawbyi.auth0.com/oauth/token' --header 'content-type: application/json' --data '{"client_id":"<your m2m client id>", "client_secret":"<your m2m client secret>", "audience":"localhost/sandbox", "grant_type":"client_credentials"}' | jq -r .access_token >> m2m.token
```

Deploy your DAML artefact on your droplet with

```
nixops ssh machine -L 6865:localhost:6865
daml ledger upload-dar --access-token-file=m2m.token .daml/dist/<your-project>.dar 
```

Deploy your front end artefact on your droplet with

```
nixops scp machine build/ --to /var/www/<your ledger id>/
```

Congratulations! Your DAML project is live!

References
----------

- https://www.daml.com
- https://github.com/digital-asset/create-daml-app
- https://nixos.org/nixops/manual

License
-------

**MIT**
