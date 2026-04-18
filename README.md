# 📊 MySQL Replica Monitor

Script sederhana untuk monitoring status MySQL Replica (Slave) dan mengirim notifikasi ke Telegram.

---

## 🚀 Features

* 🚨 Alert saat terjadi masalah (replica delay / thread mati)
* ✅ Notifikasi saat replica kembali normal
* 📊 Report harian (tanpa spam)
* 🔕 Tidak mengirim notif berulang untuk kondisi yang sama
* ⚡ Ringan & cocok untuk cron job

---

## 📋 Requirements

* MySQL / MariaDB (Replica / Slave)
* Bash (Linux)
* curl
* Telegram Bot

---

## 🔧 Setup

### 1. Buat user MySQL khusus monitoring

```sql
CREATE USER 'monitor'@'localhost' IDENTIFIED BY 'M0n!toR1ng';
GRANT REPLICATION CLIENT ON *.* TO 'monitor'@'localhost';
```

---

### 2. Simpan credential di `.my.cnf`

```bash
nano ~/.my.cnf
```

```ini
[client]
user=monitor
password=M0n!toR1ng
host=localhost
```

Set permission:

```bash
chmod 600 ~/.my.cnf
```

---

### 3. Test koneksi

```bash
mysql -e "SHOW SLAVE STATUS\G"
```

Pastikan tidak diminta password dan data muncul.

---

### 4. Konfigurasi Telegram Bot

Edit script dan isi:

```bash
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
```

---

### 5. Jalankan manual (testing)

```bash
bash mysql_replica_monitor.sh
```

---

### 6. Tambahkan ke cron

```bash
* * * * * /bin/bash /path/to/mysql_replica_monitor.sh
```

Script akan berjalan setiap menit.

---

## 🧪 Testing Mode

Untuk force kirim notifikasi (tanpa menunggu kondisi berubah):

```bash
FORCE_SEND=1
```

Setelah selesai testing:

```bash
FORCE_SEND=0
```

---

## 📩 Contoh Notifikasi

```
📊 MySQL Replica Daily Status

[server-name]
Master : 192.168.1.100
Time   : 2026-04-18 00:53:19

IO Thread   : Running ✅
SQL Thread  : Running ✅
Delay       : 0 sec ✅

State  : Replica has read all relay log; waiting for more updates
```

---

## ⚠️ Kondisi yang Dipantau

* IO Thread (Slave_IO_Running)
* SQL Thread (Slave_SQL_Running)
* Delay (Seconds_Behind_Master)
* Error message (jika ada)

---

## 🧠 Logic Notifikasi

| Kondisi      | Notifikasi                   |
| ------------ | ---------------------------- |
| Problem      | 🚨 Kirim alert               |
| Recovery     | ✅ Kirim notif normal kembali |
| Normal       | 📊 Kirim report harian (1x)  |
| Sama kondisi | 🔕 Tidak kirim ulang         |

---

## 🔐 Security Notes

* Gunakan `.my.cnf` agar password tidak terlihat di script
* Gunakan permission `600` pada file `.my.cnf`
* Gunakan user MySQL dengan privilege minimal (REPLICATION CLIENT)

---

## ⚡ Tips

* Pastikan timezone server sesuai kebutuhan
* Gunakan absolute path di cron
* Redirect log jika diperlukan:

```bash
* * * * * /bin/bash /path/script.sh >> /var/log/mysql_repl.log 2>&1
```

---

## 🛠 Troubleshooting

### Tidak ada notifikasi

* Cek TOKEN dan CHAT_ID
* Test dengan curl manual

### Output aneh (\n muncul)

* Pastikan script menggunakan `printf "%b"`

### Error command not found (emoji)

* Gunakan unicode (`\Uxxxx`) atau pastikan encoding UTF-8

---

## 📌 Notes

Script ini cocok untuk:

* VPS / Dedicated server
* Monitoring ringan tanpa tools besar (Zabbix, Prometheus, dll)

---

## 👨‍💻 Author

Custom script by chatgpt 🚀
