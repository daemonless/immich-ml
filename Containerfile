# Immich Machine Learning for FreeBSD
# Python-based ML service for face recognition, image classification, and smart search

ARG BASE_VERSION=15
ARG IMMICH_VERSION=v2.4.1

FROM ghcr.io/daemonless/base:${BASE_VERSION} AS builder

ARG IMMICH_VERSION

# Build dependencies - use FreeBSD-packaged python libraries where possible
# FreeBSD-utilities-dev provides omp.h for OpenMP (needed if any package builds from source)
# py311-onnx from ports avoids build issues with pip onnx (nanobind needs Python 3.13+)
RUN pkg update && pkg install -y \
    python311 py311-pip py311-setuptools py311-wheel \
    py311-numpy py311-pillow py311-orjson py311-scipy py311-scikit-learn \
    py311-pydantic2 py311-pydantic-settings \
    py311-fastapi py311-uvicorn py311-gunicorn \
    py311-huggingface-hub py311-tokenizers \
    py311-onnx onnxruntime \
    git-lite gmake pkgconf \
    FreeBSD-clang FreeBSD-clibs-dev FreeBSD-clang-dev FreeBSD-utilities-dev \
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
# Pin numpy<2 to avoid conflicts with scipy from ports
RUN pip install --no-cache-dir \
    "numpy<2" \
    aiocache \
    ftfy \
    python-multipart \
    rich

# Install opencv-python-headless with --no-deps to avoid numpy 2.x
# (it works fine with numpy 1.x at runtime)
RUN pip install --no-cache-dir --no-deps opencv-python-headless || true

# Install insightface for face recognition
# onnx is already installed from ports, so insightface should build cleanly
RUN pip install --no-cache-dir insightface || true

# Patch pyproject.toml for FreeBSD compatibility:
# 1. uvicorn[standard] -> uvicorn (avoid watchfiles/maturin which need Rust)
# 2. Adjust numpy constraint to match system package
RUN cat pyproject.toml && \
    sed -i '' 's/uvicorn\[standard\]/uvicorn/g' pyproject.toml && \
    cat pyproject.toml | grep -i uvicorn

# Install the app with relaxed dependency checking
# Use --no-deps first, then install missing deps manually
RUN pip install --no-cache-dir --no-deps . && \
    pip install --no-cache-dir \
    rapidocr \
    starlette \
    httptools \
    || true

# Production image
FROM ghcr.io/daemonless/base:${BASE_VERSION}

ARG FREEBSD_ARCH=amd64
ARG IMMICH_VERSION
ARG PACKAGES="python311 py311-numpy py311-pillow py311-orjson py311-scipy py311-scikit-learn py311-pydantic2 py311-pydantic-settings py311-fastapi py311-uvicorn py311-gunicorn py311-huggingface-hub py311-tokenizers py311-onnx onnxruntime openblas"

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
