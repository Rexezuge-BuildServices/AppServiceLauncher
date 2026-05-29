# AppServiceLauncher

A reusable Docker layer that adds [Cloudflared](https://github.com/Rexezuge-DockerUtils/Cloudflared), [ChordDHT](https://github.com/Rexezuge-DockerUtils/ChordDHT), and [Nginx-Static](https://github.com/Rexezuge-DockerUtils/Nginx-Static) as guarded background services to any existing container image. The original image's entrypoint and CMD run unmodified and unguarded — if the app exits, [UsagiInit](https://github.com/Rexezuge-DockerUtils/UsagiInit) stays up and continues managing the background services.

## How it works

The layer is built as a self-contained rootfs under `/.AppServiceLauncher/`. Applying it to another image is two Dockerfile lines:

```dockerfile
FROM your-base-image

COPY --from=rexezugebuild/appservicelauncher:latest /.AppServiceLauncher/ /.AppServiceLauncher/
ENTRYPOINT ["/.AppServiceLauncher/launcher.sh"]
CMD ["your-original-entrypoint", "--original-args"]
```

At container start:

1. `launcher.sh` captures the Docker `CMD` args as `APP_CMD` and exec's [UsagiInit](https://github.com/Rexezuge-DockerUtils/UsagiInit) with the init script.
2. `UsagiInit.sh` starts **ChordDHT**, **cloudflared**, and **nginx** as guarded background services (UsagiInit will restart them if they crash). Services whose required environment variables are not set are skipped with a warning to stderr.
3. `exec $APP_CMD` replaces the shell with the original application — this process is **not** registered as a service and is **never restarted** by UsagiInit.
4. When the original app exits, UsagiInit enters pure guardian mode and continues monitoring the three background services.

If no `CMD` is given, the container runs in **background-services-only** mode (no original app exec).

## Environment variables

| Variable | Service | Description |
|---|---|---|
| `APP_USER` | AppServiceLauncher | Unix user to run the application as. If set, privileges are dropped via `su-exec` before exec'ing `APP_CMD`. If unset, the application inherits the container's current user (typically root). |
| `CLOUDFLARE_TOKEN` | cloudflared | Cloudflare Tunnel token (`cloudflared tunnel … run --token`). If unset, cloudflared is skipped. |
| `NODE_URI` | ChordDHT | Canonical HTTPS URI for this node (`https://node.example.com`). |
| `TRACKER_URL` | ChordDHT | Bootstrap tracker URL. |
| `CA_PUBLIC_KEY_BASE64` | ChordDHT | Base64-encoded CA Ed25519 public key for mutual TLS auth. |
| `CHORD_AUTH_NODE_CERT` | ChordDHT | JSON content of the node's CA-issued certificate. |
| `CHORD_AUTH_NODE_PRIVATE_KEY` | ChordDHT | Base64-encoded Ed25519 private key for the node. |

All five ChordDHT variables must be set together — if any is missing, ChordDHT is skipped entirely with a warning to stderr.

## nginx

nginx listens on port **80** and proxies `/chord/` to ChordDHT at `:8443`. All other routes return 404 by default — the original application's own port is unaffected and accessible directly.

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
  -e NODE_URI=https://node.example.com \
  -e TRACKER_URL=https://tracker.example.com \
  -e CA_PUBLIC_KEY_BASE64=… \
  -e CHORD_AUTH_NODE_CERT="$(cat node.cert.json)" \
  -e CHORD_AUTH_NODE_PRIVATE_KEY="$(cat node.privkey.b64)" \
  -e POSTGRES_PASSWORD=secret \
  my-postgres-with-launcher
```
