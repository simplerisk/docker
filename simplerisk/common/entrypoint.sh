#!/bin/bash

set -eo pipefail

print_log(){
    echo "$(date -u +"[%a %b %e %X.%6N %Y]") [$1] $2"
}

generate_random_password() {
	echo "$(< /dev/urandom tr -dc A-Za-z0-9 | head -c21)"
}

run_sql_command() {
	# $1: Password
	# $2: Command
	MYSQL_PWD=$1 mysql -uroot -e "$2"
}

set_db_password(){
	echo "$(generate_random_password)" > /passwords/pass_mysql_root.txt
	echo "$(generate_random_password)" > /passwords/pass_simplerisk.txt
	sed -i "s/\('DB_PASSWORD', '\).*\(');\)/\1$(cat /passwords/pass_simplerisk.txt)\2/g" "$CONFIG_PATH"
}

set_config(){
	# If the config.php hasn't already been configured
	if [ ! -f /configurations/simplerisk-config-configured ]; then
		print_log "initial_setup:config" "Setting up SimpleRisk's configuration"

		CONFIG_PATH='/var/www/simplerisk/includes/config.php'

		# TEMP: localhost as hostname is not working on Ubuntu 20.04
		OS_VERSION="$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)"
		SIMPLERISK_DB_HOSTNAME='127.0.0.1'

		sed -i "s/\('DB_HOSTNAME', '\).*\(');\)/\1$SIMPLERISK_DB_HOSTNAME\2/g" $CONFIG_PATH
		SIMPLERISK_DB_PORT=3306 && sed -i "s/\('DB_PORT', '\).*\(');\)/\1$SIMPLERISK_DB_PORT\2/g" $CONFIG_PATH
		SIMPLERISK_DB_USERNAME=simplerisk && sed -i "s/\('DB_USERNAME', '\).*\(');\)/\1$SIMPLERISK_DB_USERNAME\2/g" $CONFIG_PATH
		set_db_password
		SIMPLERISK_DB_DATABASE=simplerisk && sed -i "s/\('DB_DATABASE', '\).*\(');\)/\1$SIMPLERISK_DB_DATABASE\2/g" $CONFIG_PATH

		# shellcheck disable=SC2015
		[ "$(cat /tmp/version)" == "testing" ] && sed -i "s|//\(define('.*_URL\)|\1|g" $CONFIG_PATH || true
	
		# Create a file so this doesn't run again
		touch /configurations/simplerisk-config-configured

		print_log "initial_setup:config" "SimpleRisk's configuration file set properly"
	fi
}

configure_db() {
	# If MySQL hasn't already been configured
	if [ ! -f /configurations/mysql-configured ]; then
		# Start MySQL and wait 10 seconds for the startup
		print_log "initial_setup:mysql" "Setting up MySQL"
		service mysql start && sleep 10s

		local password
		password="$(cat /passwords/pass_mysql_root.txt)"
		# Set the MySQL root password
		run_sql_command "${password}" "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${password}'"

		# Create the SimpleRisk database
		run_sql_command "${password}" "create database simplerisk;"

		# Load the SimpleRisk database schema
		run_sql_command "${password}" "use simplerisk; \. /simplerisk.sql" && rm /simplerisk.sql

		# Set the permissions for the SimpleRisk database
		run_sql_command "${password}" "CREATE USER 'simplerisk'@'${SIMPLERISK_DB_HOSTNAME}' IDENTIFIED BY '$(cat /passwords/pass_simplerisk.txt)'"
		run_sql_command "${password}" "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'${SIMPLERISK_DB_HOSTNAME}'"
		run_sql_command "${password}" "UPDATE mysql.db SET References_priv='Y',Index_priv='Y' WHERE db='simplerisk';"

		# Update the SIMPLERISK_INSTALLED value because of the DB installation
		sed -i "s/\('SIMPLERISK_INSTALLED', 'false'\)/'SIMPLERISK_INSTALLED', 'true'/g" $CONFIG_PATH

		# Create a file so this doesn't run again
		touch /configurations/mysql-configured

		print_log "initial_setup:mysql" "MySQL set properly"
		service mysql stop
	fi
}

unset_variables() {
	unset SIMPLERISK_DB_HOSTNAME
	unset SIMPLERISK_DB_PORT
	unset SIMPLERISK_DB_USERNAME
	unset SIMPLERISK_DB_DATABASE
}

_main() {
	print_log "startup:general" "Starting SimpleRisk container..."

	set_config
	configure_db
	unset_variables
	service cron start

	print_log "startup:general" "Container startup is finished"
	exec "$@"
}

_main "$@"
