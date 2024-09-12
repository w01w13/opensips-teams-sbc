NAME ?= opensips
OPENSIPS_VERSION ?= 3.4
OPENSIPS_VERSION_MINOR ?=
OPENSIPS_VERSION_REVISION ?=
OPENSIPS_BUILD ?= releases
OPENSIPS_DOCKER_TAG ?= latest
OPENSIPS_CLI ?= true
OPENSIPS_EXTRA_MODULES ?= "opensips-auth-modules opensips-tls-module opensips-tlsmgm-module opensips-tls-wolfssl-module opensips-sqlite-module"
DOCKER_ARGS ?=

all: build start

.PHONY: build start
build:
	docker build \
		--no-cache \
		--build-arg=OPENSIPS_BUILD=$(OPENSIPS_BUILD) \
		--build-arg=OPENSIPS_VERSION=$(OPENSIPS_VERSION) \
		--build-arg=OPENSIPS_VERSION_MINOR=$(OPENSIPS_VERSION_MINOR) \
		--build-arg=OPENSIPS_VERSION_REVISION=$(OPENSIPS_VERSION_REVISION) \
		--build-arg=OPENSIPS_CLI=${OPENSIPS_CLI} \
		--build-arg=OPENSIPS_EXTRA_MODULES=$(OPENSIPS_EXTRA_MODULES) \
		$(DOCKER_ARGS) \
		--tag="w01w13/opensips:$(OPENSIPS_DOCKER_TAG)" \
		.