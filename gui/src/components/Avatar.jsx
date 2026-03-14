import { useRef, useEffect } from 'react';
import colors from '../theme/colors';

export default function Avatar({ state = 'IDLE', size = 160 }) {
  const canvasRef = useRef(null);
  const frameRef = useRef(0);
  const blinkRef = useRef({ timer: 0, blinking: false });

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    canvas.width = size * dpr;
    canvas.height = size * dpr;
    ctx.scale(dpr, dpr);

    let animId;
    const cx = size / 2;
    const cy = size / 2;
    const baseRadius = size * 0.32;

    const draw = (time) => {
      frameRef.current++;
      ctx.clearRect(0, 0, size, size);

      // Breathing animation
      const breathe = 1 + Math.sin(time / 1000) * 0.02;
      const r = baseRadius * breathe;

      // Outer glow ring
      const stateColor = colors.stateColors[state] || colors.stateColors.IDLE;
      const glowAlpha = state === 'IDLE' ? 0.1 : 0.2 + Math.sin(time / 500) * 0.1;
      ctx.beginPath();
      ctx.arc(cx, cy, r + 12, 0, Math.PI * 2);
      ctx.fillStyle = stateColor + Math.round(glowAlpha * 255).toString(16).padStart(2, '0');
      ctx.fill();

      // Main circle
      const gradient = ctx.createRadialGradient(cx, cy - r * 0.3, 0, cx, cy, r);
      gradient.addColorStop(0, '#3D3D4A');
      gradient.addColorStop(1, '#1A1A1F');
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.fillStyle = gradient;
      ctx.fill();

      // Accent ring
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.strokeStyle = stateColor;
      ctx.lineWidth = 2;
      ctx.stroke();

      // Eyes
      const eyeSpacing = r * 0.35;
      const eyeY = cy - r * 0.08;
      const eyeRadius = r * 0.08;

      // Blink logic
      blinkRef.current.timer++;
      if (blinkRef.current.timer > 180 && !blinkRef.current.blinking) {
        blinkRef.current.blinking = true;
        blinkRef.current.timer = 0;
      }
      if (blinkRef.current.blinking && blinkRef.current.timer > 8) {
        blinkRef.current.blinking = false;
        blinkRef.current.timer = 0;
      }

      const eyeScale = blinkRef.current.blinking ? 0.15 : 1;

      // Left eye
      ctx.beginPath();
      ctx.ellipse(cx - eyeSpacing, eyeY, eyeRadius, eyeRadius * eyeScale, 0, 0, Math.PI * 2);
      ctx.fillStyle = stateColor;
      ctx.fill();

      // Right eye
      ctx.beginPath();
      ctx.ellipse(cx + eyeSpacing, eyeY, eyeRadius, eyeRadius * eyeScale, 0, 0, Math.PI * 2);
      ctx.fillStyle = stateColor;
      ctx.fill();

      // State-specific animations
      if (state === 'LISTENING') {
        // Subtle ear-wave arcs
        const waveAlpha = 0.3 + Math.sin(time / 300) * 0.2;
        for (let i = 1; i <= 3; i++) {
          ctx.beginPath();
          ctx.arc(cx, cy, r + 18 + i * 10, -0.5, 0.5);
          ctx.strokeStyle = stateColor + Math.round(waveAlpha / i * 255).toString(16).padStart(2, '0');
          ctx.lineWidth = 1.5;
          ctx.stroke();
        }
      }

      if (state === 'PROCESSING') {
        // Rotating dots around the face
        const dotCount = 6;
        for (let i = 0; i < dotCount; i++) {
          const angle = (time / 800) + (i / dotCount) * Math.PI * 2;
          const dx = cx + Math.cos(angle) * (r + 18);
          const dy = cy + Math.sin(angle) * (r + 18);
          ctx.beginPath();
          ctx.arc(dx, dy, 2.5, 0, Math.PI * 2);
          ctx.fillStyle = stateColor;
          ctx.globalAlpha = 0.3 + (i / dotCount) * 0.7;
          ctx.fill();
          ctx.globalAlpha = 1;
        }
      }

      if (state === 'RESPONDING') {
        // Mouth speaking animation
        const mouthOpen = Math.abs(Math.sin(time / 200)) * r * 0.12;
        ctx.beginPath();
        ctx.ellipse(cx, cy + r * 0.25, r * 0.15, mouthOpen, 0, 0, Math.PI * 2);
        ctx.fillStyle = stateColor + '80';
        ctx.fill();
      }

      animId = requestAnimationFrame(draw);
    };

    animId = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(animId);
  }, [state, size]);

  return (
    <canvas
      ref={canvasRef}
      style={{ width: size, height: size }}
      className="transition-transform duration-300"
    />
  );
}
