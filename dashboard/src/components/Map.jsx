import { useEffect, useRef, useCallback } from 'react';
import mapboxgl from 'mapbox-gl';
import {
  getMarkerColor,
  colorMatchExpression,
  TYPE_LABELS,
  TYPE_CODES,
} from '../utils/mapStyles';
import { useTheme } from '../hooks/useTheme';

mapboxgl.accessToken = import.meta.env.VITE_MAPBOX_TOKEN || '';

const MAP_STYLES = {
  light: 'mapbox://styles/mapbox/streets-v12',
  dark: 'mapbox://styles/mapbox/dark-v11',
};

/* ---- GeoJSON generators ---- */

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

/* ---- Styles ---- */

const styles = {
  wrapper: { position: 'relative', width: '100%', height: '100%' },
  map: { width: '100%', height: '100%' },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: '100%',
    height: '100%',
    pointerEvents: 'none',
  },
};

/* ---- Dispatch-style pin (text codes, no emojis) ---- */

function createPinEl(color, code, urgency) {
  const el = document.createElement('div');
  el.className = 'incident-pin';

  const badge = document.createElement('div');
  badge.className = 'incident-pin-badge';
  badge.style.background = color;

  const codeSpan = document.createElement('span');
  codeSpan.className = 'incident-pin-code';
  codeSpan.textContent = code;

  const sep = document.createElement('span');
  sep.className = 'incident-pin-sep';

  const urgSpan = document.createElement('span');
  urgSpan.className = 'incident-pin-urg';
  urgSpan.textContent = urgency;

  badge.appendChild(codeSpan);
  badge.appendChild(sep);
  badge.appendChild(urgSpan);

  const tail = document.createElement('div');
  tail.className = 'incident-pin-tail';
  tail.style.borderTopColor = color;

  el.appendChild(badge);
  el.appendChild(tail);
  return el;
}

/* ---- Component ---- */

