import StateIndicator from './StateIndicator';

export default function TopBar({ title, state }) {
  return (
    <header className="flex items-center justify-between px-6 py-4 border-b border-exo-elevated/30">
      <h1 className="text-lg font-semibold tracking-tight text-exo-text">{title}</h1>
      <StateIndicator state={state} />
    </header>
  );
}
