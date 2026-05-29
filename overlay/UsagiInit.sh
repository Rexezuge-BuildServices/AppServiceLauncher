#!/UsagiInit

# ChordDHT (guarded)
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

# cloudflared (guarded)
/.AppServiceLauncher/usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TOKEN" > /dev/null 2>&1 &

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
