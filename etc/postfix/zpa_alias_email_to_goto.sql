user = zarafapostfixadmin
password = 
hosts = unix:/run/mysqld/mysqld.sock
dbname = zarafapostfixadmin
query = SELECT goto FROM alias WHERE address = '%s' AND active = '1'