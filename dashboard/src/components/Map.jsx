import { useEffect, useRef } from 'react';
import mapboxgl from 'mapbox-gl';
import {
  colorMatchExpression,
  radiusExpression,
  clusterPaint,
  clusterCountLayout,
  clusterCountPaint,
  getMarkerColor,
  TYPE_LABELS,
} from '../utils/mapStyles';
import Legend from './Legend';

mapboxgl.accessToken = import.meta.env.VITE_MAPBOX_TOKEN || '';

function reportsToGeoJSON(reports) {
  return {
    type: 'FeatureCollection',
    features: reports
      .filter((r) => r.latitude != null && r.longitude != null)
      .map((r) => ({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [r.longitude, r.latitude],
        },
        properties: {
          id: r.id || '',
          type: r.type?.toLowerCase() || 'other',
          description: r.description || '',
          urgency: r.urgency ?? 1,
          hop_count: r.hop_count ?? r.hops ?? 0,
          timestamp: r.timestamp || '',
        },
      })),
  };
}

const styles = {
  wrapper: {
    position: 'relative',
    width: '100%',
    height: '100%',
  },
  map: {
    width: '100%',
    height: '100%',
  },
};

export default function Map({ reports }) {
  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const sourceReady = useRef(false);

  // Initialize map
  useEffect(() => {
    if (mapRef.current || !containerRef.current) return;

    const map = new mapboxgl.Map({
      container: containerRef.current,
      style: 'mapbox://styles/mapbox/standard',
      center: [-98, 39],
      zoom: 4,
      attributionControl: false,
    });

    map.addControl(new mapboxgl.NavigationControl(), 'top-right');

    map.on('load', () => {
      // Add GeoJSON source with clustering
      map.addSource('reports', {
        type: 'geojson',
        data: reportsToGeoJSON([]),
        cluster: true,
        clusterMaxZoom: 14,
        clusterRadius: 50,
      });

      // Cluster circles
      map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'reports',
        filter: ['has', 'point_count'],
        paint: clusterPaint,
      });

      // Cluster count labels
      map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'reports',
        filter: ['has', 'point_count'],
        layout: clusterCountLayout,
        paint: clusterCountPaint,
      });

      // Individual report circles
      map.addLayer({
        id: 'unclustered-point',
        type: 'circle',
        source: 'reports',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-color': colorMatchExpression,
          'circle-radius': radiusExpression,
          'circle-stroke-width': 1.5,
          'circle-stroke-color': 'rgba(255,255,255,0.25)',
          'circle-opacity': 0.9,
        },
      });

      sourceReady.current = true;
    });

    // Click on cluster to zoom
    map.on('click', 'clusters', (e) => {
      const features = map.queryRenderedFeatures(e.point, { layers: ['clusters'] });
      if (!features.length) return;
      const clusterId = features[0].properties.cluster_id;
      map.getSource('reports').getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err) return;
        map.easeTo({
          center: features[0].geometry.coordinates,
          zoom: zoom,
        });
      });
    });

    // Click on point to show popup
    map.on('click', 'unclustered-point', (e) => {
      const feature = e.features[0];
      const coords = feature.geometry.coordinates.slice();
      const { type, description, urgency, hop_count, timestamp } = feature.properties;
      const color = getMarkerColor(type);
      const label = TYPE_LABELS[type] || type;

      // Ensure popup appears at the correct position when the map is zoomed out
      while (Math.abs(e.lngLat.lng - coords[0]) > 180) {
        coords[0] += e.lngLat.lng > coords[0] ? 360 : -360;
      }

      const timeStr = timestamp
        ? new Date(timestamp).toLocaleString()
        : 'Unknown';

      new mapboxgl.Popup({
        closeButton: true,
        closeOnClick: true,
        className: 'relaygo-popup',
        maxWidth: '280px',
      })
        .setLngLat(coords)
        .setHTML(`
          <div style="font-family: system-ui, sans-serif;">
            <div style="display:flex;align-items:center;gap:6px;margin-bottom:8px;">
              <span style="width:10px;height:10px;border-radius:50%;background:${color};display:inline-block;box-shadow:0 0 6px ${color}66;"></span>
              <strong style="font-size:13px;color:#fff;">${label}</strong>
              <span style="margin-left:auto;font-size:11px;padding:2px 7px;border-radius:4px;background:rgba(255,255,255,0.1);color:rgba(255,255,255,0.7);">
                Urgency ${urgency}
              </span>
            </div>
            <div style="font-size:12px;color:rgba(255,255,255,0.75);line-height:1.5;margin-bottom:8px;">${description}</div>
            <div style="display:flex;justify-content:space-between;font-size:10px;color:rgba(255,255,255,0.4);">
              <span>${timeStr}</span>
              <span>${hop_count} hops</span>
            </div>
          </div>
        `)
        .addTo(map);
    });

    // Cursor changes
    map.on('mouseenter', 'clusters', () => { map.getCanvas().style.cursor = 'pointer'; });
    map.on('mouseleave', 'clusters', () => { map.getCanvas().style.cursor = ''; });
    map.on('mouseenter', 'unclustered-point', () => { map.getCanvas().style.cursor = 'pointer'; });
    map.on('mouseleave', 'unclustered-point', () => { map.getCanvas().style.cursor = ''; });

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
      sourceReady.current = false;
    };
  }, []);

  // Update data when reports change
  useEffect(() => {
    if (!mapRef.current || !sourceReady.current) return;
    const source = mapRef.current.getSource('reports');
    if (source) {
      source.setData(reportsToGeoJSON(reports));
    }
  }, [reports]);

  return (
    <div style={styles.wrapper}>
      <div ref={containerRef} style={styles.map} />
      <Legend />
    </div>
  );
}
