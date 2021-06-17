#!/bin/bash

set -eo pipefail

run_sql_command() {
	# $1: Password
	# $2: Command
	MYSQL_PWD=$1 mysql -uroot -e "$2"
}

configure_db() {
	# Start MySQL and wait 10 seconds
	/etc/init.d/mysql start && sleep 10s

	# If MySQL hasn't already been configured
	if [ ! -f /configurations/mysql-configured ]; then
		password=$(cat /passwords/pass_mysql_root.txt)
		# Set the MySQL root password
		mysqladmin -u root password $password

		# Create the SimpleRisk database
		run_sql_command $password "create database simplerisk;"

		# Load the SimpleRisk database schema
		#mysql -uroot -p`cat /passwords/pass_mysql_root.txt` -e "use simplerisk; \. /simplerisk.sql"
		run_sql_command $password "use simplerisk; \. /simplerisk.sql"

		# Set the permissions for th4e SimpleRisk database
		run_sql_command $password "CREATE USER 'simplerisk'@'localhost' IDENTIFIED BY '$(cat /passwords/pass_simplerisk.txt)'"
		run_sql_command $password "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'localhost'"

		# Create a file so this doesn't run again
		touch /configurations/mysql-configured
	fi
}

_main() {
	configure_db
	exec "$@"
}

_main "$@"
