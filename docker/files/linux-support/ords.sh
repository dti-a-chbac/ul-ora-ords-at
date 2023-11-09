#!/bin/bash

#
# Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#        ords - ORDS standalone server manager 1.5.2
#
#    DESCRIPTION
#        Starts, stops and restarts, among other things, an ORDS standalone
#        server. This script is also capable of reporting certain ORDS
#        settings from the ords.war file, to review the logs generated in
#        real time and to provide information about the server's process and
#        the actual Operating System service
#
#    NOTES
#        This is a generic ORDS standalone management script designed to work
#        as an Operating System service on Oracle Enterprise Linux 6 and 7.
#        Once placed next to the ords.war file, you can create a symbolic link
#        that points this script's absolute path in '/etc/init.d/ords' and
#        either call 'chkconfig --add ords' to add it as a system service that
#        starts automatically with an OEL 6 environment or copy the
#        ords.service file located in the same directory as this script to
#        '/etc/systemd/system/ords.service' and call 'systemctl enable ords'
#        to enable the system service auto-start in an OEL 7 environment.
#        To manage the service use 'service ords <COMMAND>' in an OEL 6
#        environment or 'systemctl <COMMAND> ords' in an OEL 7 environment
#        where <COMMAND> is one of start, status, stop or restart
#
#    CHANGE LOG
#        MODIFIED    VERSION    (MM/DD/YY)
#        admuro      1.5.2      18/01/22 - Modify scrtpt to rok with ords CLI 
#                                          bin/ords
#        admuro      1.5.1      08/08/19 - Modify scrip to work with RPM standalone
#                                          version
#                                        - Added config path validation and configure
#                                          the config dir in to the ords war file.
#                                        - Change config file path, logs path and
#                                          ords base path  to match linux stadars.
#                                        - Remove ORDS_OWNER and load variables from
#                                          config file.
#                                        - Log file is not truncated every time start
#                                          option is selected.
#                                        - Changed function to read JAVA_HOME JAVA_OPTIONS
#                                          and CONFIG from config file and make values
#                                          overwrite environment variables if exist.
#                                        - Modify the grep command to read variables
#                                          from config file to skip comments in the same
#                                          variable line.
#                                        - Fix issue realted with version and configdir
#                                          option.
#        mimisanc    1.5.0      11/26/18 - Added the basedir|base_directory
#                                          options to find out which ords.war
#                                          and ords.config files are being used
#                                          by the script
#                                        - Added the configuration_directory
#                                          alias to the configdir option
#                                        - Added logdir|log_directory,
#                                          and log_file options to get
#                                          information about the log files'
#                                          location
#                                        - Added check of PID file permissions
#                                          and a warning
#                                        - Added -v|--version and -h|--help
#                                          options
#        mimisanc    1.4.1      11/08/18 - Changed the service configuration
#                                          file name to something related to
#                                          the script
#        mimisanc    1.4.0      11/05/18 - Added PID file
#                                        - Added pid and pid_file commands
#                                        - Fixed a bug that prevented the
#                                          script to work when called with the
#                                          service command
#        mimisanc    1.3.1      11/04/18 - Fixed a bug when the service
#                                          configuration JAVA_OPTIONS were
#                                          empty
#        mimisanc    1.3.0      10/01/18 - Added handling for the
#                                          ORDS_CONFIG parameter
#        mimisanc    1.2.0      09/29/18 - Added configdir command
#                                        - Fixed hardcoder owner oracle
#                                        - Fixed last login issues
#                                        - Added version to the script comments
#                                        - Added get_ords_information function
#                                        - Added execute_script function
#                                        - Added get_ords_bound_ports
#                                        - Added port binding information to
#                                          status start and restart calls
#        mimisanc    1.1.0      07/03/18 - Added Service Configuration
#                                          Parameters ORDS_OWNER, JAVA_BASE and
#                                          JAVA_OPTIONS
#                                        - Changed how ORDS version string is
#                                          obtained
#                                        - Made code format bashate compliant
#                                        - Removed Database dependency from
#                                          start function
#        mimisanc    1.0.0      02/14/18 - Created
#
# TODO: Fix an issue when no ords configuration file is present and a query
#       to the war file is made
# TODO: Print the PID warning only if we detect we're in OEL7
# TODO: Change the PID file location to just /run/ords.pid
# TODO: Made the script able to support multiple ORDS instances
# TODO: Make the script Mac/launchd compatible (Maybe a pkg or homebrew
#       bundle even)

