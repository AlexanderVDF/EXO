import { useState } from 'react';
import TopBar from '../components/TopBar';
import Card from '../components/Card';
import Icon from '../components/Icon';

const SECTIONS = [
  { id: 'theme', icon: 'PaintBrush', label: 'Thème' },
  { id: 'voice', icon: 'Microphone', label: 'Voix' },
  { id: 'vad', icon: 'Waveform', label: 'Sensibilité VAD' },
  { id: 'network', icon: 'WifiHigh', label: 'Réseau' },
];

export default function Settings({ ws }) {
  const { state, send } = ws;
  const [activeSection, setActiveSection] = useState('theme');
  const [settings, setSettings] = useState({
    darkMode: true,
    accentColor: '#6C5CE7',
    voiceName: 'Microsoft Julie',
    voiceRate: 0.0,
    voicePitch: 0.0,
    voiceVolume: 0.8,
    vadSensitivity: 500,
    vadRecordingTime: 30,
    wsHost: 'localhost',
    wsPort: 8765,
  });

  const update = (key, value) => {
    setSettings((prev) => ({ ...prev, [key]: value }));
    send({ type: 'settings_update', key, value });
  };

  return (
    <div className="flex flex-col h-full">
      <TopBar title="Paramètres" state={state} />

      <div className="flex-1 overflow-hidden p-6 flex gap-6">
        {/* Section nav */}
        <div className="w-48 space-y-1">
          {SECTIONS.map((s) => (
            <button
              key={s.id}
              onClick={() => setActiveSection(s.id)}
              className={`w-full flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-sm transition-all duration-200 ${
                activeSection === s.id
                  ? 'bg-exo-accent/15 text-exo-accent'
                  : 'text-exo-muted hover:text-exo-text hover:bg-exo-elevated/50'
              }`}
            >
              <Icon name={s.icon} size={18} />
              {s.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto space-y-4">
          {activeSection === 'theme' && (
            <Card className="p-6 animate-fade-in">
              <h3 className="text-sm font-semibold mb-4">Apparence</h3>
              <div className="space-y-5">
                <ToggleSetting
                  label="Mode sombre"
                  description="Interface dark flat design"
                  value={settings.darkMode}
                  onChange={(v) => update('darkMode', v)}
                />
                <div>
                  <label className="text-xs text-exo-muted block mb-2">Couleur d'accent</label>
                  <div className="flex gap-2">
                    {['#6C5CE7', '#00CEC9', '#FF6B6B', '#00B894', '#FFEAA7', '#FD79A8'].map((c) => (
                      <button
                        key={c}
                        onClick={() => update('accentColor', c)}
                        className={`w-8 h-8 rounded-lg transition-all duration-200 ${
                          settings.accentColor === c ? 'ring-2 ring-white ring-offset-2 ring-offset-exo-bg scale-110' : 'hover:scale-105'
                        }`}
                        style={{ backgroundColor: c }}
                      />
                    ))}
                  </div>
                </div>
              </div>
            </Card>
          )}

          {activeSection === 'voice' && (
            <Card className="p-6 animate-fade-in">
              <h3 className="text-sm font-semibold mb-4">Paramètres vocaux</h3>
              <div className="space-y-5">
                <div>
                  <label className="text-xs text-exo-muted block mb-2">Voix TTS</label>
                  <select
                    value={settings.voiceName}
                    onChange={(e) => update('voiceName', e.target.value)}
                    className="w-full bg-exo-elevated rounded-xl px-3 py-2 text-sm text-exo-text border-none outline-none focus:ring-1 focus:ring-exo-accent"
                  >
                    <option>Microsoft Julie</option>
                    <option>Microsoft Hortense</option>
                    <option>Microsoft Paul</option>
                  </select>
                </div>
                <SliderSetting label="Débit" value={settings.voiceRate} min={-1} max={1} step={0.1} onChange={(v) => update('voiceRate', v)} />
                <SliderSetting label="Hauteur" value={settings.voicePitch} min={-1} max={1} step={0.1} onChange={(v) => update('voicePitch', v)} />
                <SliderSetting label="Volume" value={settings.voiceVolume} min={0} max={1} step={0.05} onChange={(v) => update('voiceVolume', v)} />
              </div>
            </Card>
          )}

          {activeSection === 'vad' && (
            <Card className="p-6 animate-fade-in">
              <h3 className="text-sm font-semibold mb-4">Détection vocale (VAD)</h3>
              <div className="space-y-5">
                <SliderSetting
                  label="Seuil d'énergie audio"
                  value={settings.vadSensitivity}
                  min={100}
                  max={2000}
                  step={50}
                  onChange={(v) => update('vadSensitivity', v)}
                />
                <SliderSetting
                  label="Durée d'enregistrement max (s)"
                  value={settings.vadRecordingTime}
                  min={5}
                  max={60}
                  step={5}
                  onChange={(v) => update('vadRecordingTime', v)}
                />
              </div>
            </Card>
          )}

          {activeSection === 'network' && (
            <Card className="p-6 animate-fade-in">
              <h3 className="text-sm font-semibold mb-4">Connexion réseau</h3>
              <div className="space-y-5">
                <TextSetting label="Hôte WebSocket" value={settings.wsHost} onChange={(v) => update('wsHost', v)} />
                <TextSetting label="Port WebSocket" value={settings.wsPort} onChange={(v) => update('wsPort', parseInt(v) || 8765)} />
              </div>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

function ToggleSetting({ label, description, value, onChange }) {
  return (
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm">{label}</p>
        {description && <p className="text-xs text-exo-muted mt-0.5">{description}</p>}
      </div>
      <button
        onClick={() => onChange(!value)}
        className={`w-10 h-5.5 rounded-full relative transition-all duration-200 ${
          value ? 'bg-exo-accent' : 'bg-exo-elevated'
        }`}
        style={{ width: 40, height: 22 }}
      >
        <span
          className="absolute top-0.5 w-4.5 h-4.5 rounded-full bg-white transition-all duration-200"
          style={{
            width: 18,
            height: 18,
            left: value ? 20 : 2,
          }}
        />
      </button>
    </div>
  );
}

function SliderSetting({ label, value, min, max, step, onChange }) {
  return (
    <div>
      <div className="flex justify-between items-center mb-2">
        <label className="text-xs text-exo-muted">{label}</label>
        <span className="text-xs font-medium tabular-nums">{value}</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
        className="w-full accent-exo-accent h-1"
      />
    </div>
  );
}

function TextSetting({ label, value, onChange }) {
  return (
    <div>
      <label className="text-xs text-exo-muted block mb-2">{label}</label>
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full bg-exo-elevated rounded-xl px-3 py-2 text-sm text-exo-text border-none outline-none focus:ring-1 focus:ring-exo-accent"
      />
    </div>
  );
}
