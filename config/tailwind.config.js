module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', '-apple-system', 'Segoe UI', 'Helvetica', 'Arial', 'sans-serif'],
        mono: ['JetBrains Mono', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'monospace']
      },
      colors: {
        ink: {
          900: '#0a0d14',
          800: '#0f131c',
          700: '#141925',
          600: '#1a2030',
          500: '#212940'
        },
        mist: {
          100: '#f1f3f8',
          200: '#d8dde8',
          300: '#9aa3b5',
          400: '#7a839a',
          500: '#5b6378',
          600: '#3d4458'
        }
      },
      boxShadow: {
        'glow-cyan':   '0 0 0 1px rgb(34 211 238 / 0.20), 0 8px 24px -8px rgb(34 211 238 / 0.30)',
        'glow-violet': '0 0 0 1px rgb(167 139 250 / 0.20), 0 8px 24px -8px rgb(167 139 250 / 0.30)',
        'glass':       '0 8px 32px -8px rgb(0 0 0 / 0.6), inset 0 1px 0 rgb(255 255 255 / 0.06)'
      },
      backgroundImage: {
        'gradient-cv': 'linear-gradient(135deg, #06b6d4 0%, #8b5cf6 100%)',
        'gradient-cv-soft': 'linear-gradient(135deg, rgba(6,182,212,0.16) 0%, rgba(139,92,246,0.16) 100%)'
      },
      animation: {
        'spin-slow': 'spin 1.2s linear infinite'
      }
    }
  },
  plugins: []
}
