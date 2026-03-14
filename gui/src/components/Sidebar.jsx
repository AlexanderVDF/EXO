import { NavLink } from 'react-router-dom';
import Icon from './Icon';

const NAV_ITEMS = [
  { path: '/', icon: 'House', label: 'Accueil' },
  { path: '/plans', icon: 'Blueprint', label: 'Plans' },
  { path: '/network', icon: 'GraphStruct', label: 'Réseau' },
  { path: '/devices', icon: 'Devices', label: 'Appareils' },
  { path: '/settings', icon: 'GearSix', label: 'Paramètres' },
];

export default function Sidebar() {
  return (
    <aside className="fixed left-0 top-0 h-screen w-[72px] bg-exo-surface flex flex-col items-center py-6 gap-2 z-50 border-r border-exo-elevated/40">
      {/* Logo */}
      <div className="w-10 h-10 rounded-xl bg-exo-accent flex items-center justify-center mb-6 shadow-glow">
        <span className="text-white font-bold text-sm">EXO</span>
      </div>

      {/* Nav items */}
      <nav className="flex flex-col gap-1 flex-1">
        {NAV_ITEMS.map(({ path, icon, label }) => (
          <NavLink
            key={path}
            to={path}
            end={path === '/'}
            className={({ isActive }) =>
              `group relative flex items-center justify-center w-11 h-11 rounded-xl transition-all duration-200 ease-out
              ${isActive
                ? 'bg-exo-accent/15 text-exo-accent shadow-glow'
                : 'text-exo-muted hover:text-exo-text hover:bg-exo-elevated/50'
              }`
            }
          >
            <Icon name={icon} size={22} weight="regular" />
            {/* Tooltip */}
            <span className="absolute left-full ml-3 px-2.5 py-1 rounded-lg bg-exo-elevated text-xs text-exo-text whitespace-nowrap opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity duration-150 shadow-card">
              {label}
            </span>
          </NavLink>
        ))}
      </nav>

      {/* Status dot */}
      <div className="w-2.5 h-2.5 rounded-full bg-exo-secondary animate-pulse mb-2" />
    </aside>
  );
}
