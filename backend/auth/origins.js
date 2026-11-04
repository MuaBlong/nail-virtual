function allowedOrigin(origin) {
  if (!origin) return true; // native app / command-line clients
  const configured = (process.env.CORS_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
  if (configured.includes(origin)) return true;
  if (process.env.NODE_ENV === 'production') return false;
  try {
    const url = new URL(origin);
    return ['http:','https:'].includes(url.protocol) && ['localhost','127.0.0.1','[::1]'].includes(url.hostname);
  } catch (_) { return false; }
}
module.exports = { allowedOrigin };
