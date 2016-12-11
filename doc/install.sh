#!/bin/bash -e

_etc="/etc/webapps/zarafa-postfixadmin"
_config="${_etc}/config.local.php"
_databasename="zarafapostfixadmin"
_databaseuser="zarafapostfixadmin"

function setup_password() {
    local _salt=$(date +%s)"*127.0.0.1*"$(shuf -i 0-60000 -n 1)
    local _salt=$(echo -n "${_salt}" | md5sum | cut -f1 -d' ')
    echo -n "${_salt}:"$(echo -n "${_salt}:$1" | sha1sum | cut -f1 -d' ')
}

read -s -p "MySQL Root Password:" _mysqlpassword

if [[ -z ${_mysqlpassword} ]];
then
    echo "Continue without password"
    mysqlexec="mysql -uroot -s -N -e"
else
    mysqlexec="mysql -uroot -p${_mysqlpassword} -s -N -e"
fi

if [[ -z $($mysqlexec "show databases like '${_databasename}';") ]];
then
    echo "[....] Create Zarafa-Postfixadmin database"
    _databasepassword=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)

    if [[ -z $($mysqlexec "use mysql; select * from user where user ='${_databaseuser}';") ]];
    then
	$mysqlexec "CREATE USER '${_databaseuser}'@'localhost' IDENTIFIED BY '${_databasepassword}';"
    else
	$mysqlexec "SET PASSWORD FOR '${_databaseuser}'@'localhost' = PASSWORD('${_databasepassword}');"
    fi
    $mysqlexec "CREATE DATABASE ${_databasename};"
    $mysqlexec "GRANT ALL PRIVILEGES ON ${_databasename} . * TO '${_databaseuser}'@'localhost';"
    
    # zarafa postfixadmin config
    sed -i -e "s/\(configured']\s*=\s*\)\(.*\)\(;$\)/\1true\3/" ${_config}
    sed -i -e "s/\(database_type']\s*=\s*\)\(.*\)\(;$\)/\1'mysql'\3/" ${_config}
    sed -i -e "s/\(database_host']\s*=\s*\)\(.*\)\(;$\)/\1'localhost:\/run\/mysqld\/mysqld.sock'\3/" ${_config}
    sed -i -e "s/\(database_user']\s*=\s*\)\(.*\)\(;$\)/\1'${_databaseuser}'\3/" ${_config}
    sed -i -e "s/\(database_password']\s*=\s*\)\(.*\)\(;$\)/\1'${_databasepassword}'\3/" ${_config}
    sed -i -e "s/\(database_name']\s*=\s*\)\(.*\)\(;$\)/\1'${_databasename}'\3/" ${_config}

    # zarafa postfixadmin postfix scripts
    sed -i -e "s/\(user\s*=\s*\)\(.*\)/\1${_databaseuser}/" ${_etc}/postfix/*.mysql
    sed -i -e "s/\(password\s*=\s*\)\(.*\)/\1${_databasepassword}/" ${_etc}/postfix/*.mysql
    sed -i -e "s/\(dbname\s*=\s*\)\(.*\)/\1${_databasename}/" ${_etc}/postfix/*.mysql
    echo "[DONE] Create Zarafa-Postfixadmin database"

    # super password
    _setup_password=$(< /dev/urandom tr -dc 0-9 | head -c16)$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)
    _setup_password_enc=$(setup_password "${_setup_password}")
    sed -i -e "s/\(setup_password']\s*=\s*\)\(.*\)\(;$\)/\1'${_setup_password_enc}'\3/" ${_config}

    echo
    echo "1.) Please open the setup page. The database is created during opening."
    echo
    echo "   https://HOSTNAME/zarafa-postfixadmin/setup.php"
    echo 
    echo "2.) Create admin account with super password."
    echo
    echo "   Setup password: ${_setup_password}"
    echo
fi
