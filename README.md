# openSIPS as Teams Compatible Session Border Controller

A docker image to create Teams (or Azure Communication Service with [Direct Routing](https://learn.microsoft.com/en-us/azure/communication-services/concepts/telephony/direct-routing-provisioning)) compatible Session Border Gateway for testing purposes. Configuration is based on [OpenSIPS as MS Teams SBC](https://blog.opensips.org/2019/09/16/opensips-as-ms-teams-sbc/) blog post and the docker image is forked from [OpenSIPS Docker Image](https://github.com/OpenSIPS/docker-opensips), updated to debian/bookworm instead of debian/bullseye

**NOTE**: This repo is work in progress, and only meant for prototyping and playing around. At the moment the signalling works properly but RTP still has some issues if clients are behind NAT's

**NOTE** container does not handle renewal of Let's Encrypt certificates at the moment, so if planning to run for longer periods make necessary adjustments. 

## Folder structure

The folder structure of the project: 

```
├── db_data
│   └── opensips
├── docker-compose.yaml
├── Dockerfile
├── etc
│   ├── letsencrypt
│   ├── opensips
│   │   └── config
│   │       └── opensips.cfg.m4
│   └── opensips-cli.cfg
├── Makefile
├── README.md
└── usr
    └── local
        ├── duckdns.sh
        └── entrypoint.sh
```

Some explanation of the files and folders:
- [db_data/opensips ](db_data/opensips) 
    - SQLite database created with opensips-cli -x database create and dr_gateways prepopulated with SBC_WAN tls:0.0.0.0:5061 
- [docker-compose.yaml](docker-compose.yaml) 
    - Tries to read configuration variables from environment variables, so use .env or other ways to get them in
- [Dockerfile](Dockerfile) 
    - Creates a Docker Image with openSIPS 3.4 and rtpprozy with required modules configured in [opensips.cfg.m4](etc/opensips/config/opensips.cfg.m4) and installs necessary tools to compile rtpproxy and compiles it. takes little time to compile. 
- [etc/letsencrypt](etc/letsencrypt) 
    - Mounted to /etc/letencrypt and stores the private keys , certs etc config for lets encrypt. Make sure you dont remove the .gitignore which makes sure you dont push your private key to github.
- [etc/opensips/config/opensips.cfg.m4](etc/opensips/config/opensips.cfg.m4)
    - The template used by entrypoint and m4 to create etc/opensips/config/opensips.cfg during boot. Using template as we need to automatically populate DNS domain, public IP etc into cfg file during boot 
- [etc/opensips-cli.cfg](etc/opensips-cli.cfg)
    - The opensips-cli configuration file, needed for executing opensips-cli commands within container.
- [Makefile](Makefile)
    - Used to build the container.
- [README.md](README.md)
    - This file.
- [usr/local/entrypoint.sh](usr/local/entrypoint.sh) 
    - The entrypoint.sh boots up the container and checks that configuration is setup, fetches the public IP and starts rtpproxy and opensips with necessary variables.
- [usr/local/duckdns.sh](usr/local/duckdns.sh) 
    - The hook for certbot when certs are created and stored to etc/letsencrypt folder.


## Pre-requisites

Before starting, two things are needed:
- Email address for Let's Encrypt
- [Duck DNS](https://www.duckdns.org/) account

## Parameters

The docker compose expects to get some mandatory and optional parameters via environment variables. Depending on your setup there are various ways to set them up, here's an example using a .env file (included in .gitignore also to prevent accidental push of secrets to github).

Create .env file

```
touch .env
```
Edit the file
```
nano touch .env
```
and add following mandatory parameters:
```
OPENSIPS_DOMAIN=<your Duck DNS domain>
DUCKDNS_TOKEN=<your Duck DNS token>
LETSENCYPT_EMAIL=<Email address, used by certbot for registration>
```

You can also set following optional parameters for RTP traffic: 
```
RTP_PORT_MIN=<minimum port range for RTP traffic>
RTP_PORT_MAX=<maximum port range for RTP traffic>
```
**NOTE** If you edit these, also edit the [docker-compose.yaml](docker-compose.yaml) to expose the ports as well

## Build docker file

Builds the docker file, and installs necessary opensips modules needed by the configuration file included [opensips.cfg.m4](etc/opensips/config/opensips.cfg.m4)

```
make
```

## Add user

The configuration assumes authentication is on for other clients than ones registering from *.pstnhub.microsoft.com. To create user for your VOIP clients ppen SQLite database connection and execute SQL to create a user

```
$ sqlite3 db_data/opensips
sqlite> insert into subscriber(username, domain, password, rpid) VALUES ('+358401231234','example.duckdns.org', 'ChangeMe!', '+358401231234@example.duckdns.org');
sqlite> .quit
$
```

**NOTE**: Currently using plaintext passwords, most likely will start to use ha1 at some stage

## Start container

To start the container locally simply run docker compose.

```
docker compose up -d
```