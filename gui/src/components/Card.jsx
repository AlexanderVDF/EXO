export default function Card({ children, className = '', hover = false, glow = false, ...props }) {
  return (
    <div
      className={`
        bg-exo-surface rounded-card shadow-card
        ${hover ? 'hover:bg-exo-elevated hover:scale-[1.01] cursor-pointer' : ''}
        ${glow ? 'shadow-glow' : ''}
        transition-all duration-200 ease-out
        ${className}
      `}
      {...props}
    >
      {children}
    </div>
  );
}
