import { useState, useEffect, useRef, useCallback } from 'react';

const WS_URL = 'ws://localhost:8000/ws/dashboard';
const REPORTS_URL = 'http://localhost:8000/api/reports';
const DIRECTIVES_URL = 'http://localhost:8000/api/directives';
const SENSORS_URL = 'http://localhost:8000/api/sensors';
const RECONNECT_DELAY = 3000;

export default function useWebSocket() {
  const [reports, setReports] = useState([]);
  const [directives, setDirectives] = useState([]);
  const [sensors, setSensors] = useState(null);
  const [connected, setConnected] = useState(false);
  const wsRef = useRef(null);
  const reconnectTimer = useRef(null);

  const fetchInitialReports = useCallback(async () => {
    try {
      const res = await fetch(REPORTS_URL);
      if (res.ok) {
        const data = await res.json();
        setReports(Array.isArray(data) ? data : []);
      }
    } catch (err) {
      console.warn('Failed to fetch initial reports:', err);
    }
  }, []);

  const fetchDirectives = useCallback(async () => {
    try {
      const res = await fetch(DIRECTIVES_URL);
      if (res.ok) {
        const data = await res.json();
        setDirectives(Array.isArray(data) ? data : []);
      }
    } catch (err) {
      console.warn('Failed to fetch directives:', err);
    }
  }, []);

  const fetchSensors = useCallback(async () => {
    try {
      const res = await fetch(SENSORS_URL);
      if (res.ok) {
        const data = await res.json();
        setSensors(data);
      }
    } catch (err) {
      console.warn('Failed to fetch sensors:', err);
    }
  }, []);

  const connect = useCallback(() => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) return;

    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;

    ws.onopen = () => {
      setConnected(true);
      fetchInitialReports();
      fetchDirectives();
      fetchSensors();
    };

    ws.onmessage = (event) => {
      try {
        const raw = JSON.parse(event.data);
        const items = Array.isArray(raw) ? raw : [raw];

        for (const item of items) {
          // Handle sensor updates
          if (item.kind === 'sensors') {
            setSensors((prev) => {
              const next = prev ? { ...prev } : { kind: 'sensors' };
              if (item.feed && item.data) {
                next[item.feed] = item.data;
                if (!next.last_updated) next.last_updated = {};
                next.last_updated[item.feed] = item.ts;
              }
              return next;
            });
            continue;
          }
        }

        // Handle directives and reports as before
        const newDirectives = [];
        const newReports = [];
        for (const item of items) {
          if (item.kind === 'sensors') continue;
          if (item.kind === 'directive') {
            newDirectives.push(item);
          } else {
            newReports.push(item);
          }
        }
        if (newDirectives.length) {
          setDirectives((prev) => {
            const ids = new Set(prev.map((d) => d.id));
            const fresh = newDirectives.filter((d) => !ids.has(d.id));
            return fresh.length ? [...fresh, ...prev] : prev;
          });
        }
        if (newReports.length) {
          setReports((prev) => {
            const ids = new Set(prev.map((r) => r.id));
            const fresh = newReports.filter((r) => !ids.has(r.id));
            return fresh.length ? [...fresh, ...prev] : prev;
          });
        }
      } catch (err) {
        console.warn('Failed to parse WebSocket message:', err);
      }
    };

    ws.onclose = () => {
      setConnected(false);
      wsRef.current = null;
      reconnectTimer.current = setTimeout(connect, RECONNECT_DELAY);
    };

    ws.onerror = () => {
      ws.close();
    };
  }, [fetchInitialReports, fetchDirectives, fetchSensors]);

  useEffect(() => {
    connect();

    return () => {
      clearTimeout(reconnectTimer.current);
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [connect]);

  return { reports, directives, sensors, connected, refetchDirectives: fetchDirectives };
}
