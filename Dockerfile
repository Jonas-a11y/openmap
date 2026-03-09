# =============================================================================
#  OpenMap — All-in-One OSM Server
#  Multi-stage build: OSRM binaries (from source) + final runtime image
#  Supports: linux/amd64, linux/arm64
# =============================================================================

# ── Stage 1: Build OSRM (following official osrm/osrm-backend Dockerfile) ────
FROM debian:bullseye-slim AS osrm-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV OSRM_VERSION=5.27.1

RUN apt-get update && apt-get -y --no-install-recommends install \
    ca-certificates cmake make git gcc g++ \
    libbz2-dev libxml2-dev wget \
    libzip-dev libboost1.74-all-dev \
    lua5.4 liblua5.4-dev \
    && rm -rf /var/lib/apt/lists/*

# Build oneTBB from source (same version as official OSRM Docker image)
RUN git clone --depth=1 --branch v2021.3.0 \
    https://github.com/oneapi-src/oneTBB.git /tmp/oneTBB && \
    cd /tmp/oneTBB && \
    mkdir build && cd build && \
    cmake -DTBB_TEST=OFF -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . -j$(nproc) && \
    cmake --install . && \
    ldconfig /usr/local/lib && \
    rm -rf /tmp/oneTBB

# Download and build OSRM
RUN mkdir -p /src && \
    wget -qO- "https://github.com/Project-OSRM/osrm-backend/archive/refs/tags/v${OSRM_VERSION}.tar.gz" \
    | tar xz --strip-components=1 -C /src

WORKDIR /src
RUN mkdir build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DENABLE_ASSERTIONS=Off \
      -DBUILD_TOOLS=Off \
      -DENABLE_LTO=On && \
    make -j$(nproc) install && \
    cp -r profiles/ /opt/osrm-profiles/ && \
    strip /usr/local/bin/osrm-* 2>/dev/null || true


# ── Stage 2: Final runtime image ─────────────────────────────────────────────
FROM debian:bookworm-slim

LABEL maintainer="Jonas <jonas@openmap>"
LABEL description="All-in-One OpenStreetMap server: PMTiles, search, routing, frontend"
LABEL org.opencontainers.image.source="https://github.com/Jonas-a11y/openmap"

ENV DEBIAN_FRONTEND=noninteractive
ENV DATA_DIR=/data
ENV REGION=germany
ENV DOWNLOAD_URL=https://download.geofabrik.de/europe/germany-latest.osm.pbf
# Photon: set to "none" to disable
ENV PHOTON_DOWNLOAD_URL=https://download1.graphhopper.com/public/photon-db-de-1.0-latest.tar.bz2
# TILES_MODE: pmtiles | osm (auto-detected, don't need to set manually)
ENV TILES_MODE=osm
# Optional: direct PMTiles download URL
ENV PMTILES_URL=""
# Photon JVM heap
ENV PHOTON_JVM_HEAP=4g

# ── Install runtime dependencies ──────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    curl wget ca-certificates \
    # Nginx
    nginx \
    # Supervisord
    supervisor \
    # Java 21 (for Photon)
    default-jre-headless \
    # OSRM runtime libs (bullseye versions, needed since we built on bullseye)
    libboost-filesystem1.74.0 \
    libboost-iostreams1.74.0 \
    libboost-program-options1.74.0 \
    libboost-regex1.74.0 \
    libboost-thread1.74.0 \
    libboost-date-time1.74.0 \
    libboost-chrono1.74.0 \
    libboost-system1.74.0 \
    # Lua runtime (for OSRM profiles)
    liblua5.4-0 \
    # Expat XML library
    libexpat1 \
    # Bzip2 (for Photon tar.bz2)
    bzip2 pbzip2 \
    # Utilities
    jq \
    && rm -rf /var/lib/apt/lists/*

# ── Copy oneTBB runtime from builder ─────────────────────────────────────────
COPY --from=osrm-builder /usr/local/lib/libtbb* /usr/local/lib/
COPY --from=osrm-builder /usr/local/lib/libhwloc* /usr/local/lib/

# ── Copy OSRM binaries from builder ──────────────────────────────────────────
COPY --from=osrm-builder /usr/local/bin/osrm-extract  /usr/local/bin/
COPY --from=osrm-builder /usr/local/bin/osrm-partition /usr/local/bin/
COPY --from=osrm-builder /usr/local/bin/osrm-customize /usr/local/bin/
COPY --from=osrm-builder /usr/local/bin/osrm-routed   /usr/local/bin/
COPY --from=osrm-builder /opt/osrm-profiles/ /usr/share/osrm/profiles/

RUN ldconfig /usr/local/lib

# ── Install Photon ────────────────────────────────────────────────────────────
ENV PHOTON_VERSION=1.0.1
RUN mkdir -p /opt/photon && \
    wget -q \
      "https://github.com/komoot/photon/releases/download/${PHOTON_VERSION}/photon-${PHOTON_VERSION}.jar" \
      -O /opt/photon/photon.jar

# ── Create data and log directories ──────────────────────────────────────────
RUN mkdir -p \
    ${DATA_DIR}/tiles \
    ${DATA_DIR}/photon \
    ${DATA_DIR}/osrm \
    ${DATA_DIR}/logs \
    /var/log/openmap \
    /var/run/openmap \
    /tmp/nginx-cache

# ── Nginx config ──────────────────────────────────────────────────────────────
COPY nginx.conf /etc/nginx/nginx.conf

# ── Supervisor default config ─────────────────────────────────────────────────
COPY supervisord.conf /etc/supervisor/conf.d/openmap.conf

# ── Frontend ──────────────────────────────────────────────────────────────────
COPY frontend/ /var/www/html/

# ── Init script ───────────────────────────────────────────────────────────────
COPY init.sh /opt/init.sh
RUN chmod +x /opt/init.sh

# ── Volume ────────────────────────────────────────────────────────────────────
VOLUME ${DATA_DIR}

# ── Expose port ───────────────────────────────────────────────────────────────
EXPOSE 80

# ── Health check ──────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -sf http://localhost/health || exit 1

# ── Entrypoint ────────────────────────────────────────────────────────────────
ENTRYPOINT ["/opt/init.sh"]
