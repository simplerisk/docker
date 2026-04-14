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
	if [ "$version" = "testing" ]; then
		exec_cmd "sed -i \"s|//\(define('.*_URL\)|\1|g\" $CONFIG_PATH"
	fi
}

set_csrf_secret(){
	CSRF_SECRET_PATH='/var/www/simplerisk/vendor/simplerisk/csrf-magic/csrf-secret.php'

	# If a SIMPLERISK_CSRF_SECRET value was specified create the csrf-secret.php file with that value
	[ -n "${SIMPLERISK_CSRF_SECRET:-}" ] && echo "<?php \$secret = \"${SIMPLERISK_CSRF_SECRET}\"; ?>" > "$CSRF_SECRET_PATH";
}

set_cron(){
	# If SIMPLERISK_CRON_SETUP was passed and it is set to disabled
	if [[ -n "${SIMPLERISK_CRON_SETUP:-}" && "${SIMPLERISK_CRON_SETUP:-}" = disabled* ]]; then
		print_log "cron_setup" "SimpleRisk cron setup is disabled."
	else
		print_log "cron_setup" "SimpleRisk cron setup is enabled."

		CRON_PATH='/tmp/backup-cron'

		# Create the cron file
		exec_cmd "echo '* * * * * /usr/local/bin/php -f /var/www/simplerisk/cron/cron.php > /dev/null 2>&1' >> $CRON_PATH" "Failed to write cron file. Exiting."
		exec_cmd "chmod 0644 $CRON_PATH" "Failed to chmod cron file. Exiting."
		exec_cmd_nobail "crontab $CRON_PATH" || print_log "cron_setup:warn" "crontab installation failed — cron may not run. Set SIMPLERISK_CRON_SETUP=disabled if cron is managed externally."
	fi
}

apply_mail_setting(){
	local db_key="$1" value="$2"
	# Escape backslashes then single quotes for a MySQL single-quoted string literal
	local escaped
	escaped=$(printf '%s' "$value" | sed 's/\\/\\\\/g' | sed "s/'/\\\\'/g")
	mysql -u "$SIMPLERISK_DB_USERNAME" \
	      -p"$SIMPLERISK_DB_PASSWORD" \
	      -h "$SIMPLERISK_DB_HOSTNAME" \
	      -P "$SIMPLERISK_DB_PORT" \
	      --skip-ssl \
	      "$SIMPLERISK_DB_DATABASE" \
	      -e "UPDATE settings SET value='${escaped}' WHERE name='${db_key}';" \
	    || print_log "mail_settings:warn" "Failed to update ${db_key}"
}

