#!/bin/sh -e

_lastlog="/var/lib/postfixadmin-zarafa/lastlog"

PHP=$(which php)
MYSQL=$(which mysql)
ZARAFAADMIN=$(which zarafa-admin)


# SETTINGS FROM Postfixadmin
_settings=$($PHP --no-php-ini -d open_basedir=NULL << 'EOF'
<?
    include('/usr/share/webapps/postfixadmin/config.inc.php'); 
    echo $CONF['configured'] . "\n"; 		#1
    echo $CONF['database_host'] . "\n";		#2
    echo $CONF['database_user'] . "\n";		#3
    echo $CONF['database_password'] . "\n";	#4
    echo $CONF['database_name'] . "\n";		#5
?>
EOF
)
if [[ $(echo -n "$_settings" | sed -n "1p") != "1" ]];
then
    echo "Postfixadmin is not set up."
    exit
fi

_database_host=$(echo -n "$_settings" | sed -n "2p")
_database_user=$(echo -n "$_settings" | sed -n "3p")
_database_password=$(echo -n "$_settings" | sed -n "4p")
_database_name=$(echo -n "$_settings" | sed -n "5p")

if [[ ${_database_host} == localhost:/* ]];
then
    _destination="-S"$(echo -n "${_database_host}" | sed "s/^.*\://g")
else
    _destination="-h"${_database_host}
fi
MYSQLEXEC="$MYSQL ${_database_name} -u${_database_user} -p${_database_password} ${_destination} -s -N  -e"



# SETINGS FROM ZARAFA
_zsettings="/etc/zarafa/server.cfg"
if [[ ! -e ${_zsettings} ]];
then
    echo "Zarafa is not set up."
    exit                
fi   

_zdatabase_host=$(cat ${_zsettings} | grep -e "mysql_host" | sed "s/.*=\s*//g")
_zdatabase_socket=$(cat ${_zsettings} | grep -e "mysql_socket" | sed "s/.*=\s*//g")
_zdatabase_user=$(cat ${_zsettings} | grep -e "mysql_user" | sed "s/.*=\s*//g")
_zdatabase_password=$(cat ${_zsettings} | grep -e "mysql_password" | sed "s/.*=\s*//g")
_zdatabase_name=$(cat ${_zsettings} | grep -e "mysql_database" | sed "s/.*=\s*//g")

if [[ ${_zdatabase_host} == localhost* && ${_zdatabase_socket} == /* ]];
then
    _zdestination="-S${_zdatabase_socket}"
else
    _zdestination="-h${_zdatabase_host}"
fi
ZMYSQLEXEC="$MYSQL ${_zdatabase_name} -u${_zdatabase_user} -p${_zdatabase_password} ${_zdestination} -s -N  -e"



### APPLICATION

# use only new log entries "
if [[ -e ${_lastlog} ]];
then
    _logworked=$(cat ${_lastlog})
    _log=$($MYSQLEXEC "SELECT * FROM log WHERE timestamp > '${_logworked}' ORDER BY timestamp ASC;")
else 
    _log=$($MYSQLEXEC "SELECT * FROM log WHERE ORDER BY timestamp ASC;")
fi

if [[ -z ${_log} ]];
then
    echo "Nothing to do on" $(date)
    exit
fi

echo "${_log}" | while read p
do
    echo "Action ${p}"
    
    _timestamp=$(echo "$p" | cut -f1)
    _action=$(echo "$p" | cut -f4)
    _data=$(echo "$p" | cut -f5)

    _mailbox=$($MYSQLEXEC "SELECT username, password, name, local_part, active  FROM mailbox WHERE username='${_data}';")
    _alias=$($MYSQLEXEC "SELECT address, goto, active FROM alias WHERE address='${_data}';")

    # To complicated? Well... Going with the e-mailaddress enables you to change usernames as you wish! 
    _zuser=$($ZMYSQLEXEC "SELECT objectid, value FROM objectproperty WHERE objectid=(SELECT objectid FROM objectproperty WHERE propname='emailaddress' AND value='${_data}') AND propname='loginname';")
    _zuserid=$(echo "${_zuser}" | cut -f1)
    _zusername=$(echo "${_zuser}" | cut -f2)
    # "
    
    case ${_action} in
    *alias)

	if [[ ! -z ${_mailbox} ]];
        then
            echo "Skipped automatic alias for mailbox"
            continue
        fi

	_address=$(echo "${_alias}" | cut -f1)
	_goto=$(echo "${_alias}" | cut -f2)
	_active=$(echo "${_alias}" | cut -f3)

	_znewdelegate=$($ZMYSQLEXEC "SELECT objectid, value FROM objectproperty WHERE objectid=(SELECT objectid FROM objectproperty WHERE propname='emailaddress' AND value='${_goto}') AND propname='loginname';")
	_znewdelegateid=$(echo "${_znewdelegate}" | cut -f1)
	_znewdelegateusername=$(echo "${_znewdelegate}" | cut -f2)
	#"
	
	#  CHECKS
	case ${_action} in
	create*)
	    if [[ -z ${_znewdelegateid} ]];
    	    then
        	echo "Skipping not existing local target"
        	continue
    	    fi

    	    if [[ ${_active} == "0" ]];
    	    then
        	echo "Skipping creation of inactive alias"
        	continue
    	    fi
	;;
	delete*)
	    if [[ -z ${_zuser} ]];
	    then
		echo "Skipping unknown local alias"
		continue
	    fi
	;;	
	edit*)
	    if [[ -z ${_zuser} ]];
	    then
		echo "Treating non existing local alias as create"
		_action="create_alias"
	    fi
	
	    if [[ -z ${_znewdelegateid} ]];
    	    then
    		echo "Treating non existing local target as delete_alias"	    
    		_action="delete_alias"
	    fi
	
	    if [[ ${_active} == "0" ]];
	    then
		echo "Treating alias active=0 as delete_alias"
		_action="delete_alias"
	    fi
	;;
	esac

	#  WORK
        case ${_action} in
        create*)
    	    # locale part of the email me@you.de -> me
    	    _name=$(echo "${_address}" | sed "s/@.*//g")
            _password=$(< /dev/urandom tr -dc 0-9 | head -c16)$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)

            if [[ -z ${_zusername} ]];
            then
    		echo "Creating user ${_address}"            
        	$ZARAFAADMIN -c "${_address}" -p "${_password}" -f "${_name}" -e "${_address}" -a "0" -n "1"
		$ZARAFAADMIN --create-store "${_address}"
            else
                # update existing with its username         
                echo "Reenabling user ${_zusername} with email ${_address}"
                $ZARAFAADMIN -u "${_zusername}" -p "${_password}" -f "${_name}" -e "${_address}" -a "0" -n "1"
		
		# check for existing store		
                $ZARAFAADMIN --details "${_zusername}" > /dev/null 
                if [[ $? -ne 0 ]];
                then
		    echo "Reattache store to user ${_zusername}"                            
                    $ZARAFAADMIN -u "${_zusername}" --hook-store "${_zuserstore}"
                fi
            fi
            
	    if [[ ${_active} == "1" ]];
    	    then
    		echo "Adding delegate ${_znewdelegateusername} for user ${_address}"
        	$ZARAFAADMIN -u "${_address}" --add-sendas "${_znewdelegateusername}"
    	    fi
        ;;
        delete*)
    	    # TODO Allow to keep more delegates

	    # Remove delegates
	    _zsendas=$($ZMYSQLEXEC "SELECT objectid FROM objectrelation WHERE parentobjectid='${_zuserid}' AND relationtype='6';")    
	    if [[ ! -z ${_zsendas} ]];
	    then
		echo "${_zsendas}" | while read _zdelegateid
		do
		    _zdelegateusername=$($ZMYSQLEXEC "SELECT value FROM objectproperty WHERE propname='loginname' AND objectid='${_zdelegateid}'")
		    
		    echo "Removing delegate ${_zdelegateusername} from user ${_zusername}"
		    $ZARAFAADMIN -u "${_zusername}" --del-sendas "${_zdelegateusername}"
		done
	    fi
	    
	    echo "Deleting user ${_zusername}"
	    _zuserstore=$($ZMYSQLEXEC "SELECT HEX(guid) FROM stores WHERE user_name='${_zusername}';")
	    $ZARAFAADMIN --unhook-store "${_zusername}"
	    $ZARAFAADMIN --remove-store "${_zuserstore}"
	    $ZARAFAADMIN -d "${_zusername}"
	    
	    # dummy for highlighting in mc "
        ;;
        edit*)
	    _zsendas=$($ZMYSQLEXEC "SELECT objectid FROM objectrelation WHERE parentobjectid='${_zuserid}' AND relationtype='6';")
            if [[ ! -z ${_zsendas} ]];
            then
                echo "${_zsendas}" | while read _zdelegateid
                do
                    _zdelegateusername=$($ZMYSQLEXEC "SELECT value FROM objectproperty WHERE propname='loginname' AND objectid='${_zdelegateid}'")
                    
                    echo "Removing delegate ${_zdelegateusername} from user ${_zusername}"
                    $ZARAFAADMIN -u "${_zusername}" --del-sendas "${_zdelegateusername}"
                done
            fi
	    
	    echo "Adding delegate ${_znewdelegateusername} for user ${_zusername}"
	    $ZARAFAADMIN -u "${_zusername}" --add-sendas "${_znewdelegateusername}"	    
        ;;
        esac	
    ;;
    
    *mailbox)

	_username=$(echo "${_mailbox}" | cut -f1)
	_password=$(echo "${_mailbox}" | cut -f2)
	_name=$(echo "${_mailbox}" | cut -f3)
	_local_part=$(echo "${_mailbox}" | cut -f4)
	_active=$(echo "${_mailbox}" | cut -f5)

	_zuserstore=$($ZMYSQLEXEC "SELECT HEX(guid) FROM stores WHERE user_name='${_data}';")
	# "

	#  CHECKS
	# zarafa defines inactive users
	if [[ ${_active} == "0" ]];
	then
	    _inactive="1"
	else
	    _inactive="0"
	fi
	
	# zarafa doesn't allow empty full names
        if [[ -z ${_name} ]];
        then
	    _name=${_local_part}
	fi

        case ${_action} in
        create*)
        ;;
        delete*)
    	    if [[ -z ${_zuser} ]];
            then
        	echo "User with email ${_data} not found in Zarafa"
        	continue
            fi
        ;;
        edit*)
    	    if [[ -z ${_zuser} ]];
            then
                echo "User with email ${_data} not found in Zarafa"
                continue
            fi
        ;;        
        esac

	#  WORK
	case ${_action} in
	create*)
	    if [[ -z ${_zusername} ]];
	    then
		# create with e-mail as username	    
		echo "Creating user ${_username} with email ${_username}"		
	    	$ZARAFAADMIN -c "${_username}" -p "${_password}" -f "${_name}" -e "${_username}" -a "0" -n "${_inactive}"
		$ZARAFAADMIN --create-store "${_username}"
	    else
		# update existing with its username	    
	    	echo "Reenabling user ${_zusername} with email ${_username}"
	    	$ZARAFAADMIN -u "${_zusername}" -p "${_password}" -f "${_name}" -e "${_username}" -a "0" -n "${_inactive}"

		# check for existing store
                $ZARAFAADMIN --details "${_zusername}" > /dev/null 
                if [[ $? -ne 0 ]];
                then
 		    echo "Reattache store to user ${_zusername}"            
                    $ZARAFAADMIN -u "${_zusername}" --hook-store "${_zuserstore}"
                fi		
	    fi
	    # remove password from database (set marker for password reset)
	    $MYSQLEXEC "UPDATE mailbox SET password='updated' WHERE username='${_username}'";
	;;
	delete*)
    	    # disable account. real delete will follow.	
	    echo "Deleting user ${_zusername}"
    	    $ZARAFAADMIN --unhook-store "${_zusername}"
    	    $ZARAFAADMIN --remove-store "${_zuserstore}"
    	    $ZARAFAADMIN -d "${_zusername}"
	;;
	edit*)
	    
    	    if [[ ${_password} == "updated" ]];
    	    then
            	# disable account. real delete will follow.        	
        	echo "Updating user ${_zusername} with email ${_username}"
		$ZARAFAADMIN -u "${_zusername}" -f "${_name}" -e "${_username}" -a "0" -n "${_inactive}"
    	    else
        	echo "Updating user ${_zusername} with email ${_username} and password"
        	$ZARAFAADMIN -u "${_zusername}" -p "${_password}" -f "${_name}" -e "${_username}" -a "0" -n "${_inactive}"
                # remove password from database (set marker for password reset)
	        $MYSQLEXEC "UPDATE mailbox SET password='updated' WHERE username='${_username}'";
    	    fi
	    
	    # check for existing store
            $ZARAFAADMIN --details "${_zusername}" > /dev/null
            if [[ $? -ne 0 ]];
            then
		echo "Reattache store to user ${_zusername}"            
                $ZARAFAADMIN -u "${_zusername}" --hook-store "${_zuserstore}"
            fi    	    
	;;
	esac
    ;;
        
    *)
	echo "Skipped"
    ;;
    esac
    
    # spacer
    echo " "
    
    # mark position as done
    echo "${_timestamp}" > ${_lastlog}
done


