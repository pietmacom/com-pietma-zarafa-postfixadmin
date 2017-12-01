-- IMPORT FROM KOPANO TO KOPANOPOSTFIXADMIN

-- Execute this script right in Mysql
-- mysql -uroot < import-from-kopano.sql

-- OR replace table names before execution
-- cat import-from-kopano.sql | sed "s/kopanopostfixadmin./replacement_kopanopostfixadmin./g" | sed "s/kopano./replacment_kopano./g" | mysql -uroot -p

-- import domains

 INSERT IGNORE INTO kopanopostfixadmin.domain (domain, transport, active, created, modified) 
  SELECT
   SUBSTRING_INDEX (value,'@', -1) as domain,
     'virtual' AS transport,
     '1' AS active,
	 NOW() AS created,
	 NOW() AS modified
  FROM kopano.objectproperty
  WHERE propname='emailaddress'
  GROUP BY domain;

-- import mailboxes ( no sendas )

 INSERT IGNORE INTO kopanopostfixadmin.mailbox (username, name, local_part, domain, active, created, modified)
  SELECT 
   value AS username,
   (SELECT value FROM kopano.objectproperty WHERE propname='fullname' AND objectid=m.objectid) AS name,
   SUBSTRING_INDEX (value,'@', 1) AS local_part,
   SUBSTRING_INDEX (value,'@', -1) AS domain,
   '1' AS active,
   NOW() AS created,
   NOW() AS modified
  FROM kopano.objectproperty AS m
  LEFT JOIN kopano.objectrelation AS r ON m.objectid=r.parentobjectid AND r.relationtype='6'
  WHERE m.propname='emailaddress' and r.parentobjectid IS NULL;

 INSERT IGNORE INTO kopanopostfixadmin.alias (address, goto, domain, active, created, modified)
  SELECT 
   value AS address,
   value AS goto,
   SUBSTRING_INDEX (value,'@', -1) AS domain,
   '1' AS active,
   NOW() AS created,
   NOW() AS modified
  FROM kopano.objectproperty AS m
  LEFT JOIN kopano.objectrelation AS r ON m.objectid=r.parentobjectid AND r.relationtype='6'
  WHERE m.propname='emailaddress' and r.parentobjectid IS NULL;

-- import alias ( only sendas )

 SET group_concat_max_len = 2048;
 INSERT IGNORE INTO kopanopostfixadmin.alias (address, goto, domain, active, created, modified)
  SELECT 
   value AS address,
   GROUP_CONCAT((SELECT value FROM kopano.objectproperty WHERE propname='emailaddress' AND objectid=r.objectid) SEPARATOR ', ') as goto,
   SUBSTRING_INDEX (value,'@', -1) AS domain,
   '1' AS active,
   NOW() AS created,
   NOW() AS modified  
  FROM kopano.objectrelation AS r
  INNER JOIN kopano.objectproperty AS m ON m.objectid=r.parentobjectid
  WHERE m.propname='emailaddress'
  GROUP BY value;

