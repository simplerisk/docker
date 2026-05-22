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

		local CONFIG_PATH='/var/www/simplerisk/includes/config.php'
		local CONFIG_SAMPLE_PATH='/var/www/simplerisk/includes/config.sample.php'

		# Copy the sample config into place. The SimpleRisk release ships
		# config.sample.php; the entrypoint creates config.php from it
		# before substituting the values generated below. For users
		# upgrading from an older image on a persisted /var/www/simplerisk
		# volume, config.sample.php won't be present — fall back to
		# reusing the existing config.php, which the subsequent sed
		# substitutions will rewrite in place.
		if [ -f "$CONFIG_SAMPLE_PATH" ]; then
			cp "$CONFIG_SAMPLE_PATH" "$CONFIG_PATH"
		elif [ ! -f "$CONFIG_PATH" ]; then
			print_log "initial_setup:error" "Neither $CONFIG_SAMPLE_PATH nor $CONFIG_PATH is present. The /var/www/simplerisk volume appears to be in an inconsistent state."
			exit 1
		else
			print_log "initial_setup:info" "$CONFIG_SAMPLE_PATH not found; reusing existing $CONFIG_PATH (likely upgrading from an older image on a persisted volume)."
		fi

		SIMPLERISK_DB_HOSTNAME='127.0.0.1'

		sed -i "s/\('DB_HOSTNAME', '\).*\(');\)/\1$SIMPLERISK_DB_HOSTNAME\2/g" $CONFIG_PATH
		SIMPLERISK_DB_PORT=3306 && sed -i "s/\('DB_PORT', '\).*\(');\)/\1$SIMPLERISK_DB_PORT\2/g" $CONFIG_PATH
		SIMPLERISK_DB_USERNAME=simplerisk && sed -i "s/\('DB_USERNAME', '\).*\(');\)/\1$SIMPLERISK_DB_USERNAME\2/g" $CONFIG_PATH
		set_db_password
		SIMPLERISK_DB_DATABASE=simplerisk && sed -i "s/\('DB_DATABASE', '\).*\(');\)/\1$SIMPLERISK_DB_DATABASE\2/g" $CONFIG_PATH
		sed -i "s/\('USE_DATABASE_FOR_SESSIONS', '\).*\(');\)/\1true\2/g" $CONFIG_PATH

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

	echo "Version is $version"

	set_config
	configure_db
	unset_variables

	print_log "startup:general" "Container startup is finished"
	exec "$@"
}

_main "$@"
