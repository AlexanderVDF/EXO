import * as PhosphorIcons from '@phosphor-icons/react';

export default function Icon({ name, size = 24, weight = 'regular', className = '', ...props }) {
  const IconComponent = PhosphorIcons[name];
  if (!IconComponent) return null;
  return <IconComponent size={size} weight={weight} className={className} {...props} />;
}
