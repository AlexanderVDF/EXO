import { useEffect, useRef, useState } from 'react';
import TopBar from '../components/TopBar';
import Card from '../components/Card';
import Icon from '../components/Icon';

const DEFAULT_TOPOLOGY = {
  nodes: [
    { id: 'router', label: 'Routeur', type: 'router', status: 'online' },
    { id: 'switch1', label: 'Switch Principal', type: 'switch', status: 'online' },
    { id: 'ap1', label: 'AP Salon', type: 'ap', status: 'online' },
    { id: 'ap2', label: 'AP Bureau', type: 'ap', status: 'online' },
    { id: 'exo', label: 'EXO', type: 'server', status: 'online' },
    { id: 'pc1', label: 'PC Bureau', type: 'client', status: 'online' },
    { id: 'phone1', label: 'Téléphone', type: 'client', status: 'online' },
    { id: 'iot1', label: 'Capteur Temp', type: 'iot', status: 'online' },
  ],
  edges: [
    { from: 'router', to: 'switch1' },
    { from: 'switch1', to: 'ap1' },
    { from: 'switch1', to: 'ap2' },
    { from: 'switch1', to: 'exo' },
    { from: 'ap1', to: 'phone1' },
    { from: 'ap2', to: 'pc1' },
    { from: 'switch1', to: 'iot1' },
  ],
};

const NODE_COLORS = {
  router: '#6C5CE7',
  switch: '#00CEC9',
  ap: '#FFEAA7',
  server: '#FF6B6B',
  client: '#A5A5B5',
  iot: '#00B894',
};

const NODE_ICONS = {
  router: 'WifiHigh',
  switch: 'GitBranch',
  ap: 'Broadcast',
  server: 'Desktop',
  client: 'Laptop',
  iot: 'Thermometer',
};

