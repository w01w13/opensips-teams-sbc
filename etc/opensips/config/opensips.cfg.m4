#
# simple quick-start config script including nathelper support

# This default script includes nathelper support. To make it work
# you will also have to install Maxim's RTP proxy. The proxy is enforced
# if one of the parties is behind a NAT.
#
# If you have an endpoing in the public internet which is known to
# support symmetric RTP (Cisco PSTN gateway or voicemail, for example),
# then you don't have to force RTP proxy. If you don't want to enforce
# RTP proxy for some destinations than simply use t_relay() instead of
# route(1)
#
# Sections marked with !! Nathelper contain modifications for nathelper
#
# NOTE !! This config is EXPERIMENTAL !
#
# ----------- global configuration parameters ------------------------

log_level=3      # logging level (cmd line: -dddddddddd)
stderror_enabled=no
syslog_enabled=yes
debug_mode=OPENSIPS_DEBUG
advertised_address="OPENSIPS_DOMAIN"
log_level=3
xlog_level=3
stderror_enabled=yes
syslog_enabled=yes
syslog_facility=LOG_LOCAL0
check_via=yes	# (cmd. line: -v)
dns=yes           # (cmd. line: -r)
rev_dns=yes      # (cmd. line: -R)
udp_workers=4

socket= tls:PRIVATE_IP:5061
socket= udp:PRIVATE_IP:5060

# ------------------ module loading ----------------------------------

#set module path
mpath="/usr/lib/x86_64-linux-gnu/opensips/modules/"

loadmodule "sl.so"
loadmodule "tm.so"
loadmodule "signaling.so"
loadmodule "rr.so"
loadmodule "maxfwd.so"
loadmodule "usrloc.so"
loadmodule "registrar.so"
loadmodule "textops.so"
loadmodule "sipmsgops.so"
loadmodule "mi_fifo.so"
loadmodule "options.so"
loadmodule "auth_db.so"
loadmodule "auth.so"
### registrar
modparam("registrar", "max_contacts", 1)
#### SQLite 
loadmodule "db_sqlite.so"
###RTPProxy
loadmodule "rtpproxy.so"
modparam("rtpproxy", "rtpproxy_sock", "udp:PRIVATE_IP:7722")
modparam("rtpproxy", "generated_sdp_port_min", RTP_PORT_MIN)
modparam("rtpproxy", "generated_sdp_port_max", RTP_PORT_MAX)
modparam("rtpproxy", "generated_sdp_media_ip", "OPENSIPS_IP")

## TLS
loadmodule "tls_wolfssl.so"
loadmodule "tls_mgm.so"
modparam("tls_mgm", "db_url", "sqlite:///db_data/opensips")

loadmodule "proto_tls.so"
modparam("tls_mgm", "client_domain", "dom0")
modparam("tls_mgm","verify_cert", "[dom0]1")
modparam("tls_mgm","require_cert", "[dom0]1")
modparam("tls_mgm","tls_method", "[dom0]TLSv1_2")
modparam("tls_mgm","ca_dir", "[dom0]/etc/ssl/certs") 
modparam("tls_mgm","certificate", "[dom0]/etc/letsencrypt/live/OPENSIPS_DOMAIN/fullchain.pem") 
modparam("tls_mgm","private_key", "[dom0]/etc/letsencrypt/live/OPENSIPS_DOMAIN/privkey.pem") 
modparam("tls_mgm", "server_domain", "dom1")
modparam("tls_mgm","verify_cert", "[dom1]0")
modparam("tls_mgm","require_cert", "[dom1]0")
modparam("tls_mgm","ca_dir", "[dom1]/etc/ssl/certs") 
modparam("tls_mgm","certificate", "[dom1]/etc/letsencrypt/live/OPENSIPS_DOMAIN/fullchain.pem") 
modparam("tls_mgm","private_key", "[dom1]/etc/letsencrypt/live/OPENSIPS_DOMAIN/privkey.pem") 

## TLS timeouts
modparam("proto_tls", "tls_handshake_timeout", 300)
modparam("proto_tls", "tls_max_msg_chunks", 8)
#### Dynamic Routing
loadmodule "drouting.so"
modparam("drouting", "db_url", "sqlite:///db_data/opensips")
modparam("usrloc", "db_url", "sqlite:///db_data/opensips")
modparam("auth_db", "db_url", "sqlite:///db_data/opensips")

# !! Nathelper
loadmodule "nathelper.so"

loadmodule "proto_udp.so"

# ----------------- setting module-specific parameters ---------------

# -- mi_fifo params --
modparam("mi_fifo", "fifo_name", "/tmp/opensips_fifo")

# -- usrloc params --
modparam("usrloc", "working_mode_preset", "single-instance-no-db")
# Uncomment this if you want to use SQL database 
# for persistent storage and comment the previous line
#modparam("usrloc", "working_mode_preset", "single-instance-sql-write-back")

# -- auth params --
modparam("auth_db", "calculate_ha1", 1)
modparam("auth_db", "password_column", "password")
modparam("auth_db", "user_column", "username")
modparam("auth_db", "domain_column", "domain")


# !! Nathelper
modparam("usrloc","nat_bflag", "NAT")
modparam("nathelper","sipping_bflag", "SIP_PING")
modparam("nathelper","natping_interval",60)
modparam("nathelper", "ping_threshold", 10)
modparam("nathelper","natping_tcp",1)
modparam("nathelper", "remove_on_timeout_bflag", "SIPPING_RTO")
modparam("nathelper","ping_nated_only",1)
modparam("nathelper","sipping_method","OPTIONS")
modparam("nathelper","sipping_from","sip:pinger@OPENSIPS_DOMAIN")
modparam("nathelper", "received_avp", "$avp(received)")
### Nattraversal
loadmodule "nat_traversal.so"
modparam("nat_traversal", "keepalive_interval", 30)
modparam("nat_traversal", "keepalive_method", "OPTIONS")
modparam("nat_traversal", "keepalive_from", "sip:keepalive@OPENSIPS_DOMAIN")

