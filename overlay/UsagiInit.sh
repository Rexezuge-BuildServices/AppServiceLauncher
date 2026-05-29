#!/UsagiInit

# ChordDHT
node_certificate_file=$(mktemp)
echo "$CHORD_AUTH_NODE_CERT" > "$node_certificate_file"
node_private_key_file=$(mktemp)
echo "$CHORD_AUTH_NODE_PRIVATE_KEY" > "$node_private_key_file"
/ChordDHT-Node -uri "$NODE_URI" -tracker-url "$TRACKER_URL" -listen :8443 -tls-cert /etc/ssl/selfsigned/server.crt -tls-key /etc/ssl/selfsigned/server.key -auth.enabled -auth.ca-public-key-base64 "$CA_PUBLIC_KEY_BASE64" -auth.node-certificate-file "$node_certificate_file" -auth.node-private-key-file "$node_private_key_file" &

# Cloudflared
/usr/local/bin/cloudflared tunnel --no-autoupdate run --token $CLOUDFLARE_TOKEN > /dev/null 2>&1 &

# Feishin
envsubst < /etc/nginx/templates/settings.js.template > /etc/nginx/conf.d/settings.js

# Nginx
mkdir -p /tmp/nginx/logs
/usr/sbin/nginx -p /tmp/nginx -c /etc/nginx/nginx.conf -g "daemon off;" > /dev/null 2>&1 &
