[mysql_replica_monitor.sh]

## Fitur:
- 🚨 Alert saat problem
- ✅ Notif saat normal kembali
- 📊 Report harian (tanpa spam)

#Buat user khusus monitoring
```sql
CREATE USER 'monitor'@'localhost' IDENTIFIED BY 'M0n!toR1ng';
GRANT REPLICATION CLIENT ON *.* TO 'monitor'@'localhost';
```
#buat file .my.cnf
```bash
$ nano ~/.my.cnf
[client]
user=monitor
password=M0n!toR1ng
host=localhost
```
#Set permission
```
$ chmod 600 ~/.my.cnf
```

#Test query
```
$ mysql -e "SHOW SLAVE STATUS\G"
```
Buat cron untuk jalan tiap menit
```
$ crontab -e
* * * * * /bin/bash /home/user/scripts/mysql_replica_monitor.sh
```       
