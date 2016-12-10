user = zarafa
password = 
hosts = unix:/run/mysqld/mysqld.sock
dbname = zarafa
query = SELECT value FROM objectproperty WHERE propname='emailaddress' AND value='%s';