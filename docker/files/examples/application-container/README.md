# Introduction

Oracle REST Data Services can be installed or upgraded into an application container using the ORDS sql scripts provided in the ords-*<version>*.zip file.

An application container consists of an application root where the application is defined and one or more PDBs that share the metadata about the application from the application root. You can have multiple application containers within a CDB and each container can have a different version of Oracle REST Data Services.

Installing and upgrading Oracle REST Data Services in an application container are done against the application root container. When an application PDB wishes to uptake the upgraded version, it simply syncs with the application root. Oracle REST Data Services continues to run in the application PDB at the existing version until the application PDB syncs with the application root.


# Download:

ORDS version 20.2.0 or later.

https://www.oracle.com/database/technologies/appdev/rest-data-services-downloads.html


# ORDS SQL scripts  

The ORDS sql scripts are located in the "scripts" folder.  The scripts folders contain subdirectories for the install, upgrade, validate and uninstall sql scripts.

You can run these sql scripts in SQLcl, SQL*Plus or SQL Developer.

To obtain the ORDS sql scripts, do the following:

    unzip ords-<version>.zip ords.war
    
    unzip ords.war 'WEB-INF/lib/ords-installer-*.jar'
    
    unzip  'WEB-INF/lib/ords-installer-*.jar' 'db/*'
    
    mv db scripts


# Creating Application Container

To create an Application Container:

1. Ensure that the current container is CDB$ROOT.
2. Use the **AS APPLICATION CONTAINER** clause of the CREATE PLUGGABLE DATABASE statement to create an application container.
3. Open the application container.

Note: `ords_app_root1` and the `admin` user in the following example can be any valid Oracle identifier.
    
Example:

    CREATE PLUGGABLE DATABASE ords_app_root1 AS APPLICATION CONTAINER ADMIN USER admin IDENTIFIED BY <admin_password> FILE_NAME_CONVERT=('pdbseed', 'ords_app_root1');
    
    ALTER PLUGGABLE DATABASE ords_app_root1 OPEN;

