# Immich Machine Learning for FreeBSD
# Python-based ML service for face recognition, image classification, and smart search

ARG BASE_VERSION=15
ARG IMMICH_VERSION=v2.4.1

FROM ghcr.io/daemonless/base:${BASE_VERSION} AS builder

ARG IMMICH_VERSION

# Build dependencies - use FreeBSD-packaged python libraries where possible
RUN pkg update && pkg install -y \
    python311 py311-pip py311-setuptools py311-wheel \
    py311-numpy py311-pillow py311-orjson py311-scipy \
    py311-pydantic2 py311-pydantic-settings \
    py311-fastapi py311-uvicorn py311-gunicorn \
    py311-huggingface-hub py311-tokenizers \
    onnxruntime \
    git-lite gmake pkgconf \
    FreeBSD-clang FreeBSD-clibs-dev FreeBSD-clang-dev \
    opencv cmake ninja \
    openblas gcc \
    && pkg clean -ay

# Create virtual environment with system packages
RUN python3.11 -m venv --system-site-packages /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Clone immich source
WORKDIR /build
RUN git clone --depth 1 --branch ${IMMICH_VERSION} \
    https://github.com/immich-app/immich.git .

WORKDIR /build/machine-learning

# Install remaining dependencies not available from ports
RUN pip install --no-cache-dir \
    aiocache \
    ftfy \
    python-multipart \
    rich

# Install opencv-python-headless (might need to build from source)
RUN pip install --no-cache-dir opencv-python-headless || \
    pip install --no-cache-dir opencv-python || true

# Install insightface for face recognition (may require building)
RUN pip install --no-cache-dir insightface || true

# Install the app itself
RUN pip install --no-cache-dir .

# Production image
FROM ghcr.io/daemonless/base:${BASE_VERSION}

ARG FREEBSD_ARCH=amd64
ARG IMMICH_VERSION
ARG PACKAGES="python311 py311-numpy py311-pillow py311-orjson py311-scipy py311-pydantic2 py311-pydantic-settings py311-fastapi py311-uvicorn py311-gunicorn py311-huggingface-hub py311-tokenizers onnxruntime openblas"

LABEL org.opencontainers.image.title="Immich Machine Learning" \
    org.opencontainers.image.description="Immich ML service for FreeBSD" \
    org.opencontainers.image.source="https://github.com/daemonless/immich-ml" \
    org.opencontainers.image.url="https://immich.app/" \
    org.opencontainers.image.version="${IMMICH_VERSION}" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.vendor="daemonless" \
    org.opencontainers.image.authors="daemonless" \
    io.daemonless.port="3003" \
    io.daemonless.arch="${FREEBSD_ARCH}" \
    io.daemonless.config-mount="/config" \
    io.daemonless.category="Media" \
    io.daemonless.packages="${PACKAGES}"

# Install runtime dependencies
RUN pkg update && \
    pkg install -y ${PACKAGES} && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* /var/db/pkg/repos/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Create directories
RUN mkdir -p /config /cache && \
    chown -R bsd:bsd /config /cache /opt/venv

# Copy service files
COPY root/ /
RUN chmod +x /etc/services.d/*/run /etc/cont-init.d/* 2>/dev/null || true

ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"
ENV MACHINE_LEARNING_HOST=0.0.0.0
ENV MACHINE_LEARNING_PORT=3003
ENV MACHINE_LEARNING_CACHE_FOLDER=/cache

EXPOSE 3003
VOLUME /config /cache