export default function Map({ reports }) {
  const containerRef = useRef(null);
  const canvasRef = useRef(null);
  const mapRef = useRef(null);
  const sourceReady = useRef(false);
  const reportsRef = useRef(reports);
  const markersRef = useRef([]);
  const { theme } = useTheme();

  reportsRef.current = reports;

  /* ---- Canvas relay arc rendering (draws OVER 3D buildings) ---- */
  /* Arcs are 3D-aware: points are sampled along the geographic path,
     assigned parabolic altitude, and projected to screen with pitch offset
     so they rotate and tilt naturally with the map camera. */

  const drawRelayOverlay = useCallback((map, rpts) => {
    const canvas = canvasRef.current;
    if (!canvas || !map) return;

    const rect = canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const w = rect.width;
    const h = rect.height;

    if (canvas.width !== w * dpr || canvas.height !== h * dpr) {
      canvas.width = w * dpr;
      canvas.height = h * dpr;
    }

    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const pitchRad = map.getPitch() * Math.PI / 180;
    const zoom = map.getZoom();
    const allNodes = [];

    for (const r of rpts) {
      const path = r.relay_path;
      if (!Array.isArray(path) || path.length < 2) continue;

      const geoNodes = path.filter((p) => p.lat != null && p.lng != null);
      for (const p of geoNodes) allNodes.push(map.project([p.lng, p.lat]));
      if (geoNodes.length < 2) continue;

      for (let i = 0; i < geoNodes.length - 1; i++) {
        const aGeo = geoNodes[i];
        const bGeo = geoNodes[i + 1];

        const a = map.project([aGeo.lng, aGeo.lat]);
        const b = map.project([bGeo.lng, bGeo.lat]);
        const screenDist = Math.sqrt((b.x - a.x) ** 2 + (b.y - a.y) ** 2);
        if (screenDist < 4 || screenDist > 3000) continue;

        // Haversine geographic distance (metres)
        const R = 6371000;
        const lat1 = aGeo.lat * Math.PI / 180;
        const lat2 = bGeo.lat * Math.PI / 180;
        const dLat = lat2 - lat1;
        const dLng = (bGeo.lng - aGeo.lng) * Math.PI / 180;
        const ha =
          Math.sin(dLat / 2) ** 2 +
          Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
        const geoDist = R * 2 * Math.atan2(Math.sqrt(ha), Math.sqrt(1 - ha));

        // Peak altitude of the parabolic arc (proportional to distance)
        const maxAlt = geoDist * 0.5;

        // Metres-per-pixel at the segment midpoint
        const midLat = (aGeo.lat + bGeo.lat) / 2;
        const metersPerPixel =
          (78271.484 * Math.cos(midLat * Math.PI / 180)) / Math.pow(2, zoom);

        // Pitch factor — never fully flat so arcs stay visible at low pitch
        const pitchFactor = Math.max(Math.sin(pitchRad), 0.15);

        // Sample N points along the geographic path with parabolic altitude
        const N = 30;
        const screenPts = [];

        for (let s = 0; s <= N; s++) {
          const t = s / N;
          const lng = aGeo.lng + (bGeo.lng - aGeo.lng) * t;
          const lat = aGeo.lat + (bGeo.lat - aGeo.lat) * t;
          const alt = maxAlt * 4 * t * (1 - t); // parabola: 0 → maxAlt → 0

          const sp = map.project([lng, lat]);
          // Push the point upward on screen proportional to its altitude
          sp.y -= (alt / metersPerPixel) * pitchFactor;
          screenPts.push(sp);
        }

        // Glow pass
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(screenPts[0].x, screenPts[0].y);
        for (let s = 1; s < screenPts.length; s++) {
          ctx.lineTo(screenPts[s].x, screenPts[s].y);
        }
        ctx.strokeStyle = 'rgba(0, 217, 255, 0.10)';
        ctx.lineWidth = 12;
        ctx.shadowColor = 'rgba(0, 217, 255, 0.25)';
        ctx.shadowBlur = 18;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.stroke();
        ctx.restore();

        // Main arc
        ctx.beginPath();
        ctx.moveTo(screenPts[0].x, screenPts[0].y);
        for (let s = 1; s < screenPts.length; s++) {
          ctx.lineTo(screenPts[s].x, screenPts[s].y);
        }
        ctx.strokeStyle = 'rgba(0, 217, 255, 0.75)';
        ctx.lineWidth = 2.5;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.stroke();
      }
    }

    // Relay node dots — deduplicated by screen position
    const drawn = new Set();
    for (const pt of allNodes) {
      const key = `${Math.round(pt.x)},${Math.round(pt.y)}`;
      if (drawn.has(key)) continue;
      drawn.add(key);

      ctx.beginPath();
      ctx.arc(pt.x, pt.y, 4.5, 0, Math.PI * 2);
      ctx.fillStyle = '#FFD60A';
      ctx.fill();
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }, []);

  /* ---- Map helper functions ---- */

  function stripPOIs(map) {
    const style = map.getStyle();
    if (!style?.layers) return;
    style.layers.forEach((layer) => {
      if (layer.id.includes('poi')) {
        map.setLayoutProperty(layer.id, 'visibility', 'none');
      }
    });
  }

  // GeoJSON source + incident zone circles on the ground
  function addReportSource(map, data) {
    map.addSource('reports', { type: 'geojson', data });

    // Translucent zone circles — colored ground showing affected area
    map.addLayer({
      id: 'incident-zones',
      type: 'circle',
      source: 'reports',
      paint: {
        'circle-radius': [
          'interpolate', ['linear'], ['zoom'],
          8, 12,
          12, 50,
          15, 120,
          18, 280,
        ],
        'circle-color': colorMatchExpression,
        'circle-opacity': [
          'interpolate', ['linear'], ['get', 'urgency'],
          1, 0.06,
          3, 0.10,
          5, 0.18,
        ],
        'circle-blur': 0.8,
        'circle-pitch-alignment': 'map',
      },
    });

    sourceReady.current = true;
  }

  // 3D terrain, fog, buildings
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

  // Building hover highlight
  function addBuildingHover(map, isDark) {
    map.addLayer({
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
    });

    map.on('mousemove', '3d-buildings', (e) => {
      if (e.features.length > 0) {
        map.getCanvas().style.cursor = 'pointer';
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

  // Sync incident pin markers
  function syncMarkers(map, rpts) {
    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    rpts.forEach((r) => {
      if (r.loc?.lat == null || r.loc?.lng == null) return;

      const type = r.type?.toLowerCase() || 'other';
      const color = getMarkerColor(type);
      const code = TYPE_CODES[type] || TYPE_CODES.other;
      const urgency = r.urg ?? r.urgency ?? 1;
      const el = createPinEl(color, code, urgency);
      const label = TYPE_LABELS[type] || type;
      const desc = r.desc || r.description || '';
      const hops = r.hops ?? r.hop_count ?? 0;
      const ts = r.ts || r.timestamp;
      const tsStr = ts
        ? new Date(typeof ts === 'number' && ts < 1e12 ? ts * 1000 : ts).toLocaleString()
        : 'Unknown';

      // Mapbox measures HTML elements on addition, which can be wonky for unrendered flex items.
      // Wrap it in a 0-size container so it securely anchors at the bottom-center.
      const wrapper = document.createElement('div');
      wrapper.style.position = 'absolute';
      wrapper.style.pointerEvents = 'none';

      el.style.position = 'absolute';
      el.style.bottom = '0';
      el.style.left = '50%';
      el.style.transform = 'translate(-50%, 0)';
      el.style.pointerEvents = 'auto'; // Re-enable pointer events for the pin itself
      wrapper.appendChild(el);

      el.addEventListener('click', () => {
        new mapboxgl.Popup({ closeButton: true, closeOnClick: true, maxWidth: '260px' })
          .setLngLat([r.loc.lng, r.loc.lat])
          .setHTML(
            `<div style="font-family:var(--system-font);">
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
            </div>`
          )
          .addTo(map);
      });

      const marker = new mapboxgl.Marker({ element: wrapper })
        .setLngLat([r.loc.lng, r.loc.lat])
        .addTo(map);

      markersRef.current.push(marker);
    });
  }

  // All Mapbox sources and layers in one setup call
  function setupLayers(map, isDark, data) {
    addReportSource(map, data);
    add3DLayers(map, isDark);
    addBuildingHover(map, isDark);
    stripPOIs(map);
  }

  /* ---- Effects ---- */

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

    map.addControl(new mapboxgl.NavigationControl({ visualizePitch: true }), 'bottom-left');

    // Redraw canvas arcs on every camera change
    const redraw = () => drawRelayOverlay(map, reportsRef.current);
    map.on('move', redraw);
    map.on('resize', redraw);

    map.on('load', () => {
      setupLayers(map, isDark, reportsToGeoJSON(reportsRef.current));
      syncMarkers(map, reportsRef.current);
      redraw();
    });

    mapRef.current = map;

    return () => {
      map.off('move', redraw);
      map.off('resize', redraw);
      markersRef.current.forEach((m) => m.remove());
      map.remove();
      mapRef.current = null;
      sourceReady.current = false;
    };
  }, [drawRelayOverlay]);

  // Switch map style when theme changes
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const isDark = theme === 'dark';
    const center = map.getCenter();
    const zoom = map.getZoom();
    const pitch = map.getPitch();
    const bearing = map.getBearing();

    map.setStyle(MAP_STYLES[theme]);

    map.once('style.load', () => {
      map.setCenter(center);
      map.setZoom(zoom);
      map.setPitch(pitch);
      map.setBearing(bearing);

      sourceReady.current = false;
      setupLayers(map, isDark, reportsToGeoJSON(reportsRef.current));
      syncMarkers(map, reportsRef.current);
      drawRelayOverlay(map, reportsRef.current);
    });
  }, [theme, drawRelayOverlay]);

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
    drawRelayOverlay(map, reports);

    // Auto-fly to incidents on first data load
    if (!hasFitted.current && reports.length > 0) {
      hasFitted.current = true;

      const withCoords = reports.filter((r) => r.loc?.lat != null && r.loc?.lng != null);
      if (withCoords.length === 1) {
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
  }, [reports, drawRelayOverlay]);

  return (
    <div style={styles.wrapper}>
      <div ref={containerRef} style={styles.map} />
      <canvas ref={canvasRef} style={styles.overlay} />
    </div>
  );
}
