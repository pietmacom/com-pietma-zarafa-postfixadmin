user = zarafapostfixadmin
password = 
hosts = unix:/run/mysqld/mysqld.sock
dbname = zarafapostfixadmin
query = SELECT domain FROM domain WHERE domain = '%s' AND active = '1'