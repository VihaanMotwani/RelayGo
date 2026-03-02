import { useEffect, useRef } from 'react';
import mapboxgl from 'mapbox-gl';
import {
  clusterPaint,
  clusterCountLayout,
  clusterCountPaint,
  getMarkerColor,
  TYPE_LABELS,
} from '../utils/mapStyles';
import { useTheme } from '../hooks/useTheme';

mapboxgl.accessToken = import.meta.env.VITE_MAPBOX_TOKEN || '';

const MAP_STYLES = {
  light: 'mapbox://styles/mapbox/streets-v12',
  dark: 'mapbox://styles/mapbox/dark-v11',
};

function reportsToGeoJSON(reports) {
  return {
    type: 'FeatureCollection',
    features: reports
      .filter((r) => r.loc?.lat != null && r.loc?.lng != null)
      .map((r) => ({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [r.loc.lng, r.loc.lat],
        },
        properties: {
          id: r.id || '',
          type: r.type?.toLowerCase() || 'other',
          description: r.desc || r.description || '',
          urgency: r.urg ?? r.urgency ?? 1,
          hop_count: r.hops ?? r.hop_count ?? 0,
          timestamp: r.ts || r.timestamp || '',
        },
      })),
  };
}

const styles = {
  wrapper: { position: 'relative', width: '100%', height: '100%' },
  map: { width: '100%', height: '100%' },
};

// Create pulsing HTML marker element
function createMarkerEl(color) {
  const el = document.createElement('div');
  el.className = 'incident-marker';

  const dot = document.createElement('div');
  dot.className = 'incident-marker-dot';
  dot.style.background = color;

  const pulse = document.createElement('div');
  pulse.className = 'incident-marker-pulse';
  pulse.style.background = color;

  el.appendChild(pulse);
  el.appendChild(dot);
  return el;
}

