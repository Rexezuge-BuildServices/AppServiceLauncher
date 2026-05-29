#!/UsagiInit

# ChordDHT (guarded)
if [ -n "$NODE_URI" ] && [ -n "$TRACKER_URL" ] && [ -n "$CA_PUBLIC_KEY_BASE64" ] && \
   [ -n "$CHORD_AUTH_NODE_CERT" ] && [ -n "$CHORD_AUTH_NODE_PRIVATE_KEY" ]; then
    node_certificate_file=$(mktemp)
    echo "$CHORD_AUTH_NODE_CERT" > "$node_certificate_file"
    node_private_key_file=$(mktemp)
    echo "$CHORD_AUTH_NODE_PRIVATE_KEY" > "$node_private_key_file"
    /.AppServiceLauncher/ChordDHT-Node \
        -uri "$NODE_URI" \
        -tracker-url "$TRACKER_URL" \
        -listen :8443 \
        -tls-cert /.AppServiceLauncher/etc/ssl/selfsigned/server.crt \
        -tls-key  /.AppServiceLauncher/etc/ssl/selfsigned/server.key \
        -auth.enabled \
        -auth.ca-public-key-base64 "$CA_PUBLIC_KEY_BASE64" \
        -auth.node-certificate-file "$node_certificate_file" \
        -auth.node-private-key-file "$node_private_key_file" &
else
    echo "AppServiceLauncher: skipping ChordDHT (NODE_URI, TRACKER_URL, CA_PUBLIC_KEY_BASE64, CHORD_AUTH_NODE_CERT, CHORD_AUTH_NODE_PRIVATE_KEY must all be set)" >&2
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
if [ -n "$APP_CMD" ]; then
    exec $APP_CMD
fi
