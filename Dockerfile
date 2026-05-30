FROM alpine:3 AS su-exec-builder

RUN apk add --no-cache gcc musl-dev \
 && wget -qO /tmp/su-exec.c https://raw.githubusercontent.com/ncopa/su-exec/master/su-exec.c \
 && cc -static -Wall -Werror -o /tmp/su-exec /tmp/su-exec.c \
 && strip /tmp/su-exec

FROM rexezugedockerutils/cloudflared AS cloudflared

FROM rexezugedockerutils/chorddht AS chorddht

FROM rexezugedockerutils/nginx-static AS nginx-static

FROM debian:12 AS builder

WORKDIR /tmp

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates openssl curl

RUN mkdir -p /tmp/ssl/selfsigned \
 && openssl req -x509 -newkey rsa:2048 -days 365 -nodes -keyout /tmp/ssl/selfsigned/server.key -out /tmp/ssl/selfsigned/server.crt -subj "/CN=localhost"

RUN mkdir -p /tmp/ChordDHT \
 && curl -o /tmp/ChordDHT/CERTIFICATE_REVOCATION_LIST.json -L "https://raw.githubusercontent.com/Rexezuge-ConfigurationFiles/ChordDHT-TrustAnchors/refs/heads/main/CERTIFICATE_REVOCATION_LIST.json" \
 && curl -o /tmp/ChordDHT/CERTIFICATE_AUTHORITY_PUBLIC_KEY.b64 -L "https://raw.githubusercontent.com/Rexezuge-ConfigurationFiles/ChordDHT-TrustAnchors/refs/heads/main/CERTIFICATE_AUTHORITY_PUBLIC_KEY.b64"

FROM scratch AS runtime

COPY --from=cloudflared /cloudflared /usr/local/bin/cloudflared

COPY --from=builder /tmp/ChordDHT /ChordDHT

COPY --from=chorddht /ChordDHT-Node /ChordDHT/ChordDHT-Node

COPY --from=nginx-static /nginx /usr/sbin/nginx

COPY --from=builder /tmp/ssl/selfsigned /etc/ssl/selfsigned

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=su-exec-builder /tmp/su-exec /su-exec

COPY overlay/ /

RUN chmod +x /launcher.sh

FROM scratch

COPY --from=rexezugedockerutils/usagi-init:release / /

COPY --from=runtime / /.AppServiceLauncher

ENTRYPOINT ["/.AppServiceLauncher/launcher.sh"]