# -------------------------  request routing logic -------------------

# main routing logic

route{
	xlog("L_INFO", "SIP In: $mb\n");

	$var(src) = "pstnhub.microsoft.com";
	if (($(fu{s.index, $var(src)}) == NULL) && is_method("REGISTER")) {
		if (!www_authorize("OPENSIPS_DOMAIN","subscriber")){
			www_challenge("OPENSIPS_DOMAIN", "auth");
			exit;
		}

		if (!consume_credentials()){
			exit;
		}
	}

	if (is_method("OPTIONS")) {
		xlog("L_INFO", "[MS TEAMS] OPTIONS In\n");
		options_reply();
		exit;
	} else {
		xlog("L_INFO", "OPTIONS In $ru\n");
	}

	# initial sanity checks -- messages with
	# max_forwards==0, or excessively long requests
	if (!mf_process_maxfwd_header(10)) {
		send_reply(483,"Too Many Hops");
		exit;
	}

	# !! Nathelper
	# Special handling for NATed clients; first, NAT test is
	# executed: it looks for via!=received and RFC1918 addresses
	# in Contact (may fail if line-folding is used); also,
	# the received test should, if completed, should check all
	# vias for rpesence of received
	if (nat_uac_test("diff-ip-src-via,private-contact")) {
		# Allow RR-ed requests, as these may indicate that
		# a NAT-enabled proxy takes care of it; unless it is
		# a REGISTER

		if (is_method("REGISTER") || !is_present_hf("Record-Route")) {
			xlog("Someone trying to register from private IP, rewriting\n");
			# This will work only for user agents that support symmetric
			# communication. We tested quite many of them and majority is
			# smart enough to be symmetric. In some phones it takes a 
			# configuration option. With Cisco 7960, it is called 
			# NAT_Enable=Yes, with kphone it is called "symmetric media" and 
			# "symmetric signalling".

			# Rewrite contact with source IP of signalling

			fix_nated_contact();
			if ( is_method("INVITE") ) {
				fix_nated_sdp("add-dir-active"); # Add direction=active to SDP
			};
			force_rport(); # Add rport parameter to topmost Via
			setbflag("NAT");    # Mark as NATed

			# if you want sip nat pinging
			setbflag("SIP_PING");
		};
	};

	# subsequent messages withing a dialog should take the
	# path determined by record-routing
	if (loose_route()) {
		# mark routing logic in request
		append_hf("P-hint: rr-enforced\r\n"); 
		route(1);
		exit;
	};

	# we record-route all messages -- to make sure that
	# subsequent messages will go through our proxy; that's
	# particularly good if upstream and downstream entities
	# use different transport protocol
	if (!is_method("REGISTER"))
		record_route();

	if (!is_myself("$rd")) {
		# mark routing logic in request
		append_hf("P-hint: outbound\r\n"); 
		route(1);
		exit;
	};

	# if the request is for other domain use UsrLoc
	# (in case, it does not work, use the following command
	# with proper names and addresses in it)
	if (is_myself("$rd")) {

		if (is_method("REGISTER")) {

			# Uncomment this if you want to use digest authentication
			#if (!www_authorize("siphub.org", "subscriber")) {
			#	www_challenge("siphub.org", "0");
			#	return;
			#};
			fix_nated_register();
			save("location", "force-registration");
			exit;
		};

		lookup("aliases");
		if (!is_myself("$rd")) {
			append_hf("P-hint: outbound alias\r\n"); 
			route(1);
			exit;
		};

		# native SIP destinations are handled using our USRLOC DB
		if (!lookup("location")) {
			send_reply(404, "Not Found");
			exit;
		};
	};
	append_hf("P-hint: usrloc applied\r\n"); 
	route(1);
}

route[1] 
{
	# !! Nathelper
	if ($ru=~"[@:](192\.168\.|10\.|172\.\.)"
	&& !is_present_hf("Route")) {
		send_reply(479, "We don't forward to private IP addresses");
		exit;
	};

	# if client or server know to be behind a NAT, enable relay
	if (isbflagset("NAT")) {
		rtpproxy_offer("cor", "OPENSIPS_IP");
	};

	# NAT processing of replies; apply to all transactions (for example,
	# re-INVITEs from public to private UA are hard to identify as
	# NATed at the moment of request processing); look at replies
	t_on_reply("reply_handler");

	# send it out now; use stateful forwarding as it works reliably
	# even for UDP2TCP
	if (!t_relay()) {
		sl_reply_error();
	};
}

# !! Nathelper
onreply_route[reply_handler] {
	# NATed transaction ?
	if (isbflagset("NAT") && $rs =~ "(183)|2[0-9][0-9]") {
		fix_nated_contact();
		rtpproxy_answer("cor", "OPENSIPS_IP");
	# otherwise, is it a transaction behind a NAT and we did not
	# know at time of request processing ? (RFC1918 contacts)
	} else if (nat_uac_test("private-contact")) {
		fix_nated_contact();
	};
}

local_route {
	$var(src) = "pstnhub.microsoft.com";
	if (is_method("OPTIONS") && ($(ru{s.index, $var(src)}) != NULL)) {
		$var(contact) = "sip:OPENSIPS_DOMAIN:5061";
		append_hf("Contact: <$var(contact);transport=tls>\r\n");
		xlog("L_INFO", "OPTIONS From: $var(src)\r\n");
	} else {
		xlog("L_INFO", "OPTIONS From: $ru\n");
	}
}
