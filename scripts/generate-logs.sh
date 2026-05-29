#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# generate-logs.sh
# Injects simulated attack sequence into logs upon deployment.
# Logs stored in /opt/admin/logs/ (SCENARIO75{/opt/admin/logs})
# ═══════════════════════════════════════════════════════════════

LOG_DIR="/opt/admin/logs"
ACCESS_LOG="${LOG_DIR}/access.log"
ERROR_LOG="${LOG_DIR}/error.log"

# Create log directory
mkdir -p "$LOG_DIR"

# Clear existing logs
> "$ACCESS_LOG"
> "$ERROR_LOG"

echo "[*] Generating simulated attack logs..."

# ═══════════════════════════════════════════════════════════════
# LEGITIMATE BASELINE TRAFFIC (from 192.168.1.100)
# SCENARIO75{192.168.1.100}
# ═══════════════════════════════════════════════════════════════
cat >> "$ACCESS_LOG" << 'EOF'
192.168.1.100 - admin [29/May/2026:18:45:00 +0000] "GET / HTTP/1.1" 200 3842 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
192.168.1.100 - admin [29/May/2026:18:45:05 +0000] "GET /dashboard HTTP/1.1" 200 5120 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
192.168.1.100 - admin [29/May/2026:18:46:00 +0000] "POST /api/verify-mfa HTTP/1.1" 200 256 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
192.168.1.100 - admin [29/May/2026:18:46:30 +0000] "GET /dashboard HTTP/1.1" 200 5120 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
192.168.1.100 - admin [29/May/2026:18:47:00 +0000] "GET /api/feedback HTTP/1.1" 200 1024 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
192.168.1.100 - admin [29/May/2026:18:48:00 +0000] "POST /api/feedback HTTP/1.1" 200 128 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
EOF

# ═══════════════════════════════════════════════════════════════
# ATTACKER RECONNAISSANCE (from 10.10.14.50)
# Attacker IP: SCENARIO75{10.10.14.50}
# User-Agent: SCENARIO75{Mozilla/5.0}
# Subnet: SCENARIO75{10.10.14.0/24}
# ═══════════════════════════════════════════════════════════════
cat >> "$ACCESS_LOG" << 'EOF'
10.10.14.50 - - [29/May/2026:18:49:00 +0000] "GET / HTTP/1.1" 200 3842 "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [29/May/2026:18:49:10 +0000] "GET /robots.txt HTTP/1.1" 200 156 "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [29/May/2026:18:49:20 +0000] "GET /dashboard HTTP/1.1" 401 512 "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
EOF

# ═══════════════════════════════════════════════════════════════
# ATTACKER XSS ATTEMPTS (WAF Blocks & Bypass)
# First WAF block at 18:50:15 (SCENARIO75{18:50:15})
# Blocked tag: SCENARIO75{<script>}
# ═══════════════════════════════════════════════════════════════

# WAF block entry in error.log at exact timestamp
cat >> "$ERROR_LOG" << 'EOF'
[29/May/2026:18:50:15 +0000] [WARNING] [client 10.10.14.50] WAF BLOCK: Malicious payload detected in feedback submission: <script>alert('xss')</script>
EOF

cat >> "$ACCESS_LOG" << 'EOF'
10.10.14.50 - - [29/May/2026:18:50:15 +0000] "POST /api/feedback HTTP/1.1" 403 128 "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [29/May/2026:18:50:30 +0000] "POST /api/feedback HTTP/1.1" 403 128 "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
EOF

cat >> "$ERROR_LOG" << 'EOF'
[29/May/2026:18:50:30 +0000] [WARNING] [client 10.10.14.50] WAF BLOCK: Malicious payload detected in feedback submission: <script>document.cookie</script>
EOF

# Successful WAF bypass with <svg> at 18:50:45
cat >> "$ACCESS_LOG" << 'EOF'
10.10.14.50 - - [29/May/2026:18:50:45 +0000] "POST /api/feedback HTTP/1.1" 200 128 "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
EOF

# ═══════════════════════════════════════════════════════════════
# ATTACKER SESSION REPLAY & DASHBOARD ACCESS
# Dashboard access at 18:51:55 with status 200
# SCENARIO75{200} and SCENARIO75{18:51:55}
# X-Forwarded-For with Base64 string
# SCENARIO75{UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}
# ═══════════════════════════════════════════════════════════════
cat >> "$ACCESS_LOG" << 'EOF'
10.10.14.50 - - [29/May/2026:18:51:55 +0000] "GET /dashboard HTTP/1.1" 200 5120 "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0"
EOF

# ═══════════════════════════════════════════════════════════════
# SECURITY ALERTS IN ERROR LOG
# Cookie reuse flagged as CRITICAL (SCENARIO75{CRITICAL})
# Authentication bypass anomaly at 18:53:10 (SCENARIO75{18:53:10})
# SCENARIO75{Authentication bypass anomaly}
# ═══════════════════════════════════════════════════════════════
cat >> "$ERROR_LOG" << 'EOF'
[29/May/2026:18:52:00 +0000] [WARNING] [client 10.10.14.50] Session cookie replayed from different IP - potential session hijacking
[29/May/2026:18:52:30 +0000] [CRITICAL] [client 10.10.14.50] Cookie reuse detected: adm_sess cookie presented without MFA verification flow
[29/May/2026:18:53:10 +0000] [CRITICAL] [client 10.10.14.50] Authentication bypass anomaly: admin session accessed without /api/verify-mfa completion from 10.10.14.50
EOF

# ═══════════════════════════════════════════════════════════════
# POST-ATTACK LEGITIMATE TRAFFIC (normal operations continue)
# ═══════════════════════════════════════════════════════════════
cat >> "$ACCESS_LOG" << 'EOF'
192.168.1.100 - admin [29/May/2026:18:55:00 +0000] "GET /dashboard HTTP/1.1" 200 5120 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
192.168.1.100 - admin [29/May/2026:18:56:00 +0000] "GET / HTTP/1.1" 200 3842 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
EOF

# ═══════════════════════════════════════════════════════════════
# VERIFICATION: Attacker never reached /api/verify-mfa
# SCENARIO75{No}
# (10.10.14.50 has NO entries for POST /api/verify-mfa)
# ═══════════════════════════════════════════════════════════════

echo "[+] Log generation complete!"
echo "[+] Access log: ${ACCESS_LOG}"
echo "[+] Error log: ${ERROR_LOG}"
echo ""
echo "[*] Verification:"
echo "    - Attacker IP 10.10.14.50 MFA requests: $(grep '10.10.14.50.*verify-mfa' $ACCESS_LOG | wc -l) (should be 0)"
echo "    - Legitimate IP 192.168.1.100 MFA requests: $(grep '192.168.1.100.*verify-mfa' $ACCESS_LOG | wc -l) (should be 1)"
echo "    - WAF blocks in error.log: $(grep 'WAF BLOCK' $ERROR_LOG | wc -l)"
echo "    - CRITICAL events: $(grep 'CRITICAL' $ERROR_LOG | wc -l)"
echo ""
echo "[✓] Attack simulation logs injected successfully."
