#!/bin/bash

check_vars() {
    # Check mandatory parameters
    for var in OPENSIPS_DOMAIN DUCKDNS_TOKEN LETSENCYPT_EMAIL; do
        if [ -z "${!var}" ]; then
            echo "$var is not set"
            exit 1;
        fi
    done
}

check_and_set_default() {
    local var_name=$1
    local default_value=$2
    
    if [ -z "${!var_name}" ]; then
        eval "$var_name=$default_value"
        echo "$var_name is not set. Setting to default: ${!var_name}"
    else
        echo "$var_name is set to ${!var_name}"
    fi
}
# Check DNS Name
check_dns(){
    if [[ $OPENSIPS_DOMAIN =~ ^(([a-zA-Z]|\d|[a-zA-Z\d][a-zA-Z\d-]*[a-zA-Z\d])\.)*([A-Za-z]|\d|[A-Za-z\d][A-Za-z\d-]*[A-Za-z\d])$ ]]; then
        echo "${OPENSIPS_DOMAIN} is a valid DNS name"
    else
        echo "${OPENSIPS_DOMAIN} is not a valid DNS name"
        exit;
    fi
}
check_ip_address() {
    ATTEMPTS=10
    ACTUAL_IP=""
    while [ $ATTEMPTS -gt 0 ]; do
        ACTUAL_IP=$(dig +short ${OPENSIPS_DOMAIN})
        if [[ $ACTUAL_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Public IP Address seems to be ${ACTUAL_IP}"
            break
        else
            echo "Cannot retrieve IP Public IP Address. Retrying..."
            ((ATTEMPTS--))
            sleep 1  # Optional: add a short delay between attempts
        fi
    done
    # Check if ACTUAL_IP is set
    if [ -z "$ACTUAL_IP" ]; then
        echo "Failed to retrieve IP after ${ATTEMPTS} attempts."
        exit;
    fi
}
create_config(){
    
cat <<EOF > /etc/opensips/config/env.m4
divert(-1)
define(\`OPENSIPS_IP', \`$ACTUAL_IP')
define(\`OPENSIPS_DOMAIN', \`$OPENSIPS_DOMAIN')
define(\`RTP_PORT_MIN', \`$RTP_PORT_MIN')
define(\`RTP_PORT_MAX', \`$RTP_PORT_MAX')
divert(0)dnl

EOF

m4 /etc/opensips/config/env.m4 /etc/opensips/config/opensips.cfg.m4 > /etc/opensips/config/opensips.cfg

}

check_and_create_certs() {
    CERT_DIR="/etc/letsencrypt/live/$OPENSIPS_DOMAIN"
    if [ -d "$CERT_DIR" ]; then
        echo "Certs are already configured, skipping creation."
    else
        certbot certonly --manual --preferred-challenges=dns --email $LETSENCYPT_EMAIL --non-interactive --agree-tos --manual-auth-hook "/usr/local/duckdns.sh" -d $OPENSIPS_DOMAIN
        if [ $? -eq 0 ]; then
            echo "Certbot success"
        else
            echo "Certbot failed"
            cat /var/log/letsencrypt/letsencrypt.log
            exit 1;
        fi
        # Assume that db has not been created either
    fi
}
start_rtpproxy() {
    rtpproxy_debug -F -l 127.0.0.1 -s udp:127.0.0.1:7722 -A ${ACTUAL_IP} -m ${RTP_PORT_MIN} -M ${RTP_PORT_MAX} -d DBUG:LOG_LOCAL0
    sleep 10 # Ensure it starts up
}
start_opensips() {
    /usr/sbin/opensips -f /etc/opensips/config/opensips.cfg -m 512 -M 64
}
startup_complete() {
    tail -f /dev/null
}
check_vars
check_dns
check_ip_address
check_and_create_certs
check_and_set_default RTP_PORT_MIN 10000
check_and_set_default RTP_PORT_MAX 10255
start_rtpproxy
create_config
start_opensips
startup_complete

