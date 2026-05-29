/**
 * Rudimentary WAF Middleware
 * 
 * PHASE 2 - Defense Evasion:
 * - Blocks standard <script> payloads -> returns 403 (SCENARIO75{403})
 * - Vulnerable to bypass via <svg> with onload (SCENARIO75{<svg>})
 * - Blocks direct "document.cookie" keyword access
 * - Allows bracket notation: window['docu'+'ment']['coo'+'kie'] (SCENARIO75{window['docu'+'ment']['coo'+'kie']})
 * - Permits fetch API usage (SCENARIO75{fetch})
 */

function waf(req, res, next) {
  const feedback = req.body.feedback || '';

  // Block 1: Check for <script> tags (case-insensitive)
  const scriptPattern = /<script[\s>]/i;
  if (scriptPattern.test(feedback)) {
    // Log WAF block
    logWafBlock(req, feedback);
    return res.status(403).json({
      error: 'WAF: Malicious input detected',
      blocked: true,
      reason: 'Script tag detected'
    });
  }

  // Block 2: Check for direct "document.cookie" access
  const cookiePattern = /document\.cookie/i;
  if (cookiePattern.test(feedback)) {
    logWafBlock(req, feedback);
    return res.status(403).json({
      error: 'WAF: Malicious input detected',
      blocked: true,
      reason: 'Cookie access attempt detected'
    });
  }

  // ─── VULNERABILITY ───
  // The WAF does NOT check for:
  // - <svg onload=...> (HTML5 event handler bypass)
  // - Bracket notation like window['docu'+'ment']['coo'+'kie']
  // - fetch() API calls
  // This allows the attacker to craft a bypass payload

  next();
}

function logWafBlock(req, payload) {
  const fs = require('fs');
  const path = require('path');
  const LOG_DIR = '/opt/admin/logs';

  const timestamp = new Date().toISOString();
  const ip = req.headers['x-forwarded-for'] || req.ip;
  const entry = `[${timestamp}] [WARNING] [client ${ip}] WAF BLOCK: Malicious payload detected in feedback submission: ${payload.substring(0, 100)}\n`;

  try {
    fs.appendFileSync(path.join(LOG_DIR, 'error.log'), entry);
  } catch (e) {
    // Silent fail
  }
}

module.exports = waf;
