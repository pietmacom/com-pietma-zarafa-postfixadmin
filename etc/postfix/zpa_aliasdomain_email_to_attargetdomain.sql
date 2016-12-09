user = zarafapostfixadmin
password = 
hosts = unix:/run/mysqld/mysqld.sock
dbname = zarafapostfixadmin
query = SELECT CONCAT('@', target_domain) FROM alias_domain WHERE alias_domain=SUBSTRING_INDEX ('%s','@', -1) AND active = '1'
