FROM debian:bookworm-slim

LABEL maintainer="Jonas <jonas@openmap>"
LABEL description="All-in-one OpenStreetMap server: tiles, search, routing, frontend"

ENV DEBIAN_FRONTEND=noninteractive
ENV DATA_DIR=/data
ENV REGION=germany
ENV DOWNLOAD_URL=https://download.geofabrik.de/europe/germany-latest.osm.pbf

# ========== INSTALL DEPENDENCIES ==========
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget unzip ca-certificates gnupg \
    nginx supervisor \
    nodejs npm \
    default-jre-headless \
    build-essential cmake pkg-config \
    libboost-all-dev libluabind-dev libtbb-dev \
    libstxxl-dev libxml2-dev libzip-dev \
    lua5.4 liblua5.4-dev \
    libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

# ========== TILESERVER-GL ==========
RUN npm install -g tileserver-gl-light@latest

# ========== OSRM ==========
RUN apt-get update && apt-get install -y --no-install-recommends \
    osrm-tools \
    && rm -rf /var/lib/apt/lists/*

# ========== PHOTON ==========
ENV PHOTON_VERSION=0.52.0
RUN mkdir -p /opt/photon && \
    wget -q "https://github.com/komoot/photon/releases/download/${PHOTON_VERSION}/photon-${PHOTON_VERSION}.jar" \
    -O /opt/photon/photon.jar

# ========== FRONTEND ==========
COPY frontend/ /var/www/html/

# ========== NGINX CONFIG ==========
COPY nginx.conf /etc/nginx/nginx.conf

# ========== SUPERVISOR CONFIG ==========
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ========== INIT SCRIPT ==========
COPY init.sh /opt/init.sh
RUN chmod +x /opt/init.sh

# ========== DATA VOLUME ==========
RUN mkdir -p ${DATA_DIR}/tiles ${DATA_DIR}/photon ${DATA_DIR}/osrm
VOLUME ${DATA_DIR}

# ========== PORTS ==========
# 80: Nginx (frontend + reverse proxy)
EXPOSE 80

# ========== HEALTHCHECK ==========
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# ========== ENTRYPOINT ==========
ENTRYPOINT ["/opt/init.sh"]
