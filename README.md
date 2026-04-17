# scripts
[mysql_replica_monitor.sh]
Kamu akan dapat:
🚨 Alert saat problem
✅ Notif saat normal kembali
📊 Report harian (tanpa spam)

#Buat user khusus monitoring
CREATE USER 'monitor'@'localhost' IDENTIFIED BY 'M0n!toR1ng';
GRANT REPLICATION CLIENT ON *.* TO 'monitor'@'localhost';

#buat file .my.cnf
nano ~/.my.cnf
[client]
user=monitor
password=M0n!toR1ng
host=localhost

#Set permission
chmod 600 ~/.my.cnf

#Test query
mysql -e "SHOW SLAVE STATUS\G"

#Output yang diharapkan
*************************** 1. row ***************************
               Slave_IO_State: Waiting for source to send event
                  Master_Host: 192.168.1.100
                  Master_User: replication
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000720
          Read_Master_Log_Pos: 75649192
               Relay_Log_File: mysql-relay-bin.000175
                Relay_Log_Pos: 75649408
        Relay_Master_Log_File: mysql-bin.000720
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 0
                   Last_Error:
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 75649192
              Relay_Log_Space: 75649665
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File:
           Master_SSL_CA_Path:
              Master_SSL_Cert:
            Master_SSL_Cipher:
               Master_SSL_Key:
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Master_Server_Id: 1
                  Master_UUID: 5b1c46b0-f2e8-11f0-ac42-d4f5efb4ab78
             Master_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Master_SSL_Crl:
           Master_SSL_Crlpath:
           Retrieved_Gtid_Set:
            Executed_Gtid_Set:
                Auto_Position: 0
         Replicate_Rewrite_DB:
                 Channel_Name:
           Master_TLS_Version:
       Master_public_key_path:
        Get_master_public_key: 0
            Network_Namespace:
            
Buat cron untuk jalan tiap menit
* * * * * /bin/bash /home/user/scripts/mysql_replica_monitor.sh
       