export default function Map({ reports }) {
  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const sourceReady = useRef(false);
  const reportsRef = useRef(reports);
  const markersRef = useRef([]);
  const { theme } = useTheme();

  reportsRef.current = reports;

  // Hide non-essential POI labels
  function stripPOIs(map) {
    const style = map.getStyle();
    if (!style?.layers) return;
    style.layers.forEach((layer) => {
      if (layer.id.includes('poi')) {
        map.setLayoutProperty(layer.id, 'visibility', 'none');
      }
    });
  }

  // Add cluster source and layers (no unclustered circles — we use HTML markers instead)
  function addClusterLayers(map, data) {
    map.addSource('reports', {
      type: 'geojson',
      data,
      cluster: true,
      clusterMaxZoom: 14,
      clusterRadius: 50,
    });

    map.addLayer({
      id: 'clusters',
      type: 'circle',
      source: 'reports',
      filter: ['has', 'point_count'],
      paint: clusterPaint,
    });

    map.addLayer({
      id: 'cluster-count',
      type: 'symbol',
      source: 'reports',
      filter: ['has', 'point_count'],
      layout: clusterCountLayout,
      paint: clusterCountPaint,
    });

    sourceReady.current = true;
  }

  // Add 3D terrain, fog, buildings
  function add3DLayers(map, isDark) {
    map.addSource('mapbox-dem', {
      type: 'raster-dem',
      url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
      tileSize: 512,
      maxzoom: 14,
    });
    map.setTerrain({ source: 'mapbox-dem', exaggeration: 1.5 });

    map.setFog({
      color: isDark ? 'rgb(12, 12, 20)' : 'rgb(220, 225, 235)',
      'high-color': isDark ? 'rgb(20, 20, 40)' : 'rgb(200, 210, 230)',
      'horizon-blend': 0.08,
      'space-color': isDark ? 'rgb(8, 8, 14)' : 'rgb(180, 195, 220)',
      'star-intensity': isDark ? 0.4 : 0.0,
    });

    const layers = map.getStyle().layers;
    const labelLayerId = layers.find(
      (l) => l.type === 'symbol' && l.layout?.['text-field']
    )?.id;

    map.addLayer(
      {
        id: '3d-buildings',
        source: 'composite',
        'source-layer': 'building',
        filter: ['==', 'extrude', 'true'],
        type: 'fill-extrusion',
        minzoom: 14,
        paint: {
          'fill-extrusion-color': isDark ? '#3a3a50' : '#d8d8e0',
          'fill-extrusion-height': ['get', 'height'],
          'fill-extrusion-base': ['get', 'min_height'],
          'fill-extrusion-opacity': isDark ? 0.85 : 0.6,
          'fill-extrusion-vertical-gradient': true,
        },
      },
      labelLayerId
    );
  }

  // Add building hover highlight layer
  function addBuildingHover(map, isDark) {
    map.addLayer(
      {
        id: '3d-buildings-highlight',
        source: 'composite',
        'source-layer': 'building',
        filter: ['==', 'extrude', 'true'],
        type: 'fill-extrusion',
        minzoom: 14,
        paint: {
          'fill-extrusion-color': isDark ? '#5a5a78' : '#b8b8d0',
          'fill-extrusion-height': ['get', 'height'],
          'fill-extrusion-base': ['get', 'min_height'],
          'fill-extrusion-opacity': 0,
        },
      }
    );

    let hoveredId = null;

    map.on('mousemove', '3d-buildings', (e) => {
      if (e.features.length > 0) {
        map.getCanvas().style.cursor = 'pointer';
        // Highlight by increasing opacity of the highlight layer for this feature
        map.setPaintProperty('3d-buildings-highlight', 'fill-extrusion-opacity', 0.9);
        map.setFilter('3d-buildings-highlight', [
          'all',
          ['==', 'extrude', 'true'],
          ['==', ['id'], e.features[0].id],
        ]);
      }
    });

    map.on('mouseleave', '3d-buildings', () => {
      map.getCanvas().style.cursor = '';
      map.setPaintProperty('3d-buildings-highlight', 'fill-extrusion-opacity', 0);
    });
  }

  // Sync pulsing HTML markers with reports
  function syncMarkers(map, reports) {
    // Remove old markers
    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    reports.forEach((r) => {
      if (r.loc?.lat == null || r.loc?.lng == null) return;

      const type = r.type?.toLowerCase() || 'other';
      const color = getMarkerColor(type);
      const el = createMarkerEl(color);
      const label = TYPE_LABELS[type] || type;
      const desc = r.desc || r.description || '';
      const urgency = r.urg ?? r.urgency ?? 1;
      const hops = r.hops ?? r.hop_count ?? 0;
      const ts = r.ts || r.timestamp;
      const tsStr = ts ? new Date(typeof ts === 'number' && ts < 1e12 ? ts * 1000 : ts).toLocaleString() : 'Unknown';

      el.addEventListener('click', () => {
        new mapboxgl.Popup({ closeButton: true, closeOnClick: true, maxWidth: '260px' })
          .setLngLat([r.loc.lng, r.loc.lat])
          .setHTML(`
            <div style="font-family: var(--system-font);">
              <div style="display:flex;align-items:center;gap:6px;margin-bottom:6px;">
                <span style="width:8px;height:8px;border-radius:50%;background:${color};display:inline-block;"></span>
                <strong style="font-size:12px;color:var(--text-primary);">${label}</strong>
                <span style="margin-left:auto;font-size:10px;color:var(--text-tertiary);">U${urgency}</span>
              </div>
              <div style="font-size:11px;color:var(--text-secondary);line-height:1.4;margin-bottom:6px;">${desc}</div>
              <div style="display:flex;justify-content:space-between;font-size:10px;color:var(--text-tertiary);">
                <span>${tsStr}</span>
                <span>${hops} hops</span>
              </div>
            </div>
          `)
          .addTo(map);
      });

      const marker = new mapboxgl.Marker({ element: el })
        .setLngLat([r.loc.lng, r.loc.lat])
        .addTo(map);

      markersRef.current.push(marker);
    });
  }

  // Initialize map
  useEffect(() => {
    if (mapRef.current || !containerRef.current) return;

    const isDark = theme === 'dark';
    const map = new mapboxgl.Map({
      container: containerRef.current,
      style: MAP_STYLES[theme],
      center: [-98, 39],
      zoom: 4,
      pitch: 45,
      bearing: -15,
      antialias: true,
      projection: 'globe',
      attributionControl: false,
    });

    map.addControl(new mapboxgl.NavigationControl({ visualizePitch: true }), 'top-right');

    map.on('load', () => {
      add3DLayers(map, isDark);
      addBuildingHover(map, isDark);
      addClusterLayers(map, reportsToGeoJSON(reportsRef.current));
      stripPOIs(map);
      syncMarkers(map, reportsRef.current);
    });

    // Click on cluster to zoom
    map.on('click', 'clusters', (e) => {
      const features = map.queryRenderedFeatures(e.point, { layers: ['clusters'] });
      if (!features.length) return;
      const clusterId = features[0].properties.cluster_id;
      map.getSource('reports').getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err) return;
        map.easeTo({ center: features[0].geometry.coordinates, zoom });
      });
    });

    map.on('mouseenter', 'clusters', () => { map.getCanvas().style.cursor = 'pointer'; });
    map.on('mouseleave', 'clusters', () => { map.getCanvas().style.cursor = ''; });

    mapRef.current = map;

    return () => {
      markersRef.current.forEach((m) => m.remove());
      map.remove();
      mapRef.current = null;
      sourceReady.current = false;
    };
  }, []);

  // Switch map style when theme changes
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const isDark = theme === 'dark';
    const newStyle = MAP_STYLES[theme];

    const center = map.getCenter();
    const zoom = map.getZoom();
    const pitch = map.getPitch();
    const bearing = map.getBearing();

    map.setStyle(newStyle);

    map.once('style.load', () => {
      map.setCenter(center);
      map.setZoom(zoom);
      map.setPitch(pitch);
      map.setBearing(bearing);

      add3DLayers(map, isDark);
      addBuildingHover(map, isDark);
      addClusterLayers(map, reportsToGeoJSON(reportsRef.current));
      stripPOIs(map);
      syncMarkers(map, reportsRef.current);
    });
  }, [theme]);

  // Update data when reports change + auto-fly on first load
  const hasFitted = useRef(false);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (sourceReady.current) {
      const source = map.getSource('reports');
      if (source) source.setData(reportsToGeoJSON(reports));
    }
    syncMarkers(map, reports);

    // Auto-fly to incidents on first data load
    if (!hasFitted.current && reports.length > 0) {
      hasFitted.current = true;

      const withCoords = reports.filter((r) => r.loc?.lat != null && r.loc?.lng != null);
      if (withCoords.length === 1) {
        // Single incident — fly directly to it
        const r = withCoords[0];
        map.flyTo({
          center: [r.loc.lng, r.loc.lat],
          zoom: 15,
          pitch: 55,
          bearing: -20,
          duration: 2500,
          essential: true,
        });
      } else if (withCoords.length > 1) {
        // Multiple incidents — fit bounds
        const bounds = new mapboxgl.LngLatBounds();
        withCoords.forEach((r) => bounds.extend([r.loc.lng, r.loc.lat]));
        map.fitBounds(bounds, {
          padding: { top: 80, bottom: 80, left: 80, right: 400 },
          pitch: 45,
          duration: 2500,
          maxZoom: 14,
        });
      }
    }
  }, [reports]);

  return (
    <div style={styles.wrapper}>
      <div ref={containerRef} style={styles.map} />
    </div>
  );
}
