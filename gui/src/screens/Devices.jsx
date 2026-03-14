import { useState } from 'react';
import TopBar from '../components/TopBar';
import Card from '../components/Card';
import Icon from '../components/Icon';

const DEMO_DEVICES = [
  { id: 1, name: 'EXO Hub', type: 'server', tech: 'Wi-Fi', status: 'online', ip: '192.168.1.10', integrations: ['Claude AI', 'TTS'] },
  { id: 2, name: 'Capteur Température Salon', type: 'sensor', tech: 'Zigbee', status: 'online', ip: '-', integrations: ['MQTT'] },
  { id: 3, name: 'Lumière Bureau', type: 'light', tech: 'Wi-Fi', status: 'online', ip: '192.168.1.42', integrations: ['Tuya'] },
  { id: 4, name: 'Prise Connectée Cuisine', type: 'plug', tech: 'Zigbee', status: 'offline', ip: '-', integrations: ['Zigbee2MQTT'] },
  { id: 5, name: 'Caméra Entrée', type: 'camera', tech: 'Wi-Fi', status: 'online', ip: '192.168.1.55', integrations: ['RTSP'] },
  { id: 6, name: 'Thermostat Salon', type: 'thermostat', tech: 'Z-Wave', status: 'online', ip: '-', integrations: ['Z-Wave JS'] },
];

const DEVICE_ICONS = {
  server: 'Desktop',
  sensor: 'Thermometer',
  light: 'Lamp',
  plug: 'Plug',
  camera: 'VideoCamera',
  thermostat: 'ThermometerHot',
};

const DEVICE_COLORS = {
  server: '#6C5CE7',
  sensor: '#00CEC9',
  light: '#FFEAA7',
  plug: '#00B894',
  camera: '#FF6B6B',
  thermostat: '#FD79A8',
};

export default function Devices({ ws }) {
  const { state, deviceUpdate } = ws;
  const [selectedId, setSelectedId] = useState(null);
  const [filter, setFilter] = useState('all');

  const devices = DEMO_DEVICES.map((d) => {
    if (deviceUpdate?.id === d.id) return { ...d, ...deviceUpdate };
    return d;
  });

  const filtered = filter === 'all' ? devices : devices.filter((d) => d.status === filter);
  const selected = devices.find((d) => d.id === selectedId);

  return (
    <div className="flex flex-col h-full">
      <TopBar title="Appareils" state={state} />

      <div className="flex-1 overflow-hidden p-6 flex gap-4">
        {/* Device list */}
        <div className="flex-1 flex flex-col gap-4">
          {/* Filters */}
          <div className="flex items-center gap-2">
            {['all', 'online', 'offline'].map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1.5 rounded-xl text-xs font-medium transition-all duration-200 ${
                  filter === f
                    ? 'bg-exo-accent/15 text-exo-accent'
                    : 'text-exo-muted hover:text-exo-text hover:bg-exo-elevated/50'
                }`}
              >
                {f === 'all' ? 'Tous' : f === 'online' ? 'En ligne' : 'Hors ligne'}
                <span className="ml-1.5 text-[10px] opacity-60">
                  {f === 'all' ? devices.length : devices.filter((d) => d.status === f).length}
                </span>
              </button>
            ))}
          </div>

          {/* Device cards */}
          <div className="grid grid-cols-2 gap-3 overflow-y-auto flex-1 pr-1">
            {filtered.map((device) => {
              const color = DEVICE_COLORS[device.type] || '#A5A5B5';
              return (
                <Card
                  key={device.id}
                  className={`p-4 cursor-pointer transition-all duration-200 ${
                    selectedId === device.id ? 'ring-1 ring-exo-accent/40' : ''
                  }`}
                  hover
                  onClick={() => setSelectedId(device.id)}
                >
                  <div className="flex items-start gap-3">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                      style={{ backgroundColor: color + '18' }}
                    >
                      <Icon name={DEVICE_ICONS[device.type] || 'Cpu'} size={20} style={{ color }} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">{device.name}</p>
                      <p className="text-xs text-exo-muted mt-0.5">{device.tech}</p>
                    </div>
                    <span
                      className={`w-2 h-2 rounded-full mt-1.5 shrink-0 ${
                        device.status === 'online' ? 'bg-green-400' : 'bg-red-400'
                      }`}
                    />
                  </div>
                </Card>
              );
            })}
          </div>
        </div>

        {/* Detail panel */}
        <div className="w-72 space-y-4">
          {selected ? (
            <Card className="p-5 animate-scale-in" glow>
              <div className="flex items-center gap-3 mb-4">
                <div
                  className="w-12 h-12 rounded-xl flex items-center justify-center"
                  style={{ backgroundColor: (DEVICE_COLORS[selected.type] || '#A5A5B5') + '20' }}
                >
                  <Icon
                    name={DEVICE_ICONS[selected.type] || 'Cpu'}
                    size={24}
                    style={{ color: DEVICE_COLORS[selected.type] }}
                  />
                </div>
                <div>
                  <p className="font-medium">{selected.name}</p>
                  <div className="flex items-center gap-1.5 mt-0.5">
                    <span
                      className={`w-2 h-2 rounded-full ${
                        selected.status === 'online' ? 'bg-green-400' : 'bg-red-400'
                      }`}
                    />
                    <span className="text-xs text-exo-muted capitalize">{selected.status}</span>
                  </div>
                </div>
              </div>

              <div className="space-y-3">
                <Detail label="Type" value={selected.type} />
                <Detail label="Technologie" value={selected.tech} />
                <Detail label="Adresse IP" value={selected.ip} />
                <div>
                  <span className="text-xs text-exo-muted">Intégrations</span>
                  <div className="flex flex-wrap gap-1.5 mt-1">
                    {selected.integrations.map((integ) => (
                      <span
                        key={integ}
                        className="px-2 py-0.5 rounded-md bg-exo-elevated text-[10px] text-exo-muted"
                      >
                        {integ}
                      </span>
                    ))}
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex gap-2 mt-5">
                <button className="flex-1 py-2 rounded-xl bg-exo-accent/15 text-exo-accent text-xs font-medium hover:bg-exo-accent/25 transition-all duration-200">
                  Configurer
                </button>
                <button className="flex-1 py-2 rounded-xl bg-exo-elevated text-exo-muted text-xs font-medium hover:text-exo-text transition-all duration-200">
                  Redémarrer
                </button>
              </div>
            </Card>
          ) : (
            <Card className="p-5 text-center">
              <Icon name="CursorClick" size={32} className="text-exo-muted mx-auto mb-2" />
              <p className="text-sm text-exo-muted">Sélectionnez un appareil</p>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

function Detail({ label, value }) {
  return (
    <div className="flex justify-between items-center">
      <span className="text-xs text-exo-muted">{label}</span>
      <span className="text-xs font-medium capitalize">{value}</span>
    </div>
  );
}
