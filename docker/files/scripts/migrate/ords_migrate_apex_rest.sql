Rem  Copyright (c) Oracle Corporation 2014. All Rights Reserved.
Rem
Rem    NAME
Rem      ords_migrate_apex_rest.sql
Rem
Rem    DESCRIPTION
Rem      This script migrates Application Express RESTful Services data 
Rem      (from release 4.2.x or later) to Oracle REST Data Services (ORDS).    
Rem      Do not invoke this script directly.  
Rem      If you are doing a manual migration, use ords_manual_migrate.sql
Rem
Rem    NOTES
Rem      Assumes user with SYSDBA privilege is connected.
Rem
Rem    REQUIREMENTS
Rem      - Oracle Database 11.1 or later
Rem      - Application Express 4.2.x onwards
Rem
Rem    Arguments:
Rem      None
Rem
Rem    MODIFIED    (MM/DD/YYYY)
Rem     epaglina    07/25/2014 - Created.
Rem
Rem

--set serveroutput on

set autocommit off

whenever sqlerror exit sql.sqlcode rollback

begin
  sys.dbms_output.put_line('INFO: ' || to_char(sysdate,'HH24:MI:SS') || ' Migrating APEX RESTful Services definitions to Oracle REST Data Services.');
    ords_metadata.ords_migrate.migrate_apex_restful_services;
  sys.dbms_output.put_line('INFO: ' || to_char(sysdate,'HH24:MI:SS') || ' Completed migrating APEX RESTful Services definitions.');
end;
/