# Defining script information in here so it is not easy to forget updating it
script_name='ords.sh'
script_human_readable_name='ORDS standalone server manager'
script_version='1.5.1'
script_description="$( cat <<-DESCRIPTION
	Starts, stops and restarts, among other things, an ORDS standalone
	server. This script is also capable of reporting certain ORDS
	settings from the ords.war file, to review the logs generated in
	real time and to provide information about the servers process
	and the actual Operating System service
DESCRIPTION
)"

# chkconfig: 35 99 98
# pidfile: /var/run/ords/pid
# description: Oracle REST Data Services

# The default OS user that will run ORDS. Note that only root and the user
# with the name contained in this variable will be able to start the service
# If the service is started by root, then it will switch users and start the
# service as the user name set in this variable.
ords_owner='oracle'
ords_configuration_file_name='ords.conf'
ords_configuration_file="/etc"'/'"$ords_configuration_file_name"
# Get ords_base_path
# This variable is obtained from rpm installed information
# but if was installed by zip file is necesary to set on /etc/ords.conf
rpm -qa | grep -w ords > /dev/null
_installed=$?
if [ $_installed -gt 0 ]; then
	grep -Po "(?<=^ORDS_BASE=).*$" $ords_configuration_file > /dev/null
	_ords_base=$?
	if [ $_ords_base > 0 ]; then
		echo "ERROR: Please set ORDS_BASE in $ords_configuration_file file." >&2
	else
		ords_base_path="$(grep -Po "(?<=^ORDS_BASE=).*$" $ords_configuration_file |cut -d'#' -f1| tail -n 1 )"
	fi
else 
	ords_base_path=$(rpm -qi ords|grep Relocations|awk '{print $3}')
fi
# Get SERVE_EXTRA_ARGS 
serve_extra_args="$(grep -Po "(?<=^SERVE_EXTRA_ARGS=).*$" $ords_configuration_file |cut -d'#' -f1| tail -n 1 )"
# Get APP_VM_OPTS.
app_vm_opts="$(grep -Po "(?<=^APP_VM_OPTS=).*$" $ords_configuration_file |cut -d'#' -f1| tail -n 1 )"
# Get base path in case rpm was relocated on installation
# The absolute path of the default ORDS configuration directory if not empty,
# the configdir in the ords.war file will be overwritten with this value,
# if empty the current configdir in the ords.war file will be used. This
# setting can be set via the service configuration file
ords_configdir="$(grep -Po "(?<=^ORDS_CONFIG=).*$" $ords_configuration_file |cut -d'#' -f1| tail -n 1 )"
# The default Java's base. This setting can be set via the service
# configuration file
# shellcheck disable=SC2230
java_base="$( dirname "$( dirname "$( readlink -e "$( which java )" )" )" )"
# The default JVM's options. This setting can be set via the service
# configuration file
java_options=""
# The default file to look for standalone configuration settings
exit_code=0
# Initializing it as an empty string as there's no NULL in bash. This will
# later be a boolean variable
switch_user=''

script_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if real_script_path="$( readlink -e "$script_directory/$( basename "$0" )" )"
then
    real_script_directory="$( dirname "$real_script_path" )"
else
    real_script_directory="$script_directory"
fi



