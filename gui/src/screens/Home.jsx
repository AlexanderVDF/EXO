import Avatar from '../components/Avatar';
import Waveform from '../components/Waveform';
import Card from '../components/Card';
import TopBar from '../components/TopBar';
import Icon from '../components/Icon';

export default function Home({ ws }) {
  const { state, volume, text, messages } = ws;

  return (
    <div className="flex flex-col h-full">
      <TopBar title="Accueil" state={state} />

      <div className="flex-1 overflow-y-auto p-6 space-y-6">
        {/* Hero section */}
        <div className="flex flex-col items-center gap-4 pt-4 animate-fade-in">
          <Avatar state={state} size={150} />
          <Waveform volume={volume} state={state} width={280} height={56} />
          <p className="text-exo-muted text-sm text-center max-w-md min-h-[1.5rem]">
            {text || 'EXO est en veille...'}
          </p>
        </div>

        {/* Stats cards */}
        <div className="grid grid-cols-3 gap-4 animate-fade-in">
          <Card className="p-4 flex flex-col items-center gap-2" hover>
            <Icon name="WaveformSlash" size={28} className="text-exo-accent" />
            <span className="text-xs text-exo-muted">Volume</span>
            <span className="text-lg font-semibold">{Math.round(volume * 100)}%</span>
          </Card>
          <Card className="p-4 flex flex-col items-center gap-2" hover>
            <Icon name="ChatsCircle" size={28} className="text-exo-secondary" />
            <span className="text-xs text-exo-muted">Messages</span>
            <span className="text-lg font-semibold">{messages.length}</span>
          </Card>
          <Card className="p-4 flex flex-col items-center gap-2" hover>
            <Icon name="Lightning" size={28} className="text-yellow-400" />
            <span className="text-xs text-exo-muted">État</span>
            <span className="text-sm font-medium capitalize">{state.toLowerCase()}</span>
          </Card>
        </div>

        {/* Message history */}
        <div className="animate-fade-in">
          <h2 className="text-sm font-medium text-exo-muted uppercase tracking-wider mb-3">
            Dernières interactions
          </h2>
          <div className="space-y-2 max-h-[320px] overflow-y-auto pr-1">
            {messages.length === 0 && (
              <Card className="p-4 text-center text-exo-muted text-sm">
                Aucune interaction pour le moment.
              </Card>
            )}
            {[...messages].reverse().map((msg, i) => (
              <Card key={i} className="p-3 flex items-start gap-3" hover>
                <Icon
                  name={msg.state === 'RESPONDING' ? 'Robot' : 'User'}
                  size={18}
                  className="text-exo-accent mt-0.5 shrink-0"
                />
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-exo-text leading-relaxed break-words">{msg.text}</p>
                  <span className="text-[10px] text-exo-muted mt-1 block">
                    {new Date(msg.ts).toLocaleTimeString('fr-FR')}
                  </span>
                </div>
              </Card>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
