user = zarafapostfixadmin
password = 
hosts = unix:/run/mysqld/mysqld.sock
dbname = zarafapostfixadmin
query = SELECT username FROM mailbox WHERE username = '%s' AND active = '1'