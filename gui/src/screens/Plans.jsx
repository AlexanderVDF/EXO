import { useState, useRef, useCallback, Suspense } from 'react';
import TopBar from '../components/TopBar';
import Card from '../components/Card';
import Icon from '../components/Icon';

// Lazy-loaded heavy components
import { Stage, Layer, Rect, Line, Text as KonvaText, Circle } from 'react-konva';
import { Canvas } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';

const GRID_SIZE = 20;
const TOOLS = [
  { id: 'wall', icon: 'Wall', label: 'Mur' },
  { id: 'door', icon: 'Door', label: 'Porte' },
  { id: 'window', icon: 'FrameCorners', label: 'Fenêtre' },
  { id: 'device', icon: 'Cpu', label: 'Appareil' },
];

function Extruded3DWall({ x1, y1, x2, y2 }) {
  const cx = (x1 + x2) / 200;
  const cy = 0.5;
  const cz = (y1 + y2) / 200;
  const dx = Math.abs(x2 - x1) / 100;
  const dz = Math.abs(y2 - y1) / 100;
  const sx = Math.max(dx, 0.1);
  const sz = Math.max(dz, 0.1);

  return (
    <mesh position={[cx, cy, cz]}>
      <boxGeometry args={[sx, 1, sz]} />
      <meshStandardMaterial color="#6C5CE7" opacity={0.85} transparent />
    </mesh>
  );
}

function Scene3D({ walls }) {
  return (
    <>
      <ambientLight intensity={0.5} />
      <directionalLight position={[5, 8, 5]} intensity={0.8} />
      <gridHelper args={[10, 20, '#2D2D35', '#1A1A1F']} />
      {walls.map((w, i) => (
        <Extruded3DWall key={i} {...w} />
      ))}
      <OrbitControls enableDamping dampingFactor={0.08} />
    </>
  );
}

export default function Plans({ ws }) {
  const { state, planUpdate } = ws;
  const [view, setView] = useState('2d');
  const [tool, setTool] = useState('wall');
  const [walls, setWalls] = useState([]);
  const [devices, setDevices] = useState([]);
  const drawingRef = useRef(null);
  const stageRef = useRef(null);

  const handleStageMouseDown = useCallback((e) => {
    const pos = e.target.getStage().getPointerPosition();
    const snapped = { x: Math.round(pos.x / GRID_SIZE) * GRID_SIZE, y: Math.round(pos.y / GRID_SIZE) * GRID_SIZE };

    if (tool === 'device') {
      setDevices((prev) => [...prev, { x: snapped.x, y: snapped.y, id: Date.now() }]);
      return;
    }

    if (!drawingRef.current) {
      drawingRef.current = snapped;
    } else {
      const start = drawingRef.current;
      setWalls((prev) => [...prev, { x1: start.x, y1: start.y, x2: snapped.x, y2: snapped.y, type: tool }]);
      drawingRef.current = null;
    }
  }, [tool]);

  const wallColor = { wall: '#6C5CE7', door: '#00CEC9', window: '#FFEAA7' };

  return (
    <div className="flex flex-col h-full">
      <TopBar title="Plans" state={state} />

      <div className="flex-1 overflow-hidden p-6 flex flex-col gap-4">
        {/* Toolbar */}
        <div className="flex items-center gap-3">
          {/* View toggle */}
          <div className="flex bg-exo-surface rounded-xl overflow-hidden">
            {['2d', '3d'].map((v) => (
              <button
                key={v}
                onClick={() => setView(v)}
                className={`px-4 py-2 text-xs font-medium uppercase transition-all duration-200 ${
                  view === v ? 'bg-exo-accent text-white' : 'text-exo-muted hover:text-exo-text'
                }`}
              >
                {v}
              </button>
            ))}
          </div>

          <div className="w-px h-6 bg-exo-elevated" />

          {/* Tools */}
          {TOOLS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTool(t.id)}
              className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-medium transition-all duration-200 ${
                tool === t.id
                  ? 'bg-exo-accent/15 text-exo-accent'
                  : 'text-exo-muted hover:text-exo-text hover:bg-exo-elevated/50'
              }`}
            >
              <Icon name={t.icon} size={16} />
              {t.label}
            </button>
          ))}

          <div className="flex-1" />

          <button
            onClick={() => { setWalls([]); setDevices([]); }}
            className="px-3 py-2 rounded-xl text-xs text-exo-muted hover:text-red-400 hover:bg-red-400/10 transition-all duration-200"
          >
            <Icon name="Trash" size={16} />
          </button>
        </div>

        {/* Canvas area */}
        <Card className="flex-1 overflow-hidden relative">
          {view === '2d' ? (
            <Stage
              ref={stageRef}
              width={800}
              height={500}
              onMouseDown={handleStageMouseDown}
              style={{ background: '#0E0E11', cursor: 'crosshair' }}
            >
              <Layer>
                {/* Grid */}
                {Array.from({ length: 41 }).map((_, i) => (
                  <Line
                    key={`gv${i}`}
                    points={[i * GRID_SIZE, 0, i * GRID_SIZE, 500]}
                    stroke="#1A1A1F"
                    strokeWidth={0.5}
                  />
                ))}
                {Array.from({ length: 26 }).map((_, i) => (
                  <Line
                    key={`gh${i}`}
                    points={[0, i * GRID_SIZE, 800, i * GRID_SIZE]}
                    stroke="#1A1A1F"
                    strokeWidth={0.5}
                  />
                ))}

                {/* Walls */}
                {walls.map((w, i) => (
                  <Line
                    key={i}
                    points={[w.x1, w.y1, w.x2, w.y2]}
                    stroke={wallColor[w.type] || '#6C5CE7'}
                    strokeWidth={w.type === 'wall' ? 4 : 2}
                    dash={w.type === 'door' ? [8, 4] : w.type === 'window' ? [4, 4] : undefined}
                    lineCap="round"
                  />
                ))}

                {/* Devices */}
                {devices.map((d) => (
                  <Circle
                    key={d.id}
                    x={d.x}
                    y={d.y}
                    radius={8}
                    fill="#00CEC9"
                    draggable
                    onDragEnd={(e) => {
                      const x = Math.round(e.target.x() / GRID_SIZE) * GRID_SIZE;
                      const y = Math.round(e.target.y() / GRID_SIZE) * GRID_SIZE;
                      setDevices((prev) => prev.map((dev) => dev.id === d.id ? { ...dev, x, y } : dev));
                    }}
                  />
                ))}
              </Layer>
            </Stage>
          ) : (
            <div className="w-full h-full min-h-[500px]">
              <Suspense fallback={<div className="flex items-center justify-center h-full text-exo-muted">Chargement 3D...</div>}>
                <Canvas camera={{ position: [5, 5, 5], fov: 50 }}>
                  <Scene3D walls={walls} />
                </Canvas>
              </Suspense>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
