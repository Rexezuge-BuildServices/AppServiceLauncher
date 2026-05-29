# AppServiceLauncher

A reusable Docker layer that adds [cloudflared](https://github.com/cloudflare/cloudflared), [ChordDHT](https://github.com/rexezuge/ChordDHT), and nginx as guarded background services to any existing container image. The original image's entrypoint and CMD run unmodified and unguarded — if the app exits, UsagiInit stays up and continues managing the background services.

## How it works

The layer is built as a self-contained rootfs under `/.AppServiceLauncher/`. Applying it to another image is two Dockerfile lines:

```dockerfile
FROM your-base-image

COPY --from=rexezugebuild/appservicelauncher:latest /.AppServiceLauncher/ /.AppServiceLauncher/
ENTRYPOINT ["/.AppServiceLauncher/launcher.sh"]
CMD ["your-original-entrypoint", "--original-args"]
```

At container start:

1. `launcher.sh` captures the Docker `CMD` args as `APP_CMD` and exec's [UsagiInit](https://github.com/rexezuge/UsagiInit) with the init script.
2. `UsagiInit.sh` starts **ChordDHT**, **cloudflared**, and **nginx** as guarded background services (UsagiInit will restart them if they crash).
3. `exec $APP_CMD` replaces the shell with the original application — this process is **not** registered as a service and is **never restarted** by UsagiInit.
4. When the original app exits, UsagiInit enters pure guardian mode and continues monitoring the three background services.

If no `CMD` is given, the container runs in **background-services-only** mode (no original app exec).

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `CLOUDFLARE_TOKEN` | Yes | Cloudflare Tunnel token (`cloudflared tunnel … run --token`) |
| `NODE_URI` | Yes | ChordDHT node URI |
| `TRACKER_URL` | Yes | ChordDHT tracker URL |
| `CA_PUBLIC_KEY_BASE64` | Yes | Base64-encoded CA public key for ChordDHT mutual TLS auth |
| `CHORD_AUTH_NODE_CERT` | Yes | PEM content of the node's TLS client certificate |
| `CHORD_AUTH_NODE_PRIVATE_KEY` | Yes | PEM content of the node's TLS private key |

## nginx

nginx listens on port **80** and proxies `/chord/` and `/api/chord/` to ChordDHT at `:8443`. All other routes return 404 by default — the original application's own port is unaffected and accessible directly.

To add custom locations, mount or build additional `.conf` files into `/.AppServiceLauncher/etc/nginx/conf.d/`.

## Example

```dockerfile
FROM postgres:16

COPY --from=rexezugebuild/appservicelauncher:latest /.AppServiceLauncher/ /.AppServiceLauncher/
ENTRYPOINT ["/.AppServiceLauncher/launcher.sh"]
CMD ["docker-entrypoint.sh", "postgres"]
```

```sh
docker run \
  -e CLOUDFLARE_TOKEN=… \
  -e NODE_URI=… \
  -e TRACKER_URL=… \
  -e CA_PUBLIC_KEY_BASE64=… \
  -e CHORD_AUTH_NODE_CERT="$(cat node.crt)" \
  -e CHORD_AUTH_NODE_PRIVATE_KEY="$(cat node.key)" \
  -e POSTGRES_PASSWORD=secret \
  my-postgres-with-launcher
```
