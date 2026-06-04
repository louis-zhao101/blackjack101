import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        felt: {
          DEFAULT: '#1a4731',
          dark: '#122e20',
          light: '#245f40',
          border: '#2d7a53',
        },
        card: {
          bg: '#fffef9',
          border: '#d1c4a8',
          red: '#c0392b',
          black: '#1a1a1a',
        },
        chip: {
          red: '#e74c3c',
          green: '#27ae60',
          blue: '#2980b9',
          black: '#2c2c2c',
        },
        gold: {
          DEFAULT: '#d4a843',
          light: '#f0c84a',
          dark: '#b8862a',
        },
      },
      fontFamily: {
        display: ['"Playfair Display"', 'Georgia', 'serif'],
        mono: ['"JetBrains Mono"', 'monospace'],
      },
      boxShadow: {
        card: '0 2px 8px rgba(0,0,0,0.35), 0 1px 2px rgba(0,0,0,0.2)',
        'card-hover': '0 4px 16px rgba(0,0,0,0.45)',
        chip: '0 3px 8px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.15)',
        table: 'inset 0 0 60px rgba(0,0,0,0.4)',
      },
      keyframes: {
        dealIn: {
          '0%': { transform: 'translateY(-40px) rotate(-5deg)', opacity: '0' },
          '100%': { transform: 'translateY(0) rotate(0deg)', opacity: '1' },
        },
        flipCard: {
          '0%': { transform: 'rotateY(90deg)' },
          '100%': { transform: 'rotateY(0deg)' },
        },
        slideUp: {
          '0%': { transform: 'translateY(100%)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        pulse: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.5' },
        },
      },
      animation: {
        'deal-in': 'dealIn 0.3s ease-out forwards',
        'flip-card': 'flipCard 0.25s ease-out forwards',
        'slide-up': 'slideUp 0.35s ease-out forwards',
        'fade-in': 'fadeIn 0.2s ease-out forwards',
      },
    },
  },
  plugins: [],
} satisfies Config;
