Rem  Copyright (c) Oracle Corporation 2014. All Rights Reserved.
Rem
Rem    NAME
Rem      ords_manual_migrate_workspace.sql
Rem
Rem    DESCRIPTION
Rem      This script performs a manual migration for Application Express (APEX) Workspace 
Rem      Restful Services to Oracle REST Data Services (ORDS).
Rem
Rem    NOTES
Rem      Assumes user with SYSDBA privilege is connected.
Rem
Rem    REQUIREMENTS
Rem      - Oracle Database 11.1 or later
Rem      - Application Express 4.2.x onwards
Rem
Rem    Arguments:
Rem      1  : Path of log file (include the forward slash at the end)
Rem
Rem    Example:
Rem      sqlplus "sys as sysdba" @ords_manual_migrate_workspace d:/log/scripts/ A_WORKSPACE
Rem
Rem
Rem    MODIFIED    (MM/DD/YYYY)
Rem     dwhittin    02/11/2022 Created.
Rem
Rem

set serveroutput on
timing start "ORDS Migration"

set verify off
set termout off
spool off

set define '^'
set termout on

define LOGFOLDER    = '^1'
define WORKSPACE    = '^2'

whenever sqlerror exit

column logfilename new_val ORDSLOGFILE
select '^LOGFOLDER' || 'ordsmigrate_' || to_char(sysdate,'YYYY-MM-DD_HH24_MI_SS') || '.log' as logfilename from sys.dual;
spool ^ORDSLOGFILE


prompt ******************************************************
prompt * INFO: Oracle REST Data Services (ORDS) Migration.
prompt ******************************************************

prompt * INFO: Migrating APEX Restful Services data to ORDS
@@ords_migrate_workspace_rest.sql ^WORKSPACE

commit;

prompt
prompt *********************************************************
prompt INFO: Completed Oracle REST Data Services Migration.
timing stop
prompt *********************************************************

spool off

exit
