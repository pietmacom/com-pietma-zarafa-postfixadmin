#!/bin/bash -e

_basedir="$(dirname $0)"
_etc="/etc/webapps/kopano-postfixadmin"
_databasename="kopanopostfixadmin"
_databaseuser="kopanopostfixadmin"

function setup_password() {
	local _salt=$(date +%s)"*127.0.0.1*"$(shuf -i 0-60000 -n 1)
	local _salt=$(echo -n "${_salt}" | md5sum | cut -f1 -d' ')
	echo -n "${_salt}:"$(echo -n "${_salt}:$1" | sha1sum | cut -f1 -d' ')
}

function credentials() {
	local _etc="$1"
	local _databaseuser="$2"
	local _databasepassword="$3"
	local _databasename="$4"

	echo "[....] Set credentials"	
	# kopano postfixadmin config
	sed -i -e "s/\(configured']\s*=\s*\)\(.*\)\(;$\)/\1true\3/" ${_etc}/config.local.php
	sed -i -e "s/\(database_type']\s*=\s*\)\(.*\)\(;$\)/\1'mysqli'\3/" ${_etc}/config.local.php
	sed -i -e "s/\(database_host']\s*=\s*\)\(.*\)\(;$\)/\1'localhost'\3/" ${_etc}/config.local.php
	sed -i -e "s/\(database_user']\s*=\s*\)\(.*\)\(;$\)/\1'${_databaseuser}'\3/" ${_etc}/config.local.php
	sed -i -e "s/\(database_password']\s*=\s*\)\(.*\)\(;$\)/\1'${_databasepassword}'\3/" ${_etc}/config.local.php
	sed -i -e "s/\(database_name']\s*=\s*\)\(.*\)\(;$\)/\1'${_databasename}'\3/" ${_etc}/config.local.php

	# fetchmail
	sed -i -e "s/\(db_username\s*=\s*\)\(.*\)\(;$\)/\1'${_databaseuser}'\3/" ${_etc}/fetchmail.conf
	sed -i -e "s/\(db_password\s*=\s*\)\(.*\)\(;$\)/\1'${_databasepassword}'\3/" ${_etc}/fetchmail.conf    
	sed -i -e "s/\(db_name\s*=\s*\)\(.*\)\(;$\)/\1'${_databasename}'\3/" ${_etc}/fetchmail.conf    

	# postfix scripts
	sed -i -e "s/\(user\s*=\s*\)\(.*\)/\1${_databaseuser}/" ${_etc}/postfix/*.mysql
	sed -i -e "s/\(password\s*=\s*\)\(.*\)/\1${_databasepassword}/" ${_etc}/postfix/*.mysql
	sed -i -e "s/\(dbname\s*=\s*\)\(.*\)/\1${_databasename}/" ${_etc}/postfix/*.mysql
	echo "[DONE] Set credentials"
}

echo
read -p ":: Copy and override POSTFIX (extended) settings? [Y/n]" _response
echo
echo
if [[ "${_response,,}" = "y" ]];
then
    echo "[....] Copy and override POSTFIX (extended) settings"
    cp -rf ${_basedir}/configs/postfix /etc
    echo "[DONE] Copy and override POSTFIX (extended) settings"
fi

echo
read -s -p ":: Please enter MySQL Root Password (or empty)" _mysqlpassword
echo
echo
if [[ -z ${_mysqlpassword} ]];
then
    echo "Continue without password"
    mysql="mysql -uroot"
else
    mysql="mysql -uroot -p${_mysqlpassword}"
fi
mysqlexec="${mysql} -s -N -e"


if [[ -z $($mysqlexec "show databases like '${_databasename}';") ]];
then
    echo "[....] Create Kopano-Postfixadmin database"
    _databasepassword=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)
    if [[ -z $($mysqlexec "use mysql; select * from user where user ='${_databaseuser}';") ]];
    then
		$mysqlexec "CREATE USER '${_databaseuser}'@'localhost' IDENTIFIED BY '${_databasepassword}';"
    else
		$mysqlexec "SET PASSWORD FOR '${_databaseuser}'@'localhost' = PASSWORD('${_databasepassword}');"
    fi
    $mysqlexec "CREATE DATABASE ${_databasename} CHARACTER SET latin1;"
    $mysqlexec "GRANT ALL PRIVILEGES ON ${_databasename} . * TO '${_databaseuser}'@'localhost';"
    echo "[DONE] Create Kopano-Postfixadmin database"
    
    credentials "${_etc}" "${_databaseuser}" "${_databasepassword}" "${_databasename}"

    # setup.php => create tables
    echo "[....] Install database tables (this will take a while ~1min)"
    if _setup_output=$(lynx -image_links -nolist -nonumbers -hiddenlinks=ignore --dump https://localhost/kopano-postfixadmin/setup.php) ;
    then
		_setup_done="1"
		echo "${_setup_output}"
		echo "[DONE] Install database tables"
	
		# start services
		echo
		read -p ":: Enable and start services KOPANO-POSTFIXADMIN, FETCHMAIL-POSTFIXADMIN, POSTFIX [Y/n] " _response
		echo
		if [[ "${_response,,}" = "y" ]];
		then
			echo "[....] Enable and start services"
			systemctl enable kopano-postfixadmin
			systemctl enable fetchmail-postfixadmin.timer
			systemctl enable postfix

			systemctl start kopano-postfixadmin
			systemctl start fetchmail-postfixadmin.timer
			systemctl start postfix

			postfix reload
			echo "[DONE] Enable and start services"
		else
			echo "[SKIP] Enable and start services"
		fi

		# import kopano users
		echo
		read -p ":: Import Kopano users [Y/n] " _response
		echo
		if [[ "${_response,,}" = "y" ]];
		then
			echo "[....] Import Kopano users"
			$mysql < ${_basedir}/import-from-kopano.sql
			echo "[DONE] Import Kopano users"
		else
			echo "[SKIP] Import Kopano users"
		fi
    else
		_setup_done="0"
		echo "[SKIP] Install database tables - Could not open https://localhost/kopano-postfixadmin/setup.php"
    fi

    # super password
    _setup_password=$(< /dev/urandom tr -dc 0-9 | head -c16)$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)
    _setup_password_enc=$(setup_password "${_setup_password}")
    sed -i -e "s/\(setup_password']\s*=\s*\)\(.*\)\(;$\)/\1'${_setup_password_enc}'\3/" ${_etc}/config.local.php

    echo
    echo "1.) Please open the setup page. The database is created during opening."
    echo
    echo "   https://HOSTNAME/kopano-postfixadmin/setup.php"
    echo 
    echo "2.) Create admin account with super password and write it down."
    echo
    echo "   Setup password: ${_setup_password}"
    echo
    if [[ "${_setup_done}" == "0" ]];
    then
		echo "3.) Enable, start services and reload postfix configs."
		echo
		echo "   $ systemctl enable kopano-postfixadmin"
		echo "   $ systemctl start kopano-postfixadmin"
		echo
		echo "   $ systemctl enable fetchmail-postfixadmin.timer"
		echo "   $ systemctl start fetchmail-postfixadmin.timer"
		echo
		echo "   $ systemctl enable postfix"
		echo "   $ systemctl start postfix"
		echo
		echo "   $ postfix reload"
		echo
    fi
    
    echo "Read More"
    echo
    echo "   https://wiki.archlinux.org/index.php/MySQL"
    echo "   https://pietma.com/install-run-and-access-kopano-postfix-admin/"
    echo
else
    echo "[SKIP] Install database  - Database found"

    source /usr/share/kopano-postfixadmin/config-postfix
    credentials "${_etc}" "${_database_user}" "${_database_password}" "${_database_name}"    
fi
