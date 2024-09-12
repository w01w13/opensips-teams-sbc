FROM debian:bookworm
LABEL maintainer="w01w13 <w01w13@gmail.com>"

USER root

# Set Environment Variables
ENV DEBIAN_FRONTEND noninteractive

ARG OPENSIPS_VERSION=3.4
ARG OPENSIPS_VERSION_MINOR
ARG OPENSIPS_VERSION_REVISION=1
ARG OPENSIPS_BUILD=releases

#install basic components
RUN apt-get -y update -qq && apt-get -y install gnupg2 dnsutils ca-certificates certbot m4 curl git gcc build-essential libsqlite3-dev 

#add keyserver, repository
RUN apt-key adv --fetch-keys https://apt.opensips.org/pubkey.gpg
RUN echo "deb https://apt.opensips.org bookworm ${OPENSIPS_VERSION}-${OPENSIPS_BUILD}" >/etc/apt/sources.list.d/opensips.list

RUN apt-get -y update -qq && \
    apt-get -y install \
        opensips${OPENSIPS_VERSION_MINOR:+=$OPENSIPS_VERSION.$OPENSIPS_VERSION_MINOR-$OPENSIPS_VERSION_REVISION}

ARG OPENSIPS_CLI=false
RUN if [ ${OPENSIPS_CLI} = true ]; then \
    echo "deb https://apt.opensips.org bookworm cli-nightly" >/etc/apt/sources.list.d/opensips-cli.list \
    && apt-get -y update -qq && apt-get -y install opensips-cli \
    ;fi

ARG OPENSIPS_EXTRA_MODULES
RUN if [ -n "${OPENSIPS_EXTRA_MODULES}" ]; then \
    apt-get -y install ${OPENSIPS_EXTRA_MODULES} \
    ;fi

RUN rm -rf /var/lib/apt/lists/*

COPY usr/local/duckdns.sh /usr/local/duckdns.sh
COPY usr/local/entrypoint.sh /usr/local/entrypoint.sh

RUN chmod +x /usr/local/duckdns.sh
RUN chmod +x /usr/local/entrypoint.sh

COPY etc/opensips-cli.cfg /etc/opensips-cli.cfg
COPY etc/opensips/config/opensips.cfg.m4 /etc/opensips/config/opensips.cfg.m4


# Install rtp-proxy
RUN cd /tmp
RUN git clone -b master https://github.com/sippy/rtpproxy.git
RUN git -C rtpproxy submodule update --init --recursive
RUN cd rtpproxy && ./configure && make -j4 && make install
RUN apt-get remove -y git gcc build-essential && apt-get autoremove -y
# Start the system
ENTRYPOINT ["/usr/local/entrypoint.sh"]
