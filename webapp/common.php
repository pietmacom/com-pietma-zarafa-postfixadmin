<?php
/** 
 * Postfix Admin 
 * 
 * LICENSE 
 * This source file is subject to the GPL license that is bundled with  
 * this package in the file LICENSE.TXT. 
 * 
 * Further details on the project are available at http://postfixadmin.sf.net 
 * 
 * @version $Id: common.php 1792 2015-07-12 12:09:34Z gingerdog $ 
 * @license GNU GPL v2 or later. 
 * 
 * File: common.php
 * All pages should include this file - which itself sets up the necessary
 * environment and ensures other functions are loaded.
 */

if(!defined('POSTFIXADMIN')) { # already defined if called from setup.php
    define('POSTFIXADMIN', 1); # checked in included files

    if (!defined('POSTFIXADMIN_CLI')) {
        // this is the default; see also https://sourceforge.net/p/postfixadmin/bugs/347/
        session_cache_limiter('nocache'); 
        session_start();

        if (defined('POSTFIXADMIN_LOGOUT')) {
            session_unset();
            session_destroy();
            session_start();
        }

        if(empty($_SESSION['flash'])) {
            $_SESSION['flash'] = array();
        }
    }
}

$incpath = dirname(__FILE__);
(ini_get('magic_quotes_gpc') ? ini_set('magic_quotes_runtime', '0') : '1');
(ini_get('magic_quotes_gpc') ? ini_set('magic_quotes_sybase', '0') : '1');

if(ini_get('register_globals') == 'on') {
    die("Please turn off register_globals; edit your php.ini");
}

/**
 * @param string $class
 * __autoload implementation, for use with spl_autoload_register().
 */
function postfixadmin_autoload($class) {
    $PATH = dirname(__FILE__) . '/model/' . $class . '.php';

    if(is_file($PATH)) {
        require_once($PATH);
        return true;
    }
    return false;
}
spl_autoload_register('postfixadmin_autoload');

require_once("$incpath/variables.inc.php");

if(!is_file("$incpath/config.inc.php")) {
    die("config.inc.php is missing!");
}
require_once("$incpath/config.inc.php");

if(isset($CONF['configured'])) {
    if($CONF['configured'] == FALSE) {
        die("Please run the installation script first - /usr/share/doc/kopano-postfixadmin/pietma/install.sh");
        // die("Please edit config.inc.php - change \$CONF['configured'] to true after setting your database settings");
    }
}

Config::write($CONF);

require_once("$incpath/languages/language.php");
require_once("$incpath/functions.inc.php");

if (defined('POSTFIXADMIN_CLI')) {
    $language = 'en'; # TODO: make configurable or autodetect from locale settings
} else {
    $language = check_language (); # TODO: storing the language only at login instead of calling check_language() on every page would save some processor cycles ;-)
    $_SESSION['lang'] = $language;
}

require_once("$incpath/languages/" . $language . ".lang");

if(!empty($CONF['language_hook']) && function_exists($CONF['language_hook'])) {
    $hook_func = $CONF['language_hook'];
    $PALANG = $hook_func ($PALANG, $language);
}

Config::write('__LANG', $PALANG);


if (!defined('POSTFIXADMIN_CLI')) {
    if(!is_file("$incpath/smarty.inc.php")) {
        die("smarty.inc.php is missing! Something is wrong...");
    }
    require_once ("$incpath/smarty.inc.php");
}
/* vim: set expandtab softtabstop=4 tabstop=4 shiftwidth=4: */
?>
