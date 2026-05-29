const express = require('express');
const cookieParser = require('cookie-parser');
const path = require('path');
const fs = require('fs');
const waf = require('./middleware/waf');

const app = express();
const PORT = 3000;

// ─── View engine setup ───
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// ─── Middleware ───
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(cookieParser());

// Explicitly expose X-Powered-By header (PHASE 1 flag: SCENARIO75{Node.js})
app.use((req, res, next) => {
  res.setHeader('X-Powered-By', 'Node.js');
  next();
});

// Serve static files (robots.txt, css, etc.)
app.use(express.static(path.join(__dirname, 'public')));

// ─── Session Initialization Middleware ───
// Issue pre-authentication cookie (PHASE 1 flags)
app.use((req, res, next) => {
  if (!req.cookies.pre_mfa_session && !req.cookies.adm_sess) {
    // Set cookie with HttpOnly = false (PHASE 2 flag: SCENARIO75{False})
    res.cookie('pre_mfa_session', 'pending_mfa_verification', {
      httpOnly: false,
      path: '/'
    });
  }
  next();
});

// ─── In-memory storage ───
const feedbackStore = [];
const adminSessions = {};

// Simulated admin session (pre-seeded for the attack path)
const ADMIN_COOKIE_VALUE = 'adm_sess_7f3c2d1a9b4e8f6c';
adminSessions[ADMIN_COOKIE_VALUE] = {
  user: 'admin',
  role: 'administrator',
  authenticated: true,
  mfa_verified: true
};

// ─── ROUTES ───

// Home / Feedback form
app.get('/', (req, res) => {
  res.render('index');
});

// Feedback submission endpoint - POST only (PHASE 2 flag: SCENARIO75{POST})
app.post('/api/feedback', waf, (req, res) => {
  const { feedback } = req.body;

  if (!feedback || feedback.trim() === '') {
    return res.status(400).json({ error: 'Feedback cannot be empty' });
  }

  // Store feedback (vulnerable - no sanitization after WAF bypass)
  feedbackStore.push({
    content: feedback,
    timestamp: new Date().toISOString(),
    ip: req.ip
  });

  // Log the feedback submission
  logAccess(req, 200, 'Feedback submitted');

  res.status(200).json({ message: 'Feedback submitted successfully', id: feedbackStore.length });
});

// MFA Verification endpoint (the one that gets bypassed)
app.post('/api/verify-mfa', (req, res) => {
  const { code } = req.body;
  const sessionCookie = req.cookies.pre_mfa_session;

  if (!sessionCookie || sessionCookie !== 'pending_mfa_verification') {
    return res.status(401).json({ error: 'No pending MFA session' });
  }

  // Simulate MFA verification
  if (code === '123456') {
    // Upgrade to admin session
    res.cookie('adm_sess', ADMIN_COOKIE_VALUE, {
      httpOnly: false,
      path: '/'
    });
    res.clearCookie('pre_mfa_session');
    return res.status(200).json({ message: 'MFA verified', redirect: '/dashboard' });
  }

  logError('MFA verification failed', req);
  return res.status(403).json({ error: 'Invalid MFA code' });
});

// Dashboard - Admin area (PHASE 1 flag: SCENARIO75{/dashboard})
app.get('/dashboard', (req, res) => {
  const admSession = req.cookies.adm_sess;

  // PHASE 3: If user replays a valid stolen admin cookie,
  // skip /api/verify-mfa verification (SCENARIO75{/api/verify-mfa})
  if (admSession && adminSessions[admSession]) {
    // Session replay successful - MFA bypassed!
    logAccess(req, 200, 'Dashboard accessed via session replay');

    // Render dashboard with stored feedback (reflects XSS)
    const latestFeedback = feedbackStore.length > 0
      ? feedbackStore[feedbackStore.length - 1].content
      : null;

    return res.render('dashboard', {
      user: adminSessions[admSession].user,
      feedback: latestFeedback,
      flag: 'SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d}'
    });
  }

  // No valid session - redirect to login
  logError('Unauthorized dashboard access attempt', req);
  return res.status(401).render('unauthorized');
});

// ─── Logging helpers ───
const LOG_DIR = '/opt/admin/logs';

function ensureLogDir() {
  try {
    if (!fs.existsSync(LOG_DIR)) {
      fs.mkdirSync(LOG_DIR, { recursive: true });
    }
  } catch (e) {
    // Fallback to local logs directory
  }
}

function logAccess(req, status, message) {
  ensureLogDir();
  const timestamp = new Date().toISOString();
  const ip = req.headers['x-forwarded-for'] || req.ip;
  const ua = req.headers['user-agent'] || '-';
  const entry = `${ip} - - [${timestamp}] "${req.method} ${req.originalUrl} HTTP/1.1" ${status} - "${ua}" "${message}"\n`;

  try {
    fs.appendFileSync(path.join(LOG_DIR, 'access.log'), entry);
  } catch (e) {
    // Silent fail in development
  }
}

function logError(message, req, level = 'ERROR') {
  ensureLogDir();
  const timestamp = new Date().toISOString();
  const ip = req ? (req.headers['x-forwarded-for'] || req.ip) : 'system';
  const entry = `[${timestamp}] [${level}] [client ${ip}] ${message}\n`;

  try {
    fs.appendFileSync(path.join(LOG_DIR, 'error.log'), entry);
  } catch (e) {
    // Silent fail in development
  }
}

// ─── Start server ───
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[*] Admin Feedback System running on port ${PORT}`);
  console.log(`[*] Logs directory: ${LOG_DIR}`);
  ensureLogDir();
});

module.exports = app;
