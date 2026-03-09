# 🗺️ OpenMap

**Self-hosted OpenStreetMap server in a single Docker container.**  
Works out-of-the-box with public tile servers. Optionally use self-hosted vector tiles (PMTiles), search (Photon), and routing (OSRM).

[![Docker Image](https://img.shields.io/docker/pulls/jonasa11y/openmap?logo=docker)](https://hub.docker.com/r/jonasa11y/openmap)
[![Build Status](https://github.com/Jonas-a11y/openmap/actions/workflows/docker.yml/badge.svg)](https://github.com/Jonas-a11y/openmap/actions)

---

## Quick Start

```bash
docker run -d \
  --name openmap \
  -p 8080:80 \
  -v openmap-data:/data \
  jonasa11y/openmap:latest
```

Open **`http://your-nas-ip:8080`** — map loads immediately using public OpenStreetMap tiles.

> No waiting, no mandatory downloads. Everything works out-of-the-box.

---

## Features

| Feature | Default (public) | Self-hosted |
|---|---|---|
| 🗺️ **Map display** | OSM raster tiles (tile.openstreetmap.org) | PMTiles vector tiles |
| 🔍 **Search** | photon.komoot.io | Photon (local) |
| 🧭 **Routing** | router.project-osrm.org | OSRM (local) |
| 📍 **Geolocation** | ✅ always | ✅ always |

The container **gracefully falls back** to public services when self-hosted data isn't available.

---

## Architecture

```
Browser → Nginx (:80)
            ├─ /           → Static frontend (MapLibre GL JS + PMTiles)
            ├─ /tiles/     → Static file serving (PMTiles range requests)
            ├─ /search     → Photon (:2322) — if data present
            ├─ /reverse    → Photon (:2322) — if data present
            └─ /route/     → OSRM (:5000)  — if data present
```

All processes managed by **supervisord** inside a single container. Services that aren't ready simply aren't started.

---

## Self-hosted Vector Tiles (PMTiles)

PMTiles is a single-file format that MapLibre can read directly via HTTP Range requests — no tile server needed.

### Option A: Download a pre-built extract

```bash
# Download Germany extract from Protomaps (~3-8 GB)
docker run --rm -v openmap-data:/data alpine \
  wget -O /data/tiles/map.pmtiles \
  "https://example.com/germany.pmtiles"
```

Then restart: `docker restart openmap`

### Option B: Set PMTILES_URL on start

The container downloads it automatically on first start:

```bash
docker run -d \
  --name openmap \
  -p 8080:80 \
  -v openmap-data:/data \
  -e PMTILES_URL="https://example.com/germany.pmtiles" \
  jonasa11y/openmap:latest
```

### Getting PMTiles files

- [maps.protomaps.com/builds](https://maps.protomaps.com/builds/) — Full planet + daily builds
- [download.geofabrik.de](https://download.geofabrik.de/) — OSM extracts (use `pmtiles convert` to generate PMTiles)
- Use the [pmtiles CLI](https://docs.protomaps.com/pmtiles/cli) to extract a custom region

---

## Self-hosted Search (Photon)

Photon is a geocoding engine powered by OpenStreetMap data.

```bash
docker run -d \
  --name openmap \
  -p 8080:80 \
  -v openmap-data:/data \
  -e PHOTON_DOWNLOAD_URL="https://download1.graphhopper.com/public/photon-db-de-1.0-latest.tar.bz2" \
  jonasa11y/openmap:latest
```

On first start, the container downloads the Photon database (~8-15 GB for Germany). This takes 20-60 minutes depending on your internet speed.

To **skip** Photon (always use public fallback):
```bash
-e PHOTON_DOWNLOAD_URL=none
```

---

## Self-hosted Routing (OSRM)

OSRM is a fast car-routing engine. Processing OSM data for Germany requires ~8 GB RAM and ~45 minutes.

```bash
docker run -d \
  --name openmap \
  -p 8080:80 \
  -v openmap-data:/data \
  -e DOWNLOAD_URL="https://download.geofabrik.de/europe/germany-latest.osm.pbf" \
  jonasa11y/openmap:latest
```

The container downloads and processes the OSM PBF file automatically. Routing data is stored in the volume and reused on restarts.

> **Requirements:** ≥ 8 GB RAM, ≥ 30 GB disk space for Germany  
> The container skips OSRM processing if < 4 GB RAM is available.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `REGION` | `germany` | Region name (used for file naming) |
| `DOWNLOAD_URL` | Germany PBF | OSM PBF URL for OSRM processing |
| `PMTILES_URL` | _(empty)_ | URL to download a .pmtiles file |
| `PHOTON_DOWNLOAD_URL` | Germany DB | Photon database URL (`none` to disable) |
| `TILES_MODE` | `pmtiles` | `pmtiles` or `osm` (auto-detected) |
| `PHOTON_JVM_HEAP` | `4g` | Photon JVM heap size |

---

## Custom Region (Example: France)

```bash
docker run -d \
  --name openmap \
  -p 8080:80 \
  -v openmap-data:/data \
  -e REGION=france \
  -e DOWNLOAD_URL="https://download.geofabrik.de/europe/france-latest.osm.pbf" \
  -e PHOTON_DOWNLOAD_URL="https://download1.graphhopper.com/public/photon-db-fr-1.0-latest.tar.bz2" \
  jonasa11y/openmap:latest
```

---

## Data Volume

All persistent data is stored in `/data`:

```
/data/
  tiles/
    map.pmtiles       ← self-hosted vector tiles
  photon/
    photon_data/      ← search index (extracted from tar.bz2)
  osrm/
    germany.osrm.*    ← routing graph
  logs/
    init.log          ← startup log
    photon.log        ← photon service log
    osrm.log          ← osrm service log
  .openmap-status.json ← service status tracking
```

---

## Resource Requirements

| Setup | RAM | Disk | First-run time |
|---|---|---|---|
| Public tiles only (default) | 256 MB | 100 MB | < 1 min |
| + Photon (Germany) | 4-6 GB | 15 GB | 30-60 min |
| + OSRM (Germany) | 8 GB | 30 GB | 45-90 min |
| Full self-hosted | 12 GB | 50 GB | 60-120 min |

---

## Stack

- **[MapLibre GL JS](https://maplibre.org/)** — Map rendering
- **[PMTiles](https://protomaps.com/blog/pmtiles)** — Single-file vector tile format
- **[@protomaps/basemaps](https://github.com/protomaps/basemaps)** — Map styles
- **[Photon](https://github.com/komoot/photon)** — Search/geocoding
- **[OSRM](https://project-osrm.org/)** — Routing engine
- **[Nginx](https://nginx.org/)** — Web server / reverse proxy
- **[supervisord](http://supervisord.org/)** — Process management
- **[OpenStreetMap](https://www.openstreetmap.org/)** — Map data

---

## License

Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors (ODbL)  
Map styles © [Protomaps](https://protomaps.com) (BSD-3)  
Software: MIT