if [[ -f "$ords_configuration_file"  && -r "$ords_configuration_file" ]]; then
    if [[ -f "${ords_base_path}/ords/bin/ords" && -r "${ords_base_path}/ords/bin/ords" ]]; then
        ORDS_OWNER=$(stat -c %U ${ords_base_path}/ords/bin/ords)
    else
        ORDS_OWNER="oracle"
        echo "INFO : ORDS owner has been set as default as oracle id" >&2
    fi
    if _ords_configdir="$( set -o pipefail; grep -Po "(?<=^ORDS_CONFIG=).*$" \
        "$ords_configuration_file" |cut -d'#' -f1| tail -n 1 )"
    then
        if [[ -n "$_ords_configdir" ]]; then
            if [[ -d "$_ords_configdir" && -r "$_ords_configdir" ]]
            then
                ORDS_CONFIG="$_ords_configdir"
            else
                echo "WARNING: Configuration directory '$_ords_configdir'" \
                    "does not exist, is not a directory or is not readable." \
                    "The configdir will not be overwritten" >&2
            fi
        # If it is empty there's nothing to do here
        fi
    fi
    if _java_home="$( readlink -e "$( set -o pipefail; grep -Po "(?<=^JAVA_HOME=).*$" \
        "$ords_configuration_file" |cut -d'#' -f1| tail -n 1 )" )"
    then
        if [[ -d "$_java_home" && -r "$_java_home" ]]; then
            if [[ -x "$_java_home"'/bin/java' ]]; then
                JAVA_HOME="$_java_home"
            fi
        fi
    else
        JAVA_HOME="$( dirname "$( dirname "$( readlink -e "$( which java )" )" )" )"
    fi
    unset _java_home
    if _java_options="$(set -o pipefail; grep -Po "(?<=^JAVA_OPTIONS=).*$" \
    "$ords_configuration_file" |cut -d'#' -f1| tail -n 1)"
    then
            if [[ ! -z "$_java_options" ]]; then
                JAVA_OPTIONS="$(set -o pipefail;echo $_java_options |perl -0777 -pe 's/(?:((?<!\\)(?:\\\\)*?)\\( ))|''((?:'"'"'(?:(?:\\ )|[^'"'"'])*?'"'"')|(?:"(?:(?:\\ )|(?:\\")|[^"])*?"))/''\1\2\3/g')"
            fi
    fi
    unset _java_options
fi

ords_owner_effective_group="$( id -ng "$ords_owner" )"
root_effective_group="$( id -ng root )"

# The PID file containing directory
pid_file_home='/var/run/ords'
mkdir -p $pid_file_home
# The absolute path to the PID file
pid_file_path="$pid_file_home"'/pid'

# This script is intended to be executed either as the $ords_owner or as root
if [[ "$EUID" -eq 0 ]]; then
    switch_user=true
elif [[ "$( id -un )" == "$ords_owner" ]]; then
    switch_user=false
fi

