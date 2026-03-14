import colors from '../theme/colors';

const STATE_CONFIG = {
  IDLE: { label: 'Veille', color: colors.stateColors.IDLE, pulse: false },
  LISTENING: { label: 'Écoute', color: colors.stateColors.LISTENING, pulse: true },
  PROCESSING: { label: 'Réflexion', color: colors.stateColors.PROCESSING, pulse: true },
  RESPONDING: { label: 'Réponse', color: colors.stateColors.RESPONDING, pulse: true },
};

export default function StateIndicator({ state = 'IDLE' }) {
  const config = STATE_CONFIG[state] || STATE_CONFIG.IDLE;

  return (
    <div className="flex items-center gap-2.5 px-3 py-1.5 rounded-full bg-exo-elevated/50">
      <span
        className={`w-2 h-2 rounded-full ${config.pulse ? 'animate-pulse' : ''}`}
        style={{ backgroundColor: config.color }}
      />
      <span className="text-xs font-medium tracking-wide" style={{ color: config.color }}>
        {config.label}
      </span>
    </div>
  );
}
