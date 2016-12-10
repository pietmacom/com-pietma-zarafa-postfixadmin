user = zarafapostfixadmin
password = 
hosts = unix:/run/mysqld/mysqld.sock
dbname = zarafapostfixadmin
query = SELECT CONCAT(src_user, ':', FROM_BASE64(src_password)) FROM fetchmail WHERE mailbox = '%s' AND dst_server IS NOT NULL AND dst_server <> '' AND active = '1' ORDER BY src_user, dst_server;

