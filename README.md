<!--
Standard README template for daemonless application repositories.
Copy this to repos/<app>/README.md and fill in the placeholders.
-->

# immich-ml

Machine learning service for [Immich](https://immich.app/) photo management providing face recognition, image classification, and smart search.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PUID` | User ID for the application process | `1000` |
| `PGID` | Group ID for the application process | `1000` |
| `TZ` | Timezone for the container | `UTC` |
| `S6_LOG_ENABLE` | Enable/Disable file logging | `1` |
| `S6_LOG_MAX_SIZE` | Max size per log file (bytes) | `1048576` |
| `S6_LOG_MAX_FILES` | Number of rotated log files to keep | `10` |
| `MACHINE_LEARNING_HOST` | Listen address | `0.0.0.0` |
| `MACHINE_LEARNING_PORT` | Service port | `3003` |
| `MACHINE_LEARNING_CACHE_FOLDER` | Model cache directory | `/cache` |

## Logging

This image uses `s6-log` for internal log rotation.
- **System Logs**: Captured from console and stored at `/config/logs/daemonless/immich-ml/`.
- **Application Logs**: Managed by the app and typically found in `/config/logs/`.
- **Podman Logs**: Output is mirrored to the console, so `podman logs` still works.

## Quick Start

```bash
podman run -d --name immich-ml \
  -p 3003:3003 \
  -e PUID=1000 -e PGID=1000 \
  -v /path/to/config:/config \
  -v /path/to/cache:/cache \
  ghcr.io/daemonless/immich-ml:latest
```

Access at: http://localhost:3003

## podman-compose

```yaml
services:
  immich-ml:
    image: ghcr.io/daemonless/immich-ml:latest
    container_name: immich-ml
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - MACHINE_LEARNING_CACHE_FOLDER=/cache
    volumes:
      - /data/config/immich-ml:/config
      - /data/cache/immich-ml:/cache
    ports:
      - 3003:3003
    restart: unless-stopped
```

## Tags

| Tag | Source | Description |
|-----|--------|-------------|
| `:latest` | [Upstream Releases](https://github.com/immich-app/immich) | Latest upstream release |

## Volumes

| Path | Description |
|------|-------------|
| `/config` | Configuration directory |
| `/cache` | Model cache (downloads ML models on first run) |

## Ports

| Port | Description |
|------|-------------|
| 3003 | ML API |

## Notes

- **User:** `bsd` (UID/GID set via PUID/PGID, default 1000)
- **Base:** Built on `ghcr.io/daemonless/base-image` (FreeBSD)

## Links

- [Website](https://immich.app/)
- [Upstream Repo](https://github.com/immich-app/immich)