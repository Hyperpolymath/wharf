# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Jonathan D. A. Jewell <hyperpolymath>
#
# Yacht Agent Container for Project Wharf
# ========================================
# The runtime enforcer - database proxy and security monitor.
#
# Build: podman build -t yacht-agent:latest -f infra/containers/agent.Dockerfile .
# Run:   podman run -d -p 3306:3306 -p 9001:9001 yacht-agent:latest

# -----------------------------------------------------------------------------
# Stage 1: Build the Rust binary
# -----------------------------------------------------------------------------
FROM docker.io/library/rust:1.75-alpine AS builder

RUN apk add --no-cache musl-dev openssl-dev openssl-libs-static pkgconf

WORKDIR /build

# Copy workspace files
COPY Cargo.toml Cargo.lock ./
COPY crates/wharf-core ./crates/wharf-core
COPY bin/yacht-agent ./bin/yacht-agent
COPY bin/wharf-cli ./bin/wharf-cli

# Build release binary with static linking
ENV RUSTFLAGS="-C target-feature=+crt-static"
RUN cargo build --release --bin yacht-agent

# Verify binary
RUN ls -la target/release/yacht-agent

# -----------------------------------------------------------------------------
# Stage 2: Minimal runtime image
# -----------------------------------------------------------------------------
FROM docker.io/library/alpine:3.19

LABEL org.opencontainers.image.title="Yacht Agent"
LABEL org.opencontainers.image.description="Database proxy and security enforcer for Project Wharf"
LABEL org.opencontainers.image.vendor="Hyperpolymath"

# Install minimal runtime deps (none needed for static binary, but useful for debugging)
RUN apk add --no-cache ca-certificates

# Create non-root user
RUN addgroup -g 1000 wharf && adduser -u 1000 -G wharf -s /bin/false -D wharf

# Copy the static binary
COPY --from=builder /build/target/release/yacht-agent /usr/local/bin/yacht-agent

# Ensure binary is executable
RUN chmod +x /usr/local/bin/yacht-agent

# Create config directory
RUN mkdir -p /etc/wharf && chown wharf:wharf /etc/wharf

USER wharf

# Database proxy port (masquerade as MySQL)
EXPOSE 3306
# Agent API port
EXPOSE 9001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -q --spider http://localhost:9001/health || exit 1

# Default: MySQL protocol on port 3306, shadow DB on 33060
ENTRYPOINT ["yacht-agent"]
CMD ["--listen-port", "3306", "--shadow-port", "33060", "--api-port", "9001"]
