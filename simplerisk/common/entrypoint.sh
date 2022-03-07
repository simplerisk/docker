#!/bin/bash

set -eo pipefail

generate_random_password() {
	echo "$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c21)"
}

run_sql_command() {
	# $1: Password
	# $2: Command
	MYSQL_PWD=$1 mysql -uroot -e "$2"
}

set_db_password(){
	echo "$(generate_random_password)" >> /passwords/pass_mysql_root.txt
	echo "$(generate_random_password)" >> /passwords/pass_simplerisk.txt
	sed -i "s/\('DB_PASSWORD', '\).*\(');\)/\1$(cat /passwords/pass_simplerisk.txt)\2/g" "$CONFIG_PATH"
}

set_config(){
	# If the config.php hasn't already been configured
	if [ ! -f /configurations/simplerisk-config-configured ]; then
		CONFIG_PATH='/var/www/simplerisk/includes/config.php'

		SIMPLERISK_DB_HOSTNAME=localhost && sed -i "s/\('DB_HOSTNAME', '\).*\(');\)/\1$SIMPLERISK_DB_HOSTNAME\2/g" $CONFIG_PATH
		SIMPLERISK_DB_PORT=3306 && sed -i "s/\('DB_PORT', '\).*\(');\)/\1$SIMPLERISK_DB_PORT\2/g" $CONFIG_PATH
		SIMPLERISK_DB_USERNAME=simplerisk && sed -i "s/\('DB_USERNAME', '\).*\(');\)/\1$SIMPLERISK_DB_USERNAME\2/g" $CONFIG_PATH
		set_db_password
		SIMPLERISK_DB_DATABASE=simplerisk && sed -i "s/\('DB_DATABASE', '\).*\(');\)/\1$SIMPLERISK_DB_DATABASE\2/g" $CONFIG_PATH
		
		# Update the SIMPLERISK_INSTALLED value
		sed -i "s/\('SIMPLERISK_INSTALLED', 'false'\)/'SIMPLERISK_INSTALLED', 'true'/g" $CONFIG_PATH

		# shellcheck disable=SC2015
		[ "$(cat /tmp/version)" == "testing" ] && sed -i "s|//\(define('.*_URL\)|\1|g" $CONFIG_PATH || true
	
		# Create a file so this doesn't run again
		touch /configurations/simplerisk-config-configured
	fi
}

configure_db() {
	# Start MySQL and wait 10 seconds
	/etc/init.d/mysql start && sleep 10s

	# If MySQL hasn't already been configured
	if [ ! -f /configurations/mysql-configured ]; then
		password=$(cat /passwords/pass_mysql_root.txt)
		# Set the MySQL root password
		mysqladmin -u root password "$password"

		# Create the SimpleRisk database
		run_sql_command "$password" "create database simplerisk;"

		# Load the SimpleRisk database schema
		#mysql -uroot -p`cat /passwords/pass_mysql_root.txt` -e "use simplerisk; \. /simplerisk.sql"
		run_sql_command "$password" "use simplerisk; \. /simplerisk.sql" && rm /simplerisk.sql

		# Set the permissions for the SimpleRisk database
		run_sql_command "$password" "CREATE USER 'simplerisk'@'localhost' IDENTIFIED BY '$(cat /passwords/pass_simplerisk.txt)'"
		run_sql_command "$password" "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'localhost'"

		# Create a file so this doesn't run again
		touch /configurations/mysql-configured
	fi
}

unset_variables() {
	unset SIMPLERISK_DB_HOSTNAME
	unset SIMPLERISK_DB_PORT
	unset SIMPLERISK_DB_USERNAME
	unset SIMPLERISK_DB_PASSWORD
	unset SIMPLERISK_DB_DATABASE
	unset SIMPLERISK_USER_PASS
}

_main() {
	set_config
	configure_db
	unset_variables
	service cron start
	exec "$@"
}

_main "$@"
