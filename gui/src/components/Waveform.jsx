import { useRef, useEffect } from 'react';
import colors from '../theme/colors';

const BAR_COUNT = 48;
const BAR_WIDTH = 3;
const GAP = 2;

export default function Waveform({ volume = 0, state = 'IDLE', width = 320, height = 64 }) {
  const canvasRef = useRef(null);
  const barsRef = useRef(new Array(BAR_COUNT).fill(0));

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.scale(dpr, dpr);

    let animId;
    const bars = barsRef.current;

    const draw = (time) => {
      ctx.clearRect(0, 0, width, height);

      const isActive = state === 'LISTENING' || state === 'RESPONDING';
      const center = height / 2;

      for (let i = 0; i < BAR_COUNT; i++) {
        // Target height based on volume + noise
        const noise = Math.sin(time / 200 + i * 0.5) * 0.3 + Math.sin(time / 130 + i * 1.2) * 0.2;
        const target = isActive
          ? Math.max(4, (volume * 0.8 + noise * 0.3) * height * 0.8)
          : 2 + Math.abs(Math.sin(time / 1500 + i * 0.3)) * 4;

        // Smooth interpolation
        bars[i] += (target - bars[i]) * 0.12;
        const h = Math.max(2, bars[i]);

        const x = i * (BAR_WIDTH + GAP);
        const y = center - h / 2;

        // Color gradient from center
        const distFromCenter = Math.abs(i - BAR_COUNT / 2) / (BAR_COUNT / 2);
        const alpha = isActive ? 0.5 + (1 - distFromCenter) * 0.5 : 0.2 + (1 - distFromCenter) * 0.15;
        const color = state === 'RESPONDING' ? colors.stateColors.RESPONDING : colors.accent;

        ctx.beginPath();
        ctx.roundRect(x, y, BAR_WIDTH, h, 1.5);
        ctx.fillStyle = color + Math.round(alpha * 255).toString(16).padStart(2, '0');
        ctx.fill();
      }

      animId = requestAnimationFrame(draw);
    };

    animId = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(animId);
  }, [volume, state, width, height]);

  return (
    <canvas
      ref={canvasRef}
      style={{ width, height }}
      className="opacity-90"
    />
  );
}
