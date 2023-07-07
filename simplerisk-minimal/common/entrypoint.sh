#!/bin/bash

set -eo pipefail

print_log(){
	echo "$(date -u +"[%a %b %e %X.%6N %Y]") [$1] $2"
}

exec_cmd(){
	exec_cmd_nobail "$1" || fatal_error "$2"
}

exec_cmd_nobail() {
	bash -c "$1"
}

generate_random_password() {
	# shellcheck disable=SC2005
	echo "$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c21)"
}

fatal_error(){
	print_log "error" "$1"
	exit 1
}

set_db_password(){
	if [[ "${DB_SETUP:-}" = automatic* ]]; then
		# shellcheck disable=SC2015
		[ -z "${SIMPLERISK_DB_PASSWORD:-}" ] && SIMPLERISK_DB_PASSWORD=$(generate_random_password) && print_log "initial_setup:warn" "As no password was provided and this is a first time setup, a random password has been generated ($SIMPLERISK_DB_PASSWORD)"
	else
		SIMPLERISK_DB_PASSWORD=${SIMPLERISK_DB_PASSWORD:-simplerisk}
	fi
	exec_cmd "sed -i \"s/\('DB_PASSWORD', '\).*\(');\)/\1$SIMPLERISK_DB_PASSWORD\2/g\" $CONFIG_PATH"
}

validate_db_setup(){
	case "${DB_SETUP:-}" in
		automatic)
			print_log "initial_info:setup" "Setting database through the automatic process";;
		automatic-only)
			print_log "initial_info:setup" "Setting database through the automatic process and removing container";;
		manual)
			print_log "initial_info:setup" "Database will be set manually";;
		delete)
			print_log "initial_info:setup" "Perform deletion of database";;
		"")
			print_log "initial_info:setup" "Database is already set";;
		*)
			fatal_error "The provided option for DB_SETUP is invalid. It must be automatic, automatic-only or manual.";;
	esac
}

set_config(){
	CONFIG_PATH='/var/www/simplerisk/includes/config.php'

	# Replacing config variables if they exist
	SIMPLERISK_DB_HOSTNAME=${SIMPLERISK_DB_HOSTNAME:-localhost} && exec_cmd "sed -i \"s/\('DB_HOSTNAME', '\).*\(');\)/\1$SIMPLERISK_DB_HOSTNAME\2/g\" $CONFIG_PATH"

	SIMPLERISK_DB_PORT=${SIMPLERISK_DB_PORT:-3306} && exec_cmd "sed -i \"s/\('DB_PORT', '\).*\(');\)/\1$SIMPLERISK_DB_PORT\2/g\" $CONFIG_PATH"

	SIMPLERISK_DB_USERNAME=${SIMPLERISK_DB_USERNAME:-simplerisk} && exec_cmd "sed -i \"s/\('DB_USERNAME', '\).*\(');\)/\1$SIMPLERISK_DB_USERNAME\2/g\" $CONFIG_PATH"

	set_db_password

	SIMPLERISK_DB_DATABASE=${SIMPLERISK_DB_DATABASE:-simplerisk} && exec_cmd "sed -i \"s/\('DB_DATABASE', '\).*\(');\)/\1$SIMPLERISK_DB_DATABASE\2/g\" $CONFIG_PATH"

	# shellcheck disable=SC2015
	[ -n "${SIMPLERISK_DB_FOR_SESSIONS:-}" ] && sed -i "s/\('USE_DATABASE_FOR_SESSIONS', '\).*\(');\)/\1$SIMPLERISK_DB_FOR_SESSIONS\2/g" $CONFIG_PATH || true

	# shellcheck disable=SC2015
	[ -n "${SIMPLERISK_DB_SSL_CERT_PATH:-}" ] && sed -i "s/\('DB_SSL_CERTIFICATE_PATH', '\).*\(');\)/\1$SIMPLERISK_DB_SSL_CERT_PATH\2/g" $CONFIG_PATH || true

	# If DB_SETUP is not set, update the SIMPLERISK_INSTALLED value to true
	# shellcheck disable=SC2015
	[ -z "${DB_SETUP:-}" ] && exec_cmd "sed -i \"s/\('SIMPLERISK_INSTALLED', \)'false'/\1'true'/g\" $CONFIG_PATH" || true

	# Testing related operations
	if [ "$(cat /tmp/version)" = "testing" ]; then
		exec_cmd "sed -i \"s|//\(define('.*_URL\)|\1|g\" $CONFIG_PATH"
	fi
}

delete_db(){
	print_log "db_deletion: prepare" "Performing database deletion"

	# Needed to separate the GRANT statement from the rest because it was providing a syntax error
	exec_cmd "mysql --protocol=socket -u $DB_SETUP_USER -p$DB_SETUP_PASS -h$SIMPLERISK_DB_HOSTNAME -P$SIMPLERISK_DB_PORT <<EOSQL
	SET sql_mode = 'ANSI_QUOTES';
	DROP DATABASE \"${SIMPLERISK_DB_DATABASE}\";
	USE mysql;
	DELETE FROM user WHERE User='${SIMPLERISK_DB_USERNAME}';
	DELETE FROM db WHERE User='${SIMPLERISK_DB_USERNAME}';
	FLUSH PRIVILEGES;
EOSQL" "Was not able to apply settings on database. Check error above. Exiting."

	print_log "db_deletion: done" "Database deletion performed. Exiting."
	exit 0
}

