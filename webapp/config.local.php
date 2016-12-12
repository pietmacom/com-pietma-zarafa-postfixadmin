<?php

/* 
 * THIS FILE CONTAINS COSTUMIZATIONS TO POSTFIXADMIN
 *
 * See https://git.pietma.com/pietma/com-pietma-zarafa-postfixadmin
 */

$CONF['generate_password'] = 'YES';
$CONF['sendmail'] = 'NO';
$CONF['fetchmail'] = 'YES';

function domain_struct_admin_modify($struct) {
    $struct['default_aliases']['display_in_form'] = 0;
    $struct['default_aliases']['default'] = 0;
    $struct['backupmx']['display_in_form'] = 0;
    $struct['backupmx']['default'] = 0;
    return $struct;
}
$CONF['domain_struct_hook'] = 'domain_struct_admin_modify';

function mailbox_struct_admin_modify($struct) {
    $struct['welcome_mail']['display_in_form'] = 0;
    $struct['welcome_mail']['default'] = 0;

    # type=text stores initial password in cleartext
    $struct['password']['display_in_form'] = 1;
    $struct['password']['type'] = 'text';

    $struct['password2']['display_in_form'] = 1;    
    $struct['password2']['type'] = 'text';    
    
    $struct['quota']['display_in_form'] = 0;        
    
    #$struct['x_admin'] = pacol(   1,          1,      1,      'bool', 'active'                        , ''                                 , 1 );
    
    return $struct;
}
$CONF['mailbox_struct_hook'] = 'mailbox_struct_admin_modify';

function fetchmail_struct_admin_modify($struct) {
    $struct['dst_server']    = pacol(   1,          1,      1,      'text', 'pFetchmail_field_dst_server'   , 'pFetchmail_desc_dst_server'      );
    $struct['dst_address']    = pacol(   1,          1,      1,      'text', 'pFetchmail_field_dst_address'   , 'pFetchmail_desc_dst_address'      );    
    return $struct;
}
$CONF['fetchmail_struct_hook'] = 'fetchmail_struct_admin_modify';


function language_hook($PALANG, $language) {
    switch ($language) {
        default:
            $PALANG['pCreate_mailbox_password_text'] = 'Initial password (transferred / generated when empty). Please change in Zarafa!';

            $PALANG['pFetchmail_field_src_server'] = 'Inbound Server';
            $PALANG['pFetchmail_desc_src_server'] = 'POP/IMAP Server';

            $PALANG['pFetchmail_field_dst_server'] = 'Outbound Server';
            $PALANG['pFetchmail_desc_dst_server'] = 'SMTP Server';

            $PALANG['pFetchmail_field_dst_address'] = 'Outbound Address';
            $PALANG['pFetchmail_desc_dst_address'] = 'E-Mail Address';
    }

    return $PALANG;
}
$CONF['language_hook'] = 'language_hook';


// LOAD SETTINGS
if (file_exists('/etc/webapps/zarafa-postfixadmin/config.local.php')) {
    include('/etc/webapps/zarafa-postfixadmin/config.local.php');
}

?>
