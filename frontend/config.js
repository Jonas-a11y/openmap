// Default config — overridden at runtime by /opt/init.sh
// This file ensures the frontend works even during development (without Docker)
window.OPENMAP_CONFIG = {
  tilesMode: 'osm',
  tilesAvailable: false,
  photonAvailable: false,
  osrmAvailable: false,
  region: 'germany',
  generatedAt: 'static-default',
};