set_mail_settings(){
	local email_regex='^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$'

	# transport: smtp or sendmail
	if [ -n "${MAIL_TRANSPORT:-}" ]; then
		case "${MAIL_TRANSPORT}" in
			smtp|sendmail) apply_mail_setting phpmailer_transport "$MAIL_TRANSPORT" ;;
			*) print_log "mail_settings:warn" "MAIL_TRANSPORT='${MAIL_TRANSPORT}' must be 'smtp' or 'sendmail' — skipping" ;;
		esac
	fi

	# email addresses: validate regex
	if [ -n "${MAIL_FROM_EMAIL:-}" ]; then
		if [[ "${MAIL_FROM_EMAIL}" =~ $email_regex ]]; then
			apply_mail_setting phpmailer_from_email "$MAIL_FROM_EMAIL"
		else
			print_log "mail_settings:warn" "MAIL_FROM_EMAIL is not a valid email address — skipping"
		fi
	fi

	if [ -n "${MAIL_REPLYTO_EMAIL:-}" ]; then
		if [[ "${MAIL_REPLYTO_EMAIL}" =~ $email_regex ]]; then
			apply_mail_setting phpmailer_replyto_email "$MAIL_REPLYTO_EMAIL"
		else
			print_log "mail_settings:warn" "MAIL_REPLYTO_EMAIL is not a valid email address — skipping"
		fi
	fi

	# free-form strings
	# shellcheck disable=SC2015
	[ -n "${MAIL_FROM_NAME:-}" ]    && apply_mail_setting phpmailer_from_name    "$MAIL_FROM_NAME"    || true
	# shellcheck disable=SC2015
	[ -n "${MAIL_REPLYTO_NAME:-}" ] && apply_mail_setting phpmailer_replyto_name "$MAIL_REPLYTO_NAME" || true
	# shellcheck disable=SC2015
	[ -n "${MAIL_HOST:-}" ]         && apply_mail_setting phpmailer_host         "$MAIL_HOST"         || true
	# shellcheck disable=SC2015
	[ -n "${MAIL_USERNAME:-}" ]     && apply_mail_setting phpmailer_username     "$MAIL_USERNAME"     || true
	# shellcheck disable=SC2015
	[ -n "${MAIL_PREPEND:-}" ]      && apply_mail_setting phpmailer_prepend      "$MAIL_PREPEND"      || true

	# booleans: true or false
	if [ -n "${MAIL_SMTPAUTOTLS:-}" ]; then
		case "${MAIL_SMTPAUTOTLS}" in
			true|false) apply_mail_setting phpmailer_smtpautotls "$MAIL_SMTPAUTOTLS" ;;
			*) print_log "mail_settings:warn" "MAIL_SMTPAUTOTLS must be 'true' or 'false' — skipping" ;;
		esac
	fi

	if [ -n "${MAIL_SMTPAUTH:-}" ]; then
		case "${MAIL_SMTPAUTH}" in
			true|false) apply_mail_setting phpmailer_smtpauth "$MAIL_SMTPAUTH" ;;
			*) print_log "mail_settings:warn" "MAIL_SMTPAUTH must be 'true' or 'false' — skipping" ;;
		esac
	fi

	# smtpsecure: none, tls, or ssl
	if [ -n "${MAIL_ENCRYPTION:-}" ]; then
		case "${MAIL_ENCRYPTION}" in
			none|tls|ssl) apply_mail_setting phpmailer_smtpsecure "$MAIL_ENCRYPTION" ;;
			*) print_log "mail_settings:warn" "MAIL_ENCRYPTION must be 'none', 'tls', or 'ssl' — skipping" ;;
		esac
	fi

	# port: numeric only
	if [ -n "${MAIL_PORT:-}" ]; then
		if [[ "${MAIL_PORT}" =~ ^[0-9]+$ ]]; then
			apply_mail_setting phpmailer_port "$MAIL_PORT"
		else
			print_log "mail_settings:warn" "MAIL_PORT must be numeric — skipping"
		fi
	fi

	# password: only applied when non-empty
	# shellcheck disable=SC2015
	[ -n "${MAIL_PASSWORD:-}" ] && apply_mail_setting phpmailer_password "$MAIL_PASSWORD" || true
}

delete_db(){
	print_log "db_deletion: prepare" "Performing database deletion"

	# Pass password via env var to avoid shell interpretation of special characters in the value
	export MYSQL_PWD="$DB_SETUP_PASS"
	# Needed to separate the GRANT statement from the rest because it was providing a syntax error
	exec_cmd "mysql -u $DB_SETUP_USER -h$SIMPLERISK_DB_HOSTNAME -P$SIMPLERISK_DB_PORT <<EOSQL
	SET sql_mode = 'ANSI_QUOTES';
	DROP DATABASE \"${SIMPLERISK_DB_DATABASE}\";
	USE mysql;
	DROP USER '${SIMPLERISK_DB_USERNAME}'@'%';
	FLUSH PRIVILEGES;
EOSQL" "Was not able to apply settings on database. Check error above. Exiting."
	unset MYSQL_PWD

	print_log "db_deletion: done" "Database deletion performed. Exiting."
	exit 0
}

