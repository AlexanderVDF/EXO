import { useState, useEffect, useRef, useCallback } from 'react';

const WS_URL = 'ws://localhost:8765';
const RECONNECT_DELAY = 3000;
const MAX_RECONNECT = 10;

export default function useWebSocket() {
  const [state, setState] = useState('IDLE');
  const [volume, setVolume] = useState(0);
  const [text, setText] = useState('');
  const [messages, setMessages] = useState([]);
  const [deviceUpdate, setDeviceUpdate] = useState(null);
  const [networkTopology, setNetworkTopology] = useState(null);
  const [planUpdate, setPlanUpdate] = useState(null);
  const [connected, setConnected] = useState(false);

  const wsRef = useRef(null);
  const reconnectCount = useRef(0);
  const reconnectTimer = useRef(null);

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;

    ws.onopen = () => {
      setConnected(true);
      reconnectCount.current = 0;
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);

        if (data.state) setState(data.state);
        if (data.volume !== undefined) setVolume(data.volume);
        if (data.text) {
          setText(data.text);
          setMessages((prev) => [...prev.slice(-49), { text: data.text, state: data.state, ts: Date.now() }]);
        }
        if (data.device_update) setDeviceUpdate(data.device_update);
        if (data.network_topology) setNetworkTopology(data.network_topology);
        if (data.plan_update) setPlanUpdate(data.plan_update);
      } catch {
        // ignore malformed messages
      }
    };

    ws.onclose = () => {
      setConnected(false);
      wsRef.current = null;
      if (reconnectCount.current < MAX_RECONNECT) {
        reconnectCount.current++;
        reconnectTimer.current = setTimeout(connect, RECONNECT_DELAY);
      }
    };

    ws.onerror = () => {
      ws.close();
    };
  }, []);

  useEffect(() => {
    connect();
    return () => {
      clearTimeout(reconnectTimer.current);
      wsRef.current?.close();
    };
  }, [connect]);

  const send = useCallback((data) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(data));
    }
  }, []);

  return {
    state,
    volume,
    text,
    messages,
    deviceUpdate,
    networkTopology,
    planUpdate,
    connected,
    send,
  };
}
