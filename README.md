# 🗺️ OpenMap

Self-hosted OpenStreetMap server. One Docker image, all included.

## Quick Start

```bash
docker run -d \
  --name openmap \
  -p 8080:80 \
  -v openmap-data:/data \
  jonasa11y/openmap:latest
```

Open `http://your-nas-ip:8080` and done.

## First Run

On first start, the container will:
1. 📥 Download OSM data for Germany (~4GB)
2. 🔨 Prepare search index
3. 🗺️ Set up routing

**This takes 30-60 minutes on first run.** After that, data is cached in the volume.

## Features

- 🗺️ **Map tiles** — Vector/raster tiles via tileserver-gl
- 🔍 **Search** — Geocoding via Photon (type an address, get coordinates)
- 🧭 **Routing** — Car routing via OSRM
- 📍 **Geolocation** — "Where am I?" button
- 📱 **Responsive** — Works on mobile and desktop

## Custom Region

```bash
docker run -d \
  --name openmap \
  -p 8080:80 \
  -v openmap-data:/data \
  -e REGION=europe \
  -e DOWNLOAD_URL=https://download.geofabrik.de/europe-latest.osm.pbf \
  jonasa11y/openmap:latest
```

## Architecture

```
Browser → Nginx (:80)
            ├─ /         → Static frontend (MapLibre GL JS)
            ├─ /tiles/   → tileserver-gl (:8080)
            ├─ /search   → Photon (:2322)
            └─ /route/   → OSRM (:5000)
```

All managed by supervisord in a single container.

## Requirements

- Docker
- ~25GB disk space (Germany)
- ~4GB RAM recommended
- Internet for first-time data download

## Stack

- **[MapLibre GL JS](https://maplibre.org/)** — Map rendering
- **[tileserver-gl](https://github.com/maptiler/tileserver-gl)** — Tile serving
- **[Photon](https://github.com/komoot/photon)** — Search/geocoding
- **[OSRM](https://project-osrm.org/)** — Routing
- **[OpenStreetMap](https://www.openstreetmap.org/)** — Map data

## License

Map data © OpenStreetMap contributors (ODbL)
