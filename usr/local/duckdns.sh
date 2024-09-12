#!/bin/bash
curl -s "https://www.duckdns.org/update?domains=${OPENSIPS_DOMAIN}&token=${DUCKDNS_TOKEN}&txt=${CERTBOT_VALIDATION}&verbose=true" && sleep 45
