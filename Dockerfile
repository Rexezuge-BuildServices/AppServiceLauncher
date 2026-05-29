FROM rexezugedockerutils/cloudflared AS cloudflared

FROM ghcr.io/jeffvli/feishin:latest AS feishin

FROM rexezugedockerutils/chorddht AS chorddht

FROM rexezugedockerutils/nginx-static AS nginx-static

FROM debian:12 AS builder

WORKDIR /tmp

# Install Dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates openssl

# Generate Random Self Signed SSL Certificate
RUN mkdir -p /tmp/ssl/selfsigned \
 && openssl req -x509 -newkey rsa:2048 -days 365 -nodes -keyout /tmp/ssl/selfsigned/server.key -out /tmp/ssl/selfsigned/server.crt -subj "/CN=localhost"

FROM rexezugedockerutils/usagi-init:release AS runtime

COPY --from=feishin /usr/share/nginx/html /usr/share/nginx/html

COPY --from=feishin /etc/nginx/templates/settings.js.template /etc/nginx/templates/settings.js.template

COPY --from=cloudflared /cloudflared /usr/local/bin/cloudflared

COPY --from=chorddht /ChordDHT-Node /ChordDHT-Node

COPY --from=nginx-static /nginx /usr/sbin/nginx

COPY --from=builder /tmp/ssl/selfsigned /etc/ssl/selfsigned

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY overlay/ /

FROM scratch

COPY --from=runtime / /

ENV WEBSITES_PORT=80

EXPOSE 80/tcp

ENTRYPOINT ["/UsagiInit"]
