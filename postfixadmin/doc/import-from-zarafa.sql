-- IMPORT FROM ZARAFA TO ZARAFA-POSTFIXADMIN
-- Just run this script right in Mysql

-- import domains

 INSERT IGNORE INTO zarafapostfixadmin.domain (domain, transport, active, created, modified) 
  SELECT
   SUBSTRING_INDEX (value,'@', -1) as domain,
     'virtual' AS transport,
     '1' AS active,
	 NOW() AS created,
	 NOW() AS modified
  FROM zarafa.objectproperty
  WHERE propname='emailaddress'
  GROUP BY domain;

-- import mailboxes ( no sendas )

INSERT IGNORE INTO zarafapostfixadmin.mailbox (username, name, local_part, domain, active, created, modified)
 SELECT 
  value AS username,
  (SELECT value FROM zarafa.objectproperty WHERE propname='fullname' AND objectid=m.objectid) AS name,
  SUBSTRING_INDEX (value,'@', 1) AS local_part,
  SUBSTRING_INDEX (value,'@', -1) AS domain,
  '1' AS active,
  NOW() AS created,
  NOW() AS modified
 FROM zarafa.objectproperty AS m
 LEFT JOIN zarafa.objectrelation AS r ON m.objectid=r.parentobjectid AND r.relationtype='6'
 WHERE m.propname='emailaddress' and r.parentobjectid IS NULL;

INSERT IGNORE INTO zarafapostfixadmin.alias (address, goto, domain, active, created, modified)
 SELECT 
  value AS address,
  value AS goto,
  SUBSTRING_INDEX (value,'@', -1) AS domain,
  '1' AS active,
  NOW() AS created,
  NOW() AS modified
 FROM zarafa.objectproperty AS m
 LEFT JOIN zarafa.objectrelation AS r ON m.objectid=r.parentobjectid AND r.relationtype='6'
 WHERE m.propname='emailaddress' and r.parentobjectid IS NULL;

-- import alias ( only sendas )

SET group_concat_max_len = 2048;
INSERT IGNORE INTO zarafapostfixadmin.alias (address, goto, domain, active, created, modified)
 SELECT 
  value AS address,
  GROUP_CONCAT((SELECT value FROM zarafa.objectproperty WHERE propname='emailaddress' AND objectid=r.objectid) SEPARATOR ', ') as goto,
  SUBSTRING_INDEX (value,'@', -1) AS domain,
  '1' AS active,
  NOW() AS created,
  NOW() AS modified  
 FROM zarafa.objectrelation AS r
 INNER JOIN zarafa.objectproperty AS m ON m.objectid=r.parentobjectid
 WHERE m.propname='emailaddress'
 GROUP BY value;