See Oracle documentation ["Creating Application Containers"](https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/creating-removing-application-containers-seeds-with-sql-plus.html#GUID-20B0B12F-A6A5-4403-95FF-64B3A5CC00A9) for additional information.


# Installing Oracle REST Data Services in the Application Container

To install Oracle REST Data Services in an Application Container:

1. Connect to the Application Container.
2. Run /path/to/scripts/install/core/ords\_app\_con_install.sql with the following parameters:    

> Parameters:
>
>1. Log folder (must include the forward slash at the end)
>2. Default tablespace for ORDS schema
>3. Temporary tablespace for ORDS schema
>4. Default tablespace for ORDS proxy user
>5. Temporary tablespace for ORDS proxy user
>6. ORDS proxy user password
>7. Scripts path (requires the fully qualified path to the ORDS scripts)

Note: The tablespaces must already exist in the database.

Example:

    ALTER SESSION SET CONTAINER = ords_app_root1;
    
    @/path/to/scripts/install/core/ords_app_con_install.sql  /path/to/logs/ SYSAUX TEMP SYSAUX TEMP P033w0r6! /path/to/scripts

Refer to "Verifying Oracle REST Data Services in the Application Container" to check the ORDS installation.

The ords\_app\_con_install.sql will create an application named ORDS and set the application version to the ORDS product version.  The product version format is Year.Quarter.Patch.rJulianDay24HRMM (e.g., 20.2.0.r1801800). 

The script will install ORDS and create the ORDS schema (ORDS\_METADATA), create the ORDS proxy user (ORDS\_PUBLIC_USER), and create related database objects in the application container.  


# Creating an Application Seed

An application seed is used to provision application PDBs with the application root's applications pre-installed.

To create an Application Seed:

1. Ensure that the current container is the CDB$ROOT.
2. Alter session and set container to the application root.
3. Use the **AS SEED** clause of the **CREATE PLUGGABLE DATABASE** statement to create an application seed.
4. Sync the ORDS application with the application seed.
5. Compile invalid objects.
6. Open the application seed in read only mode.

Note: `ords_app_root1` and the `admin` user in the following example can be any valid Oracle identifier.

Example:

    ALTER SESSION SET CONTAINER = ords_app_root1;
    
    CREATE PLUGGABLE DATABASE AS SEED ADMIN USER admin IDENTIFIED BY <admin_password> FILE_NAME_CONVERT=('pdbseed', 'ords_app_root1_seed');
    
    ALTER PLUGGABLE DATABASE ords_app_root1$seed open;
    
    ALTER SESSION SET CONTAINER = ords_app_root1$seed;
    
    ALTER PLUGGABLE DATABASE application ORDS sync;
    
    begin
      sys.dbms_utility.compile_schema('ORDS_METADATA', FALSE);
    end;
    /
    
    ALTER PLUGGABLE DATABASE ords_app_root1$seed close immediate;
    
    ALTER PLUGGABLE DATABASE ords_app_root1$seed open read only;

See Oracle documentation ["Creating Application Containers"](https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/creating-removing-application-containers-seeds-with-sql-plus.html#GUID-20B0B12F-A6A5-4403-95FF-64B3A5CC00A9) for additional information.


# Creating an Application PDB from the Application Root Seed

An application PDB is created by issuing the CREATE PLUGGABLE DATABASE statement from the application root.

The PLUGGABLE DATABASE is created from the application container seed so the ORDS application is already installed and ready for configuration.

To create an Application PDB from the Application Root Seed:

1. Ensure that the current container is CDB$ROOT.
2. Alter session and set container to the application root.
3. Use the CREATE PLUGGABLE DATABASE command to create a PDB from the application seed.

Note: `ords_app_pdb1` and the `admin` user in the following example can be any valid Oracle identifier.


Example:

    ALTER SESSION SET CONTAINER=ords_app_root1;
    
    CREATE PLUGGABLE DATABASE ords_app_pdb1 ADMIN USER admin IDENTIFIED BY <admin password> FILE_NAME_CONVERT=('ords_app_root1_seed','ords_app_pdb1');
    
    ALTER PLUGGABLE DATABASE ords_app_pdb1 OPEN;
    
    ALTER SESSION SET CONTAINER = ords_app_pdb1;
    
    select app_name, app_version, app_status from dba_applications where app_name = 'ORDS';
    
    APP_NAME     APP_VERSION         APP_STATUS
    --------     ---------------     ------------
    ORDS         20.2.0.r1801800     NORMAL


See Oracle documentation ["Creating Application Containers"](https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/creating-removing-application-containers-seeds-with-sql-plus.html#GUID-20B0B12F-A6A5-4403-95FF-64B3A5CC00A9) for additional information.


# ORDS Configuration Files

## Create the ORDS configuration folder

The configuration folder will contain the ORDS configuration files.  If the configuration folder is undefined,  you will be prompted for the configuration folder when you execute the setup command.  Specify the location for your ORDS configuration files.

    java -jar ords.war configdir /path/to/config


## Create the ORDS configuration files for Application Root Container

Execute the setup command to create the configuration files.  The `--configOnly` option must be specified to only create the configuration files.  When prompted for the service name, specify the Application PDB servicename.

    java -jar ords.war setup --configOnly


Example 1 - Configuring ORDS for Application Express

    java -jar ords.war setup --configOnly
    
    Specify the database connection type to use.
    Enter number for [1] Basic  [2] TNS  [3] Custom URL [1]:
    Enter the name of the database server [localhost]:
    Enter the database listen port [1521]:
    Enter 1 to specify the database service name, or 2 to specify the database SID [1]:
    Enter the database service name: ords_app_root1
    Enter the database password for ORDS_PUBLIC_USER:
    Confirm password:
    Enter 1 if you want to use PL/SQL Gateway or 2 to skip this step.
    If using Oracle Application Express or migrating from mod_plsql then you must enter 1 [1]:   
    Enter the PL/SQL Gateway database user name [APEX_PUBLIC_USER]:
    Enter the database password for APEX_PUBLIC_USER:
    Confirm password:
    Enter 1 to specify passwords for Application Express RESTful Services database users (APEX_LISTENER, APEX_REST_PUBLIC_USER) or 2 to skip this step [1]:
    Enter the database password for APEX_LISTENER:
    Confirm password:
    Enter the database password for APEX_REST_PUBLIC_USER:
    Confirm password:
    Enter a number to select a feature to enable [1] SQL Developer Web [2] REST Enabled SQL [3] None [1]:


Example 2 - Configuring ORDS only

    java -jar ords.war setup --configOnly
    
    Specify the database connection type to use.
    Enter number for [1] Basic  [2] TNS  [3] Custom URL [1]:
    Enter the name of the database server [localhost]:
    Enter the database listen port [1521]:
    Enter 1 to specify the database service name, or 2 to specify the database SID [1]:
    Enter the database service name: ords_app_root1
    Enter the database password for ORDS_PUBLIC_USER:
    Confirm password:
    Enter 1 if you want to use PL/SQL Gateway or 2 to skip this step.
    If using Oracle Application Express or migrating from mod_plsql then you must enter 1 [1]:2
    Enter a number to select a feature to enable [1] SQL Developer Web [2] REST Enabled SQL [3] None [1]:

## Making All PDBs Addressable by Oracle REST Data Services (Pluggable Mapping)

Refer to the documentation below on how to make all Application PDBs in a Application Root Container addressable by Oracle REST Data Services.
This step is required for starting ORDS from the Application Root container.

See documentation to setup the db.serviceNameSuffix parameter in your ords configuration file:
https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/19.4/aelig/configuring-REST-data-services.html#GUID-694B2F89-CE4F-4AB0-88E2-EB35D03DEC3C

The value of the db.serviceNameSuffix parameter must match the value of the DB_DOMAIN database initialization parameter, and it must start with a period (.). 

Example in /path/to/config/ords/defaults.xml:

    <entry key="db.serviceNameSuffix">.example.com</entry>

If your DB_DOMAIN is empty, then the db.serviceNameSuffix parameter must contain an empty value.

Example:

    <entry key="db.serviceNameSuffix"></entry>

# Running ORDS in Standalone Mode

To run ORDS in standalone mode, execute the standalone command.  The standalone command will prompt you for information the first time you run in standalone mode.  

    java -jar ords.war standalone


See [ORDS documentation](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services) for information on using Standalone Mode or deploying ORDS to Oracle WebLogic Server or Apache Tomcat.


## Upgrading Oracle REST Data Services in the Application Container

Prerequisite
- ORDS must already be installed in the application container
- Upgrading ORDS from an earlier release to a new release (e.g., ords release 20.2.x.x to 20.3.x.x)

To upgrade Oracle REST Data Services in an Application Container:

1. Connect to the Application Container.
2. Run /path/to/scripts/upgrade/ords\_app\_con_upgrade.sql with the following parameters:


> Parameters:
>
> 1. Log folder (must include the forward slash at the end)
> 2. Scripts path (requires the fully qualified path to the ORDS scripts)

Example:

    ALTER SESSION SET CONTAINER = ords_app_root1;
    
    @/path/to/scripts/upgrade/ords_app_con_upgrade.sql  /path/to/logs/ /path/to/scripts


Refer to "Verifying Oracle REST Data Services in the Application Container" to check the ORDS upgrade.

The ords\_app\_con_upgrade.sql will upgrade ORDS in the application container to the release that you are using.  For example, if the ORDS application version is 20.2.0.r1801800, and the ORDS upgrade script is 20.3.0.r2601900, then the script will upgrade ORDS to release 20.3.0.r2601900 in the application container.


# Validating Oracle REST Data Services in the Application Container

To repair Oracle REST Data Services in an Application Container:

1. Connect to the Application Container.
2. Run /path/to/scripts/validate/core/ords\_app\_con_validate.sql with the following parameters:

> Parameters:

> 1. Log folder (must include the forward slash at the end)
> 2. Scripts path (requires the fully qualified path to the ORDS scripts)

Example:

    ALTER SESSION SET CONTAINER = ords_app_root1;
    
    @/path/to/scripts/validate/core/ords_app_con_validate.sql  /path/to/logs/ /path/to/scripts


Refer to "Verifying Oracle REST Data Services in the Application Container" to check the ORDS validate.

The ords\_app\_con\_validate.sql will set the application version to the ORDS product version with suffix "\_v_YYMMDD24HRMISS". 

Example:

> Year.Quarter.Patch.rJulianDay24MI\_v\_YYMMDD24HRMISS

> 20.2.0.r1801800\_v_200705160015


# Uninstalling Oracle REST Data Services in the Application Container

To uninstall Oracle REST Data Services in an Application Container:

1. Connect to the Application Container.
2. Run /path/to/scripts/uninstall/core/ords\_app\_con_uinstall.sql with the following parameters:

Parameters:

> 1. Log folder (must include the forward slash at the end)
> 2. Scripts path (requires the fully qualified path to the ORDS scripts)

Example:

    ALTER SESSION SET CONTAINER = ords_app_root1;
    
    @/path/to/scripts/uninstall/core/ords_app_con_uninstall.sql  /path/to/logs/ /path/to/scripts


Refer to "Verifying Oracle REST Data Services in the Application Container" to check that ORDS is uninstalled.


# Verifying Oracle REST Data Services in the Application Container

To verify the Oracle REST Data Services install, upgrade, validate and uninstall in the Application Container:

1. Manually inspect the log files for any errors:


- Install - ordsinstall_<timestamp>.log
- Upgrade - ordsupgrade_<timestamp>.log
- Validate - ordsvalidate_<timestamp>.log
- Uninstall - ordsuninstall_<timestamp>.log


2. Query dba_applications to verify that the ORDS application exist and its application version is the same as the ORDS product version.

    SQL> select app_name, app_version, app_status from dba_applications where app_name = 'ORDS';
    
    APP_NAME     APP_VERSION         APP_STATUS
    --------     ---------------     ------------
    ORDS         20.2.0.r1801800     NORMAL

3. Query dba\_app_errors to check for any errors.

    SQL> select app_name, app_statement, errornum, errormsg from dba_app_errors where app_name = 'ORDS';
    no rows selected


Note:  If uninstalling ORDS in the application container, the APP_STATUS will contain the value UNINSTALLED.