export default function NetworkMap({ ws }) {
  const { state, networkTopology } = ws;
  const canvasRef = useRef(null);
  const [selected, setSelected] = useState(null);
  const nodesRef = useRef([]);
  const topology = networkTopology || DEFAULT_TOPOLOGY;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const W = canvas.parentElement.clientWidth;
    const H = canvas.parentElement.clientHeight;
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    canvas.style.width = W + 'px';
    canvas.style.height = H + 'px';
    ctx.scale(dpr, dpr);

    // Layout nodes in a circle
    const cx = W / 2;
    const cy = H / 2;
    const radius = Math.min(W, H) * 0.32;
    const nodes = topology.nodes.map((n, i) => {
      const angle = (i / topology.nodes.length) * Math.PI * 2 - Math.PI / 2;
      return { ...n, x: cx + Math.cos(angle) * radius, y: cy + Math.sin(angle) * radius };
    });
    nodesRef.current = nodes;

    let animId;
    const draw = (time) => {
      ctx.clearRect(0, 0, W, H);

      // Draw edges
      topology.edges.forEach(({ from, to }) => {
        const a = nodes.find((n) => n.id === from);
        const b = nodes.find((n) => n.id === to);
        if (!a || !b) return;
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.strokeStyle = '#2D2D35';
        ctx.lineWidth = 2;
        ctx.stroke();

        // Animated packet dot
        const progress = ((time / 3000) + nodes.indexOf(a) * 0.1) % 1;
        const px = a.x + (b.x - a.x) * progress;
        const py = a.y + (b.y - a.y) * progress;
        ctx.beginPath();
        ctx.arc(px, py, 2.5, 0, Math.PI * 2);
        ctx.fillStyle = '#6C5CE740';
        ctx.fill();
      });

      // Draw nodes
      nodes.forEach((n) => {
        const color = NODE_COLORS[n.type] || '#A5A5B5';
        const isSelected = selected === n.id;
        const nodeRadius = isSelected ? 24 : 20;

        // Glow
        if (isSelected) {
          ctx.beginPath();
          ctx.arc(n.x, n.y, nodeRadius + 8, 0, Math.PI * 2);
          ctx.fillStyle = color + '25';
          ctx.fill();
        }

        // Circle
        ctx.beginPath();
        ctx.arc(n.x, n.y, nodeRadius, 0, Math.PI * 2);
        ctx.fillStyle = '#1A1A1F';
        ctx.fill();
        ctx.strokeStyle = color;
        ctx.lineWidth = isSelected ? 2.5 : 1.5;
        ctx.stroke();

        // Status dot
        const statusColor = n.status === 'online' ? '#00B894' : '#FF6B6B';
        ctx.beginPath();
        ctx.arc(n.x + nodeRadius * 0.6, n.y - nodeRadius * 0.6, 4, 0, Math.PI * 2);
        ctx.fillStyle = statusColor;
        ctx.fill();

        // Label
        ctx.fillStyle = '#A5A5B5';
        ctx.font = '11px Inter, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(n.label, n.x, n.y + nodeRadius + 16);
      });

      animId = requestAnimationFrame(draw);
    };

    animId = requestAnimationFrame(draw);

    const handleClick = (e) => {
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const clickedNode = nodes.find(
        (n) => Math.hypot(n.x - mx, n.y - my) < 24
      );
      setSelected(clickedNode?.id || null);
    };
    canvas.addEventListener('click', handleClick);

    return () => {
      cancelAnimationFrame(animId);
      canvas.removeEventListener('click', handleClick);
    };
  }, [topology, selected]);

  const selectedNode = nodesRef.current.find((n) => n.id === selected);

  return (
    <div className="flex flex-col h-full">
      <TopBar title="Carte Réseau" state={state} />

      <div className="flex-1 overflow-hidden p-6 flex gap-4">
        {/* Graph */}
        <Card className="flex-1 relative overflow-hidden">
          <canvas ref={canvasRef} className="w-full h-full" />
        </Card>

        {/* Details panel */}
        <div className="w-64 space-y-4 animate-fade-in">
          <Card className="p-4">
            <h3 className="text-xs font-medium text-exo-muted uppercase tracking-wider mb-3">Topologie</h3>
            <div className="flex justify-between text-sm">
              <span className="text-exo-muted">Nœuds</span>
              <span className="font-medium">{topology.nodes.length}</span>
            </div>
            <div className="flex justify-between text-sm mt-1">
              <span className="text-exo-muted">Liens</span>
              <span className="font-medium">{topology.edges.length}</span>
            </div>
          </Card>

          {selectedNode && (
            <Card className="p-4 animate-scale-in" glow>
              <div className="flex items-center gap-3 mb-3">
                <div
                  className="w-10 h-10 rounded-xl flex items-center justify-center"
                  style={{ backgroundColor: NODE_COLORS[selectedNode.type] + '20' }}
                >
                  <Icon name={NODE_ICONS[selectedNode.type]} size={20} style={{ color: NODE_COLORS[selectedNode.type] }} />
                </div>
                <div>
                  <p className="text-sm font-medium">{selectedNode.label}</p>
                  <p className="text-xs text-exo-muted capitalize">{selectedNode.type}</p>
                </div>
              </div>
              <div className="flex items-center gap-2 text-xs">
                <span className={`w-2 h-2 rounded-full ${selectedNode.status === 'online' ? 'bg-green-400' : 'bg-red-400'}`} />
                <span className="text-exo-muted capitalize">{selectedNode.status}</span>
              </div>
            </Card>
          )}

          {/* Legend */}
          <Card className="p-4">
            <h3 className="text-xs font-medium text-exo-muted uppercase tracking-wider mb-3">Légende</h3>
            <div className="space-y-2">
              {Object.entries(NODE_COLORS).map(([type, color]) => (
                <div key={type} className="flex items-center gap-2.5">
                  <span className="w-3 h-3 rounded-full" style={{ backgroundColor: color }} />
                  <span className="text-xs text-exo-muted capitalize">{type}</span>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
