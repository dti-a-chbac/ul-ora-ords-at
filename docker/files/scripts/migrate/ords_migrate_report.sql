Rem  Copyright (c) Oracle Corporation 2014. All Rights Reserved.
Rem
Rem    NAME
Rem      ords_migrate_report.sql
Rem
Rem    DESCRIPTION
Rem      This script reports on Application Express (APEX) Workspace Restful Services
Rem      not yet migrated to Oracle REST Data Services (ORDS).
Rem
Rem    NOTES
Rem      Assumes user with SYSDBA privilege is connected.
Rem
Rem    REQUIREMENTS
Rem      - Oracle Database 11.1 or later
Rem      - Application Express 4.2.x onwards
Rem      - select any table privilege
Rem
Rem    Arguments:
Rem      None
Rem
Rem    MODIFIED    (MM/DD/YYYY)
Rem     dwhittin    02/11/2022 - Created.
Rem
Rem

set termout off
set autocommit off
set verify off
set define '^'
set serveroutput off

whenever sqlerror exit sql.sqlcode rollback

COLUMN :v_apex_installed NEW_VALUE ORDS_APEX_INSTALLED NOPRINT
VARIABLE v_apex_installed VARCHAR2(2000)
COLUMN :v_apex_modules NEW_VALUE ORDS_APEX_MODULES NOPRINT
VARIABLE v_apex_modules VARCHAR2(2000)

-- Lookup APEX schema name and version
declare
  l_schema  VARCHAR(255);
  l_version VARCHAR(255);
  l_status  VARCHAR(255);
  l_ver_no  NUMBER;

  l_migrate_modules_1 VARCHAR2(255) := 
    '
      c.short_name workspace, 
      nvl2(w.schema_id,''YES'',''NO'') migrated,
      count(m.name) module_count
    from 
    ';
  
   l_migrate_modules_2 VARCHAR(500) :=
    '
       ords_metadata.ords_workspace_schemas w
    where 
          c.provisioning_company_id NOT IN (10,11,12) 
      and m.security_group_id = w.workspace_id(+) 
      and m.name NOT IN (''oracle.apex.friendly_url'',''oracle.example.hr'') 
      and m.security_group_id = c.provisioning_company_id 
    group by c.short_name, w.schema_id
    order by migrated, workspace
    ';

  l_null_query VARCHAR2(255) := '''no rows selected'' workspace, null migrated, null modules from dual';
begin
  begin
    l_schema := ords_metadata.ords_migrate.get_apex_schema(
                        p_version => l_version,
                        p_status  => l_status);

   if l_schema is not null then
     if l_version is not null then
       l_ver_no  := to_number(substr(l_version,1, instr(l_version, '.') - 1));

       if l_ver_no < 5 and l_version NOT LIKE '4.2.%' then
         l_status := 'NOT SUPPORTED';
       end if;
     end if;
   else
     l_status := 'NOT AVAILABLE';
   end if;
  exception
    when others then
       l_schema := SQLERRM;
       l_version := SQLCODE;
       l_status := 'ERROR';
  end;

  :v_apex_installed := sys.dbms_assert.enquote_literal(l_schema)  || ' apex_schema, ' ||
                       'nvl(' || sys.dbms_assert.enquote_literal(l_version) || ',''UNKNOWN'')' || ' apex_version, ' ||
                       'nvl(' || sys.dbms_assert.enquote_literal(l_status) || ',''UNKNOWN'')' || ' apex_status from dual';

  if l_status IS NOT NULL AND l_status NOT IN ('VALID') then
    :v_apex_modules := l_null_query;
  else
    :v_apex_modules := l_migrate_modules_1 ||
                       sys.dbms_assert.schema_name(l_schema) || '.wwv_flow_companies c, ' ||
                       sys.dbms_assert.schema_name(l_schema) || '.wwv_flow_rt$modules m, ' ||
                       l_migrate_modules_2;
  end if;
  
end;
/

select :v_apex_installed from dual;
select :v_apex_modules   from dual;

COLUMN workspace      HEADING 'WORKSPACE NAME'
COLUMN migrated       HEADING 'MIGRATED' 
COLUMN module_count   HEADING 'MODULES' 
COLUMN workspace      format   a63
COLUMN migrated       format   a8
COLUMN module_count   format   999999

COLUMN apex_schema    HEADING 'APEX SCHEMA'
COLUMN apex_version   HEADING 'APEX VERSION' 
COLUMN apex_status    HEADING 'APEX STATUS' 
COLUMN apex_schema    format    a48
COLUMN apex_version   format    a15
COLUMN apex_status    format    a15

set termout on

select ^ORDS_APEX_INSTALLED;

select ^ORDS_APEX_MODULES;