# If the switch_user variable was defined then we proceed with the execution
if [[ ! -z "$switch_user" ]]; then
    ords_name="Oracle REST Data Services"
    ords_base="${ords_base_path}/ords"
    ords_log_path="/var/log/ords"
    ords_log_file="$ords_log_path/ords.log"
    mkdir -p $ords_log_path
    chown oracle:oinstall $ords_log_path

    function remove_pid_file(){
        local exit_code=0

        rm -rf "$pid_file_path"
        exit_code="$?"

        return "$exit_code"
    }

    function update_pid_file(){
        local exit_code=0
        local pid="$1"

        if [[ -w "$pid_file_path" || -w "$pid_file_home" ]]; then
            (
                set -e;
                mkdir -pm 700 "$pid_file_home"
                chown root:"$root_effective_group" "$pid_file_home"
                touch "$pid_file_path"
                chmod 600 "$pid_file_path"
                chown root:"$root_effective_group" "$pid_file_path"
                echo "$pid" > "$pid_file_path"
            )
            exit_code="$?"
        fi

        return "$exit_code"
    }
    function get_ords_pid(){
        local exit_code=0
        local pid=''

        # Check if the PID file exists and is readable
        if [[ -r "$pid_file_path" ]]; then
            pid="$( cat "$pid_file_path" )"
            if ! ps -p "$pid" &>/dev/null; then
                remove_pid_file
                pid=''
            fi
        else
            # Get the PID
            pid="$( pgrep -f "Doracle.dbtools.cmdline.home=${ords_base_path}/ords *"| head -n 1 )"

            if [[ -n "$pid" ]]; then
                update_pid_file "$pid"
            fi
        fi

        echo "$pid"

        return "$exit_code"
    }

    # Check if the PID file exists and is writable or if the PID home
    # exists and is writable. Either one should be writable by the current
    # user (Either root or the ORDS owner)
    if [[ ! -w "$pid_file_path" && ! -w "$pid_file_home" ]]; then
        echo 'WARNING: PID file "'"$pid_file_path"'" is not' \
            'writable by the current user or it cannot be' \
            'created due to the parent folder'"'"'s' \
            'permissions. Note this must be fixed in order to' \
            'use ORDS'"'"' OEL7 service' >&2
        # Do not modify the exit code as this is not critical for the
        # script to run standalone
    fi

    current_ords_pid="$( get_ords_pid )"

    function get_ords_bound_ports(){
        local exit_code=0

        # - Obtain open file information for the ORDS process regarding TCP,
        #   obtain numeric addresses and ports (-P, -n, -M) and only obtain the
        #   file names (Internet addresses with ports and remote addresses)
        # - Get only the names of the open file (Remove the n)
        # - Remove the address up to the port and then remove the remote
        #   address part as well
        # - Join the lines with a comma between them
        (
            set -o pipefail;
            # TODO: Check if we need to exclude GVFS filesystems using the
            #       lsof option `-e /run/user/1000/gvfs`
            lsof -p "$current_ords_pid" -ai TCP -as TCP:LISTEN -Pn -MF n \
                | grep -Po '(?<=^n).*?$' \
                | sed -re 's/^[^:]*?://' -e 's/->.*?$//' \
                | paste -s -d ','
        )
        exit_code="$?"

        return "$exit_code"
    }
    export -f get_ords_bound_ports

    function execute_script(){
        local exit_code=0
        local script="$1"

        if [[ -n "$script" ]]; then
            if [[ "$switch_user" == true ]]; then
                sudo -iu "$ords_owner" <<-EXECUTION_AS_THE_ORDS_OWNER
					$script
				EXECUTION_AS_THE_ORDS_OWNER
                exit_code="$?"
            else
                "/bin/bash" -c "$script"
                exit_code="$?"
            fi
        else
            echo "ERROR: The script parameter should not be empty" >&2
            exit_code=1
        fi
        return "$exit_code"
    }

    function start(){
        local exit_code=0
        #Validate if ords is configured before to start
        echo "INFO: Starting ${ords_name}..."
        if [[ ! -z "$current_ords_pid" ]]; then
            echo -n "WARNING: $ords_name is already running with PID" \
                "$current_ords_pid" >&2

            if ords_bound_ports="$( get_ords_bound_ports )"; then
                echo -n " and bounded to ports $ords_bound_ports" >&2
            fi

            echo -n $'\n' >&2
        else
            local script
		    script="$( cat <<-EXECUTION_AS_THE_ORDS_OWNER
					exit_code=0

					ords_base=$( printf "%q" "$ords_base" )
					ords_log_file=$( printf "%q" "$ords_log_file" )
					ORDS_CONFIG=$( printf "%q" "$ORDS_CONFIG" )

					# We need to be careful as the configuration directory could be
					# relative
					cd "\$ords_base"
					# Start ORDS in background
					cd $ORDS_CONFIG
					export APP_VM_OPTS=$app_vm_opts
					nohup /usr/local/bin/ords serve $serve_extra_args &>> "\$ords_log_file" &
					exit \$exit_code
				EXECUTION_AS_THE_ORDS_OWNER
			)"
			local script_output=""
			local script_exit_code=0
			local current_ords_pid=""

			script_output="$( execute_script "$script" )"
			script_exit_code="$?"

			if [[ $script_exit_code -eq 0 ]]; then
				echo "$script_output" | head -n -1
				sleep 2s
				current_ords_pid="$( pgrep -f "Doracle.dbtools.cmdline.home=${ords_base_path}/ords *"| head -n 1 )"
				update_pid_file "$current_ords_pid"
			fi

			if [[ ! -z "$current_ords_pid" ]]; then
				echo "INFO: $ords_name started with PID $current_ords_pid"
				script="$( cat <<-PORT_BINDING_SCRIPT
						exit_code=0

						# Escape the variable contents
						current_ords_pid=$( printf "%q" "$current_ords_pid" )

						while true; do
						    if ps -p "\$current_ords_pid" &> /dev/null; then
							ords_bound_ports="\$( get_ords_bound_ports )"
							if [[ -n "\$ords_bound_ports" ]]; then
							    echo "\$ords_bound_ports"
							    break
							fi
						    else
							echo -e "\\nERROR: $ords_name process ended" \
							    "unexpectedly" >&2
							exit_code=1
							break
						    fi
						    sleep 1
						done;

						exit "\$exit_code"
					PORT_BINDING_SCRIPT
			)"

			echo "INFO: Obtaining the port binding information..."
			script_output="$(
			    trap 'kill -INT -"$timeout_pid"' INT
			    timeout -s SIGKILL 20 bash -c "$script" &
			    timeout_pid="$!"
			    wait "$timeout_pid"
			)"
			script_exit_code="$?"

			# If ORDS was not terminated
			if [[ "$script_exit_code" -eq 1 ]]; then
			    # Error was already printed so no need for it
			    exit_code="$script_exit_code"
			elif [[ "$script_exit_code" -eq 0 ]]; then
			    echo 'INFO: '"$ords_name"' is bounded to ports' \
				"$script_output"
			elif [[ "$script_exit_code" -eq 137 \
			    || "$script_exit_code" -eq 124 ]]
			then
			    echo $'\n'"WARNING: Timed-out while obtaining the" \
				"port binding information" >&2
                elif [[ "$script_exit_code" -eq 130 ]]; then
                    echo $'\n''WARNING: User interrupted the execution' \
                        'while obtaining the port binding information.'
                    echo 'INFO: The '"$ords_name"' process is still' \
                        'running in the background'
                        exit_code="$script_exit_code"
                else
                    echo $'\n'"WARNING: An error occurred while" \
                        "obtaining the port binding information" >&2
                    exit_code="$script_exit_code"
                fi
            else
                echo -e "ERROR: There was an error starting ORDS. Please" \
                    "check the log under \"$ords_log_file\"" >&2
                exit_code=1
            fi
        fi

        return "$exit_code"
    }

    function status(){
        local exit_code=0

        local ords_bound_ports=''

        echo "INFO: Obtaining $ords_name status..."
        if [[ ! -z "$current_ords_pid" ]]; then
            echo -n "INFO: $ords_name is running with PID" \
                "$current_ords_pid"

            if ords_bound_ports="$( get_ords_bound_ports )"; then
                echo -n " and bounded to ports $ords_bound_ports"
            fi

            echo -n $'\n'
        else
            echo "WARNING: $ords_name is not running" >&2
            exit_code=1
        fi

        return $exit_code
    }

    function stop(){
        local exit_code=0

        echo "INFO: Stopping ${ords_name}..."
        if [[ ! -z "$current_ords_pid" ]]; then
            if kill "$current_ords_pid"; then
                while kill -0 "$current_ords_pid" &>/dev/null; do
                    sleep 1
                done

                echo "INFO: ${ords_name} stopped"
                remove_pid_file
                current_ords_pid=''
            else
                echo "ERROR: Error stopping $ords_name" >&2
                exit_code=1
            fi
        else
            echo "WARNING: $ords_name is not running" >&2
        fi

        return $exit_code
    }

    function log(){
        less +F "$ords_log_file"
    }

    function get_ords_information(){
        local exit_code=0
        local key="$1"

        if [[ -n "$key" ]]; then
            if [[ "$key" == 'version' || "$key" == 'configdir' ]]; then

                local script
                script="$( cat <<-EXECUTION_AS_THE_ORDS_OWNER
					exit_code=0

					java_base=$( printf "%q" "$java_base" )
					# java_options is escaped so we use the external one
					ords_base=$( printf "%q" "$ords_base" )
					ords_log_file=$( printf "%q" "$ords_log_file" )
					key=$( printf "%q" "$key" )

					java_base_command="\$java_base"'/bin/java'
					java_command="\$java_base_command"

					# We need to be careful as the configuration directory
					# could be relative
					cd "\$ords_base"

					ords_information="\$( \$java_command -jar \
						"\$ords_base/ords.war" "\$key" 2>&1 )"
					exit_code=\$?

					if [[ "\$exit_code" -eq 0 ]]; then
					    echo "\$ords_information"
					fi

					exit \$exit_code
				EXECUTION_AS_THE_ORDS_OWNER
                )"
                local script_output=""
                local script_exit_code=0
                local current_ords_pid=""

                script_output="$( execute_script "$script" 2>&1 )"
                script_exit_code="$?"

                if [[ $script_exit_code -eq 0 ]]; then
                    echo -e "$script_output"
                else
                    echo -e 'ERROR: There was an error obtaining the ORDS '\
