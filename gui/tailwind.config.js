/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        exo: {
          bg: '#0E0E11',
          surface: '#1A1A1F',
          elevated: '#2D2D35',
          accent: '#6C5CE7',
          secondary: '#00CEC9',
          text: '#FFFFFF',
          muted: '#A5A5B5',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        card: '14px',
      },
      boxShadow: {
        card: '0 4px 12px rgba(0,0,0,0.25)',
        glow: '0 0 20px rgba(108,92,231,0.35)',
        'glow-secondary': '0 0 20px rgba(0,206,201,0.35)',
      },
      animation: {
        'fade-in': 'fadeIn 0.25s ease-out',
        'scale-in': 'scaleIn 0.2s ease-out',
        'pulse-glow': 'pulseGlow 2s ease-in-out infinite',
        breathe: 'breathe 4s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.95)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
        pulseGlow: {
          '0%, 100%': { boxShadow: '0 0 15px rgba(108,92,231,0.3)' },
          '50%': { boxShadow: '0 0 30px rgba(108,92,231,0.6)' },
        },
        breathe: {
          '0%, 100%': { transform: 'scale(1)' },
          '50%': { transform: 'scale(1.03)' },
        },
      },
    },
  },
  plugins: [],
};
