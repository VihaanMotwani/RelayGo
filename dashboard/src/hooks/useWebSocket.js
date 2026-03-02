import { useState, useEffect, useRef, useCallback } from 'react';

const WS_URL = 'ws://localhost:8000/ws/dashboard';
const REPORTS_URL = 'http://localhost:8000/api/reports';
const DIRECTIVES_URL = 'http://localhost:8000/api/directives';
const RECONNECT_DELAY = 3000;

export default function useWebSocket() {
  const [reports, setReports] = useState([]);
  const [directives, setDirectives] = useState([]);
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

  const connect = useCallback(() => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) return;

    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;

    ws.onopen = () => {
      setConnected(true);
      fetchInitialReports();
      fetchDirectives();
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.kind === 'directive') {
          setDirectives((prev) => [data, ...prev]);
        } else {
          setReports((prev) => [data, ...prev]);
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
  }, [fetchInitialReports, fetchDirectives]);

  useEffect(() => {
    connect();

    return () => {
      clearTimeout(reconnectTimer.current);
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [connect]);

  return { reports, directives, connected, refetchDirectives: fetchDirectives };
}
