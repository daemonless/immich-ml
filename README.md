# Immich Machine Learning for FreeBSD

Machine learning service for [Immich](https://immich.app/) photo management.

Provides:
- Face recognition
- Image classification
- Smart search (CLIP embeddings)

## Usage

```bash
podman run -d --name immich-ml \
  -v /containers/immich/cache:/cache \
  -p 3003:3003 \
  ghcr.io/daemonless/immich-ml:latest
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| MACHINE_LEARNING_HOST | 0.0.0.0 | Listen address |
| MACHINE_LEARNING_PORT | 3003 | Service port |
| MACHINE_LEARNING_CACHE_FOLDER | /cache | Model cache directory |

## Volumes

- `/cache` - Model cache (downloads ML models on first run)
- `/config` - Configuration

## Ports

- `3003` - ML API

## Part of Immich for FreeBSD

See [daemonless/immich](https://github.com/daemonless/immich) for the complete stack.
