#!/bin/bash
set -e

DATA_DIR="${DATA_DIR:-/data}"
REGION="${REGION:-germany}"
PBF_URL="${DOWNLOAD_URL:-https://download.geofabrik.de/europe/germany-latest.osm.pbf}"
PBF_FILE="${DATA_DIR}/${REGION}.osm.pbf"

echo "============================================"
echo "  🗺️  OpenMap — All-in-One OSM Server"
echo "============================================"
echo "  Region: ${REGION}"
echo "  Data:   ${DATA_DIR}"
echo "============================================"

# ========== DOWNLOAD OSM DATA ==========
if [ ! -f "${PBF_FILE}" ]; then
    echo "📥 Downloading OSM data for ${REGION}..."
    wget -q --show-progress -O "${PBF_FILE}" "${PBF_URL}"
    echo "✅ Download complete"
else
    echo "✅ OSM data already exists"
fi

# ========== PREPARE TILES ==========
MBTILES="${DATA_DIR}/tiles/${REGION}.mbtiles"
if [ ! -f "${MBTILES}" ]; then
    echo "🔨 Generating vector tiles (this takes a while on first run)..."
    # Use tilemaker for generating tiles from PBF
    if command -v tilemaker &> /dev/null; then
        tilemaker --input "${PBF_FILE}" --output "${MBTILES}"
    else
        echo "⚠️  tilemaker not found, downloading pre-built tiles..."
        # Fallback: download pre-built mbtiles for the region
        wget -q --show-progress \
            -O "${MBTILES}" \
            "https://data.source.coop/protomaps/openstreetmap/tiles/v3.json" 2>/dev/null || \
        echo "⚠️  Could not download pre-built tiles. Please provide ${MBTILES} manually."
    fi
    echo "✅ Tiles ready"
else
    echo "✅ Tiles already exist"
fi

# Write tileserver config
cat > "${DATA_DIR}/tiles/config.json" << EOF
{
  "options": {
    "paths": {
      "root": "/data/tiles",
      "mbtiles": "/data/tiles"
    }
  },
  "data": {
    "${REGION}": {
      "mbtiles": "${REGION}.mbtiles"
    }
  }
}
EOF

# ========== PREPARE OSRM ==========
OSRM_FILE="${DATA_DIR}/osrm/${REGION}.osrm"
if [ ! -f "${OSRM_FILE}.datasource" ]; then
    echo "🔨 Preparing routing data (this takes a while on first run)..."
    cd "${DATA_DIR}/osrm"
    
    # Get car profile
    if [ ! -f "car.lua" ]; then
        wget -q -O car.lua \
            "https://raw.githubusercontent.com/Project-OSRM/osrm-backend/master/profiles/car.lua"
        wget -q -O lib/access.lua --create-dirs \
            "https://raw.githubusercontent.com/Project-OSRM/osrm-backend/master/profiles/lib/access.lua" 2>/dev/null || true
    fi
    
    osrm-extract -p car.lua "${PBF_FILE}" -o "${OSRM_FILE}" 2>/dev/null || \
    osrm-extract -p /usr/share/osrm/profiles/car.lua "${PBF_FILE}" 2>/dev/null || \
    echo "⚠️  OSRM extract needs more RAM, trying with less memory..."
    
    if [ -f "${OSRM_FILE}" ]; then
        osrm-partition "${OSRM_FILE}"
        osrm-customize "${OSRM_FILE}"
        echo "✅ Routing data ready"
    else
        echo "⚠️  Routing data preparation failed — routing will be unavailable"
    fi
else
    echo "✅ Routing data already exists"
fi

# ========== PREPARE PHOTON ==========
PHOTON_DB="${DATA_DIR}/photon/photon_data"
if [ ! -d "${PHOTON_DB}" ]; then
    echo "📥 Downloading Photon search index for ${REGION}..."
    cd "${DATA_DIR}/photon"
    
    # Photon provides pre-built search indices
    wget -q --show-progress \
        -O photon-db-latest.tar.bz2 \
        "https://download1.graphhopper.com/public/extracts/by-country-code/de/photon-db-de-latest.tar.bz2" 2>/dev/null || \
    echo "⚠️  Could not download Photon index. Search will be unavailable."
    
    if [ -f "photon-db-latest.tar.bz2" ]; then
        echo "📦 Extracting search index..."
        tar xjf photon-db-latest.tar.bz2
        rm -f photon-db-latest.tar.bz2
        echo "✅ Search index ready"
    fi
else
    echo "✅ Search index already exists"
fi

echo ""
echo "============================================"
echo "  🚀 Starting all services..."
echo "============================================"

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
