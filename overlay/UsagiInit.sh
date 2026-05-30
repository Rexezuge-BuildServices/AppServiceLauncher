#!/UsagiInit

# ChordDHT (guarded)
if [ -n "$NODE_URI" ] && [ -n "$TRACKER_URL" ] && \
   [ -n "$CHORD_AUTH_NODE_CERT" ] && [ -n "$CHORD_AUTH_NODE_PRIVATE_KEY" ]; then
    node_certificate_file=$(mktemp)
    echo "$CHORD_AUTH_NODE_CERT" > "$node_certificate_file"
    node_private_key_file=$(mktemp)
    echo "$CHORD_AUTH_NODE_PRIVATE_KEY" > "$node_private_key_file"
    IFS='' read -r ca_public_key_base64 < /.AppServiceLauncher/ChordDHT/CERTIFICATE_AUTHORITY_PUBLIC_KEY.b64
    /.AppServiceLauncher/ChordDHT/ChordDHT-Node \
        -uri "$NODE_URI" \
        -tracker-url "$TRACKER_URL" \
        -listen :58443 \
        -tls-cert /.AppServiceLauncher/etc/ssl/selfsigned/server.crt \
        -tls-key  /.AppServiceLauncher/etc/ssl/selfsigned/server.key \
        -log-level error \
        -auth.enabled \
        -auth.ca-public-key-base64 "$ca_public_key_base64" \
        -auth.crl-file /.AppServiceLauncher/ChordDHT/CERTIFICATE_REVOCATION_LIST.json \
        -auth.node-certificate-file "$node_certificate_file" \
        -auth.node-private-key-file "$node_private_key_file" &
else
    echo "AppServiceLauncher: skipping ChordDHT (NODE_URI, TRACKER_URL, CHORD_AUTH_NODE_CERT, CHORD_AUTH_NODE_PRIVATE_KEY must all be set)" >&2
fi

# cloudflared (guarded)
if [ -n "$CLOUDFLARE_TOKEN" ]; then
    /.AppServiceLauncher/usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TOKEN" > /dev/null 2>&1 &
else
    echo "AppServiceLauncher: skipping cloudflared (CLOUDFLARE_TOKEN not set)" >&2
fi

# nginx (guarded)
mkdir -p /tmp/nginx/logs
/.AppServiceLauncher/usr/sbin/nginx \
    -p /tmp/nginx \
    -c /.AppServiceLauncher/etc/nginx/nginx.conf \
    -g "daemon off;" > /dev/null 2>&1 &

# Original application — exec replaces sh (not guarded, not restarted)
if [ $# -gt 0 ]; then
    if [ -n "$APP_USER" ]; then
        exec /.AppServiceLauncher/su-exec "$APP_USER" "$@"
    else
        exec "$@"
    fi
fi
