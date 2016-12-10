user = zarafa
password = 
hosts = unix:/run/mysqld/mysqld.sock
dbname = zarafa
query = select distinct SUBSTRING_INDEX (value,'@', -1) from objectproperty where propname='emailaddress' AND  SUBSTRING_INDEX (value,'@', -1) = '%s';