db_setup(){
	print_log "initial_setup:info" "First time setup. Will wait..."
	exec_cmd "sleep ${DB_SETUP_WAIT:-20}s > /dev/null 2>&1" "DB_SETUP_WAIT variable is set incorrectly. Exiting."

	print_log "initial_setup:info" "Starting database set up"

	if [ "$(cat /tmp/version)" == "testing" ]; then
		print_log "initial_setup:info" "Testing version detected. Looking for SQL script (simplerisk.sql) at /var/www/simplerisk/..."
		SCHEMA_FILE='/var/www/simplerisk/simplerisk.sql'
		exec_cmd "[ -f $SCHEMA_FILE ]" "SQL script not found. Exiting."
	else
		print_log "initial_setup:info" "Downloading schema..."
		SCHEMA_FILE='/tmp/simplerisk.sql'
		exec_cmd "curl -sL https://github.com/simplerisk/database/raw/master/simplerisk-en-$(cat /tmp/version).sql > $SCHEMA_FILE" "Could not download schema from Github. Exiting."
	fi

	print_log "initial_setup:info" "Applying changes to MySQL database... (MySQL error will be printed to console as guidance)"
	# Using sql_mode = ANSI_QUOTES to avoid using backticks
	exec_cmd "mysql --protocol=socket -u $DB_SETUP_USER -p$DB_SETUP_PASS -h$SIMPLERISK_DB_HOSTNAME -P$SIMPLERISK_DB_PORT <<EOSQL
	SET sql_mode = 'ANSI_QUOTES';
	CREATE DATABASE \"${SIMPLERISK_DB_DATABASE}\";
	USE \"${SIMPLERISK_DB_DATABASE}\";
	\. ${SCHEMA_FILE}
	CREATE USER \"${SIMPLERISK_DB_USERNAME}\"@\"%\" IDENTIFIED BY \"${SIMPLERISK_DB_PASSWORD}\";
EOSQL" "Was not able to apply settings on database. Check error above. Exiting."
	# Needed to separate the GRANT statement from the rest because it was providing a syntax error
	exec_cmd "mysql --protocol=socket -u $DB_SETUP_USER -p$DB_SETUP_PASS -h$SIMPLERISK_DB_HOSTNAME -P$SIMPLERISK_DB_PORT <<EOSQL
	SET sql_mode = 'ANSI_QUOTES';
	GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON \"${SIMPLERISK_DB_DATABASE}\".* TO \"${SIMPLERISK_DB_USERNAME}\"@\"%\";
EOSQL" "Was not able to apply settings on database. Check error above. Exiting."

	print_log "initial_setup:info" "Setup has been applied successfully!"
	print_log "initial_setup:info" "Removing schema file..."
	exec_cmd "rm ${SCHEMA_FILE}"

	# Update the SIMPLERISK_INSTALLED value
	exec_cmd "sed -i \"s/\('SIMPLERISK_INSTALLED', \)'false'/\1'true'/g\" $CONFIG_PATH"

	# shellcheck disable=SC2015
	[ "${DB_SETUP:-}" = "automatic-only" ] && print_log "initial_setup:info" "Running setup only (automatic-only). Container will be discarded." && exit 0 || true
}

unset_variables() {
	unset DB_SETUP
	unset DB_SETUP_USER
	unset DB_SETUP_PASS
	unset DB_SETUP_WAIT
	unset SIMPLERISK_DB_HOSTNAME
	unset SIMPLERISK_DB_PORT
	unset SIMPLERISK_DB_USERNAME
	unset SIMPLERISK_DB_PASSWORD
	unset SIMPLERISK_DB_DATABASE
	unset SIMPLERISK_DB_FOR_SESSIONS
	unset SIMPLERISK_DB_SSL_CERT_PATH
}

load_scripts() {
	if [[ -d /tmp/scripts ]]; then
		for script in /tmp/scripts/*; do
			case "$script" in
				*.sh)
					if [ -x "$script" ]; then
						echo "Running $script"
						"$script"
					else
						echo "Sourcing $script"
						# shellcheck source=/dev/null
						. "$script"
					fi ;;
				*) echo "Ignoring $script" ;;
			esac
		done
	fi
}

_main() {
	validate_db_setup
	set_config
	if [[ -n ${DB_SETUP:-} ]]; then
	  DB_SETUP_USER="${DB_SETUP_USER:-root}"
	  DB_SETUP_PASS="${DB_SETUP_PASS:-root}"
	fi
	# shellcheck disable=SC2015
	[[ "${DB_SETUP:-}" == "delete" ]] && delete_db || true
	# shellcheck disable=SC2015
	[[ "${DB_SETUP:-}" = automatic* ]] && db_setup || true
	unset_variables
	load_scripts
	service cron start
	exec "$@"
}

_main "$@"
