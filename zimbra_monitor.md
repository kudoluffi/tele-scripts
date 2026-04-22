# 📊 Zimbra Monitor Script

Script Bash untuk monitoring server Zimbra dan mengirim notifikasi ke Telegram.

---

## 🚀 Features

- 🔍 Monitoring service Zimbra (`zmcontrol status`)
- 💾 Disk usage monitoring
- 🧠 Memory usage
- ⚙️ CPU load
- 📬 Mail queue
- 🔒 SSL certificate expiration
- 💿 Backup status (based on log file)

---

## 🔔 Notification Type

### 🚨 Problem Detected
Dikirim jika ada kondisi berikut:

- Service Zimbra tidak running
- Disk usage ≥ 90%
- SSL akan expired:
  - ⚠️ < 30 hari
  - ❌ < 15 hari
- Backup:
  - ⚠️ > 7 hari
  - ❌ > 10 hari

Contoh:
```bash
🚨 Zimbra Problem Detected

[mail-server]
Time : 2026-04-22 22:00:01

Services : 14/18 Running ❌
DOWN ❌ : amavis, antispam, antivirus, mta

Disk : 92% (CRITICAL)
SSL Exp : 12 days ❌
Backup : 11 days ago ❌
```

---

### ✅ Recovered
Dikirim saat kondisi kembali normal  
(Hanya menampilkan komponen yang sebelumnya bermasalah)

Contoh:
```
✅ Zimbra Recovered

[mail-server]
Time : 2026-04-22 22:10:01

Services : OK ✅

Status : BACK TO NORMAL
```

---

### 📊 Daily Summary
Dikirim 1x sehari (default: 05:30)

Contoh:
```
📊 ZIMBRA DAILY SUMMARY

📍 Server: mail-server
⏰ Time: 2026-04-22 05:30:01

Service Status:
✅ Services: 18 running

Resources:
💾 Disk: 46% (25G available)
🧠 Memory: 46% (3.6Gi/7.7Gi)
⚙️ CPU: 0.05

Mail:
📬 Queue: 0 messages

Security:
🔒 SSL: 86 days

Backup:
💿 Last backup: 0 days ago
```

---

## ⚙️ Configuration

Edit bagian berikut di script:

```bash
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
```

---

## ⏱️ Cron Setup

Jalankan setiap 5 menit:
```bash
*/5 * * * * /bin/bash /path/to/zimbra_monitor.sh
```

---

## 📁 Required Path

Pastikan path berikut tersedia:

* Zimbra binary:
```
/opt/zimbra/bin/
```
* Backup logs:
```
/backup/zimbra/logs/
```
* Format file backup:
```
zimbra-backup-YYYYMMDD.log
```

---

## 🧪 Testing
### Force send
Edit `zimbra_monitor.sh` dan ubah 
```
FORCE_SEND=1
```
Jalankan script-nya
```
sudo bash zimbra_monitor.sh
```
Simulasi problem
```
zmcontrol stop
```

---

## 📝 State File

Script menggunakan file berikut untuk tracking:

* `/tmp/zimbra_state` → status global
* `/tmp/zimbra_detail` → detail problem (service/disk/ssl/backup)
* `/tmp/zimbra_daily` → kontrol daily report

---

## 📌 Notes
* Script harus dijalankan dengan akses sudo
* Menggunakan user zimbra untuk query internal
* Tidak akan spam notifikasi (hanya saat state berubah)

---

## 🏷 Version

`Current version: v1.6.1`

---
## 👨‍💻 Author

ChatG-Kudo

---

# 👍 Kelebihan versi ini

- ✔ clean & profesional
- ✔ langsung siap GitHub
- ✔ konsisten dengan behavior script kamu
- ✔ mudah dikembangkan (next script tinggal copy format)

---
