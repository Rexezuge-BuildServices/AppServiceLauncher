FROM rexezugedockerutils/cloudflared AS cloudflared

FROM rexezugedockerutils/chorddht AS chorddht

FROM rexezugedockerutils/nginx-static AS nginx-static

FROM debian:12 AS builder

WORKDIR /tmp

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates openssl

RUN mkdir -p /tmp/ssl/selfsigned \
 && openssl req -x509 -newkey rsa:2048 -days 365 -nodes -keyout /tmp/ssl/selfsigned/server.key -out /tmp/ssl/selfsigned/server.crt -subj "/CN=localhost"

FROM rexezugedockerutils/usagi-init:release AS runtime

COPY --from=cloudflared /cloudflared /usr/local/bin/cloudflared

COPY --from=chorddht /ChordDHT-Node /ChordDHT-Node

COPY --from=nginx-static /nginx /usr/sbin/nginx

COPY --from=builder /tmp/ssl/selfsigned /etc/ssl/selfsigned

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY overlay/ /

RUN chmod +x /launcher.sh

FROM scratch

COPY --from=runtime / /.AppServiceLauncher/

ENTRYPOINT ["/.AppServiceLauncher/launcher.sh"]