db_setup(){
	print_log "initial_setup:info" "First time setup. Will wait..."
	exec_cmd "sleep ${DB_SETUP_WAIT:-20}s > /dev/null 2>&1" "DB_SETUP_WAIT variable is set incorrectly. Exiting."

	print_log "initial_setup:info" "Starting database set up"

	if [ "$version" == "testing" ]; then
		print_log "initial_setup:info" "Testing version detected. Looking for SQL script (simplerisk.sql) at /var/www/simplerisk/..."
		SCHEMA_FILE='/var/www/simplerisk/simplerisk.sql'
		exec_cmd "[ -f $SCHEMA_FILE ]" "SQL script not found. Exiting."
	else
		print_log "initial_setup:info" "Downloading schema..."
		SCHEMA_FILE='/tmp/simplerisk.sql'
		exec_cmd "curl -sL https://github.com/simplerisk/database/raw/master/simplerisk-en-$version.sql > $SCHEMA_FILE" "Could not download schema from Github. Exiting."
	fi

	print_log "initial_setup:info" "Applying changes to MySQL database... (MySQL error will be printed to console as guidance)"
	# Pass password via env var to avoid shell interpretation of special characters in the value
	export MYSQL_PWD="$DB_SETUP_PASS"
	# Using sql_mode = ANSI_QUOTES to avoid using backticks
	exec_cmd "mysql -u $DB_SETUP_USER -h$SIMPLERISK_DB_HOSTNAME -P$SIMPLERISK_DB_PORT <<EOSQL
	SET sql_mode = 'ANSI_QUOTES';
	CREATE DATABASE \"${SIMPLERISK_DB_DATABASE}\";
	USE \"${SIMPLERISK_DB_DATABASE}\";
	\. ${SCHEMA_FILE}
	CREATE USER \"${SIMPLERISK_DB_USERNAME}\"@\"%\" IDENTIFIED BY \"${SIMPLERISK_DB_PASSWORD}\";
EOSQL" "Was not able to apply settings on database. Check error above. Exiting."
	# Needed to separate the GRANT statement from the rest because it was providing a syntax error
	exec_cmd "mysql -u $DB_SETUP_USER -h$SIMPLERISK_DB_HOSTNAME -P$SIMPLERISK_DB_PORT <<EOSQL
	SET sql_mode = 'ANSI_QUOTES';
	GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON \"${SIMPLERISK_DB_DATABASE}\".* TO \"${SIMPLERISK_DB_USERNAME}\"@\"%\";
EOSQL" "Was not able to apply settings on database. Check error above. Exiting."
	unset MYSQL_PWD

	print_log "initial_setup:info" "Setup has been applied successfully!"
	print_log "initial_setup:info" "Removing schema file..."
	exec_cmd "rm ${SCHEMA_FILE}"

	# Update the SIMPLERISK_INSTALLED value
	exec_cmd "sed -i \"s/\('SIMPLERISK_INSTALLED', \)'false'/\1'true'/g\" $CONFIG_PATH"

	# Create admin user if ADMIN_USERNAME is provided (optional, non-fatal)
	if [ -n "${ADMIN_USERNAME:-}" ]; then
		exec_cmd_nobail "php /docker/configure-admin.php" || print_log "initial_setup:warn" "Admin user creation failed; check output above"
	fi

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
	unset SIMPLERISK_CSRF_SECRET
	unset SIMPLERISK_CRON_SETUP
	unset MAIL_TRANSPORT
	unset MAIL_FROM_EMAIL
	unset MAIL_FROM_NAME
	unset MAIL_REPLYTO_EMAIL
	unset MAIL_REPLYTO_NAME
	unset MAIL_HOST
	unset MAIL_SMTPAUTOTLS
	unset MAIL_SMTPAUTH
	unset MAIL_USERNAME
	unset MAIL_PASSWORD
	unset MAIL_ENCRYPTION
	unset MAIL_PORT
	unset MAIL_PREPEND
	unset ADMIN_USERNAME
	unset ADMIN_PASSWORD
	unset ADMIN_EMAIL
	unset ADMIN_NAME
}

_main() {
	validate_db_setup
	set_config
	set_cron
	if [[ -n ${DB_SETUP:-} ]]; then
	  DB_SETUP_USER="${DB_SETUP_USER:-root}"
	  DB_SETUP_PASS="${DB_SETUP_PASS:-root}"
	fi
	if [[ -n ${SIMPLERISK_CSRF_SECRET:-} ]]; then
	  set_csrf_secret
	fi
	# shellcheck disable=SC2015
	[[ "${DB_SETUP:-}" == "delete" ]] && delete_db || true
	# shellcheck disable=SC2015
	[[ "${DB_SETUP:-}" = automatic* ]] && db_setup || true
	set_mail_settings
	unset_variables
	exec "$@"
}

_main "$@"
