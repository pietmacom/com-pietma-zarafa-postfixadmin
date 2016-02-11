<?php

/* 
 * DON'T MAKE CHANGES TO THIS FILE!
 */

$CONF['generate_password'] = 'YES';
$CONF['sendmail'] = 'NO';
$CONF['fetchmail'] = 'NO';

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

function language_hook($PALANG, $language) {
    switch ($language) {
        default:
            $PALANG['pCreate_mailbox_password_text'] = 'Initial password (generated when empty). Please change in Zarafa!';
    }

    return $PALANG;
}
$CONF['language_hook'] = 'language_hook';

?>
