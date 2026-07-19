# syntax=docker/dockerfile:1

# intentionally not strict: CI rebuilds (and the quadlet's Pull=newer) pick up base image updates
FROM docker.io/library/ubuntu:24.04

ARG SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG http_proxy
ARG https_proxy
ARG no_proxy

# ca-certificates is injected from host env if not in CI.
# Splitting layer so it works in both environments.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
    apt-get update && apt-get install -yqq --no-install-recommends ca-certificates \
        || echo "WARNING: ca-certificates not installed; a CA bundle must be provided externally" >&2
EOF

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=secret,id=certs,target=/etc/ssl/certs/ca-certificates.crt \
<<EOF
    apt-get update
    apt-get install -yqq --no-install-recommends \
        build-essential \
        curl \
        git \
        libssl-dev \
        pkg-config
EOF

RUN --mount=type=secret,id=certs,target=/etc/ssl/certs/ca-certificates.crt \
<<EOF
    curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
    export PATH="/root/.moon/bin:${PATH}"
    moon update
EOF

ENV PATH="/root/.moon/bin:${PATH}"