"$key"', please review your service configuration file\n' >&2
                    exit_code=1
                fi
            else
                echo -e 'ERROR: The key parameter value should be one of [ '\
'version, configdir ]. Was "'"$key"'"\n' >&2
                exit_code=1
            fi
        else
            echo -e 'ERROR: The key parameter must not be empty\n' >&2
            exit_code=1
        fi

        return $exit_code
    }

    function version(){
        local exit_code=0

        ( set -o pipefail; get_ords_information 'version' | grep -Po '\S+$' )
        exit_code="$?"

        return $exit_code
    }

    function fun_configdir(){
        local exit_code=0

        (
            set -o pipefail;
            get_ords_information 'configdir' \
                | tail -n +2 \
                | sed -re 's/^INFO:\s+The\s+config\.dir\s+value\s+is\s+//'
        )
        exit_code="$?"

        return $exit_code
    }

    function usage(){
        cat <<-USAGE
			$script_name - $script_human_readable_name $script_version

			$script_description

			Usage: $script_name [OPTION|COMMAND]

			OPTIONS

			Options will only be read from the first passed argument. Other
			arguments will be ignored

			    -h, --help       Print this message and exit
			    -v, --version    Prints this script's version and exit

			COMMANDS

			Commands will only be read from the first passed argument. Other
			arguments will be ignored.

			The present message will only describe the available standard
			service commands, for more information see this command's manpage
			ords(1)

			    status
			        Reports the status of the Oracle REST Data Services and
              if running, it also reports the ports to which it is bounded.
			    start
			        Starts the server in the background and detaches the newly
			        created process from its parent terminal so it
			        continues to run even if the current terminal window is
			        closed. Once the server has been started, the program will
			        report the port numbers to which the server is bounded.
			    stop
			        Stops the Oracle REST Data Services
			    restart
			        Tries to stop the server and starts it again
                pid_file
                    Show the file containing the ORDS pid file
                pid
                    Show the PID number
                log
                    Open log file in read only mode
                version
                    Show the ORDS version
                configdir
                    Show the current config path of the ORDS
                basedir
                    Show the ORDS path
                logdir
                    Show the path where the logs are written

			SEE ALSO

			ords(1), ords.service(1), ords.config(5)
		USAGE
    }

    case "${1:---help}" in
        start)
            start
            exit_code="$?"
            ;;
        stop)
            stop
            exit_code="$?"
            ;;
        status)
            status
            exit_code="$?"
            ;;
        restart)
            stop && start
            exit_code="$?"
            ;;
        pid_file)
            echo "$pid_file_path"
            exit_code="$?"
            ;;
        pid)
            get_ords_pid
            exit_code="$?"
            ;;
        log)
            log
            exit_code="$?"
            ;;
        version)
            version
            exit_code="$?"
            ;;
        configdir|configuration_directory)
            fun_configdir
            exit_code="$?"
            ;;
        basedir|base_directory)
            echo "$ords_base"
            exit_code="$?"
            ;;
        logdir|log_directory)
            echo "$ords_log_path"
            exit_code="$?"
            ;;
        log_file)
            echo "$ords_log_file"
            exit_code="$?"
            ;;
        -h|--help)
            usage
            # Leave the exit code as is (0)
            ;;
        -v|--version)
            echo "$script_version"
            ;;
        *)
            echo "ERROR: Unrecognized OPTION or COMMAND"
            usage
            exit_code=1
            ;;
    esac
else
    echo "ERROR: Script must be run either as the root or the $ords_owner" \
        "user" >&2
    exit_code=1
fi

exit "$exit_code"
