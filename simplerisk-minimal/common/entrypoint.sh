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

# Escape a value for use as the replacement in a sed s|...|VALUE|... command.
# Escapes \, &, | and newlines so they aren't interpreted as sed metacharacters
# or terminate the s command. Required for any env-var-derived value that may
# contain / (which would otherwise terminate the / delimiter the sed
# substitution used to use). Done with parameter expansion (not a sed pipe) so
# embedded newlines survive.
sed_escape() {
	local v="$1"
	v="${v//\\/\\\\}"
	v="${v//&/\\&}"
	v="${v//|/\\|}"
	v="${v//$'\n'/\\$'\n'}"
	printf '%s' "$v"
}

# Escape a value for a PHP single-quoted string literal ('...'): only \ and '
# are special there, so a value can neither close the string nor inject code.
php_sq_escape() {
	local v="$1"
	v="${v//\\/\\\\}"
	v="${v//\'/\\\'}"
	printf '%s' "$v"
}

# Escape a value for a MySQL single-quoted string literal ('...').
sql_str_escape() {
	local v="$1"
	v="${v//\\/\\\\}"
	v="${v//\'/\\\'}"
	printf '%s' "$v"
}

# Escape a value for a MySQL ANSI_QUOTES identifier ("...").
sql_ident_escape() {
	local v="$1"
	printf '%s' "${v//\"/\"\"}"
}

# Rewrite define('NAME', '...'); in $CONFIG_PATH. The value is PHP-escaped first
# (so it cannot break out of the string in config.php) and then sed-escaped.
config_define() {
	local name="$1" value="$2"
	sed -i "s|\('${name}', '\).*\(');\)|\1$(sed_escape "$(php_sq_escape "$value")")\2|g" "$CONFIG_PATH"
}

# Run the mysql client as the privileged setup user, reading SQL from stdin.
# Arguments are passed as an argv array (never through a shell string), and the
# password via MYSQL_PWD, so no value is subject to shell interpretation.
mysql_setup() {
	local -a flags=()
	# DB_SSL_FLAGS is an internal value from set_db_ssl_flags (client-specific TLS flags)
	[ -n "${DB_SSL_FLAGS:-}" ] && read -ra flags <<< "$DB_SSL_FLAGS"
	MYSQL_PWD="$DB_SETUP_PASS" mysql ${flags[@]+"${flags[@]}"} \
		-u "$DB_SETUP_USER" -h "$SIMPLERISK_DB_HOSTNAME" -P "$SIMPLERISK_DB_PORT"
}

fatal_error(){
	print_log "error" "$1"
	exit 1
}

# Docker/Kubernetes secrets support: if VAR_FILE is set, read VAR from the file it
# points to (typically /run/secrets/<name>), so credentials need not live in the
# container's environment. Setting both VAR and VAR_FILE is an error. The _FILE
# variable is unset afterwards so it is not inherited by child processes.
file_env() {
	local var="$1"
	local file_var="${var}_FILE"
	local var_val="${!var:-}"
	local file_val="${!file_var:-}"

	if [ -n "$var_val" ] && [ -n "$file_val" ]; then
		fatal_error "Both $var and $file_var are set (but are exclusive)."
	fi

	if [ -n "$file_val" ]; then
		[ -r "$file_val" ] || fatal_error "$file_var points to '$file_val', which is not a readable file."
		# $(< file) strips trailing newlines, which secret files commonly end with
		export "$var=$(< "$file_val")"
	fi
	unset "$file_var"
}

load_file_envs() {
	local var
	for var in \
		DB_SETUP_USER DB_SETUP_PASS \
		SIMPLERISK_DB_HOSTNAME SIMPLERISK_DB_PORT SIMPLERISK_DB_USERNAME \
		SIMPLERISK_DB_PASSWORD SIMPLERISK_DB_DATABASE \
		SIMPLERISK_CSRF_SECRET \
		MAIL_USERNAME MAIL_PASSWORD \
		ADMIN_USERNAME ADMIN_PASSWORD; do
		file_env "$var"
	done
}

set_db_password(){
	if [[ "${DB_SETUP:-}" = automatic* ]]; then
		# shellcheck disable=SC2015
		[ -z "${SIMPLERISK_DB_PASSWORD:-}" ] && SIMPLERISK_DB_PASSWORD=$(generate_random_password) && print_log "initial_setup:warn" "As no password was provided and this is a first time setup, a random password has been generated ($SIMPLERISK_DB_PASSWORD)"
	else
		SIMPLERISK_DB_PASSWORD=${SIMPLERISK_DB_PASSWORD:-simplerisk}
	fi
	config_define DB_PASSWORD "$SIMPLERISK_DB_PASSWORD"
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

validate_db_upgrade(){
	case "${DB_UPGRADE:-}" in
		automatic)
			print_log "initial_info:upgrade" "Database schema will be upgraded";;
		automatic-only)
			print_log "initial_info:upgrade" "Database schema will be upgraded and the container removed";;
		"")
			: ;;  # not set — no upgrade
		*)
			fatal_error "The provided option for DB_UPGRADE is invalid. It must be automatic or automatic-only.";;
	esac
}

set_config(){
	local CONFIG_PATH='/var/www/simplerisk/includes/config.php'
	local CONFIG_SAMPLE_PATH='/var/www/simplerisk/includes/config.sample.php'

	# Copy the sample config into place. The new SimpleRisk release ships
	# config.sample.php; the entrypoint creates config.php from it before
	# substituting env-var-driven values. For users upgrading from an older
	# image on a persisted /var/www/simplerisk volume, config.sample.php
	# won't be present — fall back to reusing the existing config.php, which
	# the subsequent sed substitutions will rewrite in place.
	if [ -f "$CONFIG_SAMPLE_PATH" ]; then
		cp "$CONFIG_SAMPLE_PATH" "$CONFIG_PATH"
	elif [ ! -f "$CONFIG_PATH" ]; then
		fatal_error "Neither $CONFIG_SAMPLE_PATH nor $CONFIG_PATH is present. The /var/www/simplerisk volume appears to be in an inconsistent state."
	else
		print_log "initial_setup:info" "$CONFIG_SAMPLE_PATH not found; reusing existing $CONFIG_PATH (likely upgrading from an older image on a persisted volume)."
	fi

	# Replacing config variables. Values are run through sed_escape so paths
	# or other inputs containing \, &, or | don't break the substitution.
	SIMPLERISK_DB_HOSTNAME=${SIMPLERISK_DB_HOSTNAME:-localhost}
	config_define DB_HOSTNAME "$SIMPLERISK_DB_HOSTNAME"

	SIMPLERISK_DB_PORT=${SIMPLERISK_DB_PORT:-3306}
	config_define DB_PORT "$SIMPLERISK_DB_PORT"

	SIMPLERISK_DB_USERNAME=${SIMPLERISK_DB_USERNAME:-simplerisk}
	config_define DB_USERNAME "$SIMPLERISK_DB_USERNAME"

	set_db_password

	SIMPLERISK_DB_DATABASE=${SIMPLERISK_DB_DATABASE:-simplerisk}
	config_define DB_DATABASE "$SIMPLERISK_DB_DATABASE"

	SIMPLERISK_DB_FOR_SESSIONS=${SIMPLERISK_DB_FOR_SESSIONS:-true}
	config_define USE_DATABASE_FOR_SESSIONS "$SIMPLERISK_DB_FOR_SESSIONS"

	if [ -n "${SIMPLERISK_DB_SSL_CERT_PATH:-}" ]; then
		# The sample ships DB_SSL_CERTIFICATE_PATH as a commented-out line so
		# that operators who don't set the env var don't end up requesting SSL
		# against a non-existent cert path. When a path is supplied, rewrite
		# the whole line (commented or not) as an active define.
		escaped_ssl_path=$(sed_escape "$(php_sq_escape "$SIMPLERISK_DB_SSL_CERT_PATH")")
		sed -i "s|^[[:space:]]*\(//[[:space:]]*\)\{0,1\}define('DB_SSL_CERTIFICATE_PATH', '[^']*');|define('DB_SSL_CERTIFICATE_PATH', '${escaped_ssl_path}');|" "$CONFIG_PATH"
	fi


	# DEMO_MODE — restricts a public demo instance (uploads, password change,
	# language change). Deliberately NOT a placeholder in config.sample.php: this
	# is a hosting-platform concern, not a self-hosted option, so it is APPENDED
	# only when asked for and is invisible to everyone else. config.sample.php has
	# no closing "?>", so an appended define lands inside PHP.
	#
	# ONLY an explicitly true value activates it. PHP treats the STRING 'false' as
	# truthy, so writing define('DEMO_MODE', 'false') would put EVERY customer into
	# demo mode. The constant's PRESENCE is the signal — core checks
	# defined('DEMO_MODE'), not its value.
	#
	# The grep guard matters for the fallback path above: when config.sample.php is
	# absent the existing config.php is reused rather than regenerated, so an
	# unguarded append would redefine the constant on every boot.
	case "$(printf '%s' "${SIMPLERISK_DEMO_MODE:-}" | tr '[:upper:]' '[:lower:]')" in
		true|1|yes|on)
			if grep -q "define('DEMO_MODE'" "$CONFIG_PATH"; then
				print_log "initial_setup:info" "DEMO_MODE already present in $CONFIG_PATH; leaving it alone."
			else
				printf "\n// Set by the hosting platform when demo_mode is enabled for this\n// instance. Not a self-hosted configuration option.\ndefine('DEMO_MODE', 'true');\n" >> "$CONFIG_PATH"
				print_log "initial_setup:info" "DEMO_MODE enabled."
			fi
			;;
		"")
			;;
		*)
			print_log "initial_setup:info" "SIMPLERISK_DEMO_MODE is set to a non-true value; demo mode NOT enabled."
			;;
	esac

	# Optional service endpoint overrides, for instances that must talk to the
	# test estate rather than production. Same shape as DEMO_MODE above: no
	# placeholder in config.sample.php, appended only when supplied, so an
	# instance that says nothing keeps the code's built-in production defaults.
	#
	# All five are written when supplied, on purpose. LICENSING_URL superseded
	# SERVICES_URL and PING_URL when registration and ping were merged into the
	# licensing service (July 2026 release) — but the platform runs different
	# images per release channel, and an instance on an older image still reads
	# the legacy pair. Writing whichever ones are supplied keeps one config
	# correct across both.
	#
	# Every consumer is defined()-guarded with a production fallback, so a
	# constant that a given image does not know about is simply ignored.
	for _url_const in SERVICES_URL UPDATES_URL PING_URL BUNDLES_URL LICENSING_URL; do
		_url_env="SIMPLERISK_${_url_const}"
		_url_val="${!_url_env:-}"

		[ -z "$_url_val" ] && continue

		# Only http(s), and no quote or backslash — the value is interpolated into
		# a single-quoted PHP string, and this is config we generate, not input we
		# need to be clever about.
		case "$_url_val" in
			https://*|http://*) ;;
			*)
				print_log "initial_setup:info" "$_url_env is not an http(s) URL; ignoring."
				continue
				;;
		esac
		case "$_url_val" in
			*\'*|*\\*)
				print_log "initial_setup:info" "$_url_env contains a quote or backslash; ignoring."
				continue
				;;
		esac

		if grep -q "define('${_url_const}'" "$CONFIG_PATH"; then
			print_log "initial_setup:info" "${_url_const} already present in $CONFIG_PATH; leaving it alone."
		else
			printf "\ndefine('%s', '%s');\n" "$_url_const" "$_url_val" >> "$CONFIG_PATH"
			print_log "initial_setup:info" "${_url_const} set to ${_url_val}."
		fi
	done
}

set_csrf_secret(){
	CSRF_SECRET_PATH='/var/www/simplerisk/vendor/simplerisk/csrf-magic/csrf-secret.php'

	# If a SIMPLERISK_CSRF_SECRET value was specified create the csrf-secret.php file with that value
	# (single-quoted PHP string, escaped, so the value cannot inject code or be interpolated)
	# shellcheck disable=SC2015
	[ -n "${SIMPLERISK_CSRF_SECRET:-}" ] && printf "<?php \$secret = '%s'; ?>\n" "$(php_sq_escape "$SIMPLERISK_CSRF_SECRET")" > "$CSRF_SECRET_PATH" || true
}

set_ssl_certificate(){
	# Generate Apache's self-signed TLS key pair at container startup rather
	# than at image build time. A key baked into the image (the previous
	# behavior) is identical in every copy of the image anyone pulls, and was
	# additionally being registered as a trusted CA in the container's system
	# trust store -- anyone who extracted that key could forge certs the
	# container's own outbound curl calls would accept (HackerOne #3764027).
	# Generating here means each deployment gets its own key, and idempotence
	# (skip if already present) means an existing cert persisted in the
	# /etc/apache2/ssl volume survives container restarts/recreation.
	local ssl_dir='/etc/apache2/ssl/simplerisk'
	local key="$ssl_dir/simplerisk.key"
	local crt="$ssl_dir/simplerisk.crt"

	if [ -f "$key" ] && [ -f "$crt" ]; then
		return 0
	fi

	print_log "ssl_setup:info" "No Apache TLS certificate found; generating a self-signed one for this container."
	exec_cmd "mkdir -p $ssl_dir" "Failed to create SSL certificate directory. Exiting."
	# basicConstraints=CA:FALSE is explicit because openssl's own default
	# x509 extensions otherwise mark a self-signed leaf cert as CA:TRUE,
	# which Apache logs a warning about on every start.
	exec_cmd "openssl req -x509 -newkey rsa:2048 -nodes -keyout $key -out $crt -days 365 -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,DNS:simplerisk,IP:127.0.0.1,IP:0.0.0.0' -addext 'basicConstraints=critical,CA:FALSE' -addext 'keyUsage=critical,digitalSignature,keyEncipherment' -addext 'extendedKeyUsage=serverAuth'" "Failed to generate self-signed TLS certificate. Exiting."
	exec_cmd "chmod 600 $key" "Failed to set permissions on TLS private key. Exiting."
}

set_apache_workers(){
	# Optional cap on how many requests Apache serves at once. Every request
	# holds a database connection, so the default of 150 workers can exceed a
	# small database's max_connections (a db.t3.micro allows about 60), and
	# several containers sharing one database multiply it. The right number
	# depends on the database and the replica count, which the image cannot
	# know, so it is left to the operator. Unset keeps Apache's default.
	local workers="${APACHE_MAX_REQUEST_WORKERS:-}"
	local conf="${APACHE_MPM_CONF_PATH:-/etc/apache2/conf-enabled/simplerisk-mpm.conf}"

	# Remove what a previous start wrote, so unsetting the variable on a
	# restarted container goes back to Apache's default
	rm -f "$conf"

	if [ -z "$workers" ]; then
		return 0
	fi

	# Strip leading zeros and bound the length before any arithmetic: bash
	# arithmetic wraps at 64 bits, so a very long digit string could otherwise
	# wrap into the valid range
	local digits="${workers#"${workers%%[!0]*}"}"

	if ! [[ "$workers" =~ ^[0-9]+$ ]] || [ -z "$digits" ] || [ "${#digits}" -gt 4 ] || [ "$digits" -gt 2000 ]; then
		print_log "apache_setup:warn" "APACHE_MAX_REQUEST_WORKERS must be a whole number between 1 and 2000 -- leaving Apache's default."
		return 0
	fi

	workers="$digits"

	local content="# Written by the container entrypoint from APACHE_MAX_REQUEST_WORKERS"$'\n'"<IfModule mpm_prefork_module>"$'\n'
	# ServerLimit defaults to 256 and silently caps MaxRequestWorkers
	if [ "$workers" -gt 256 ]; then
		content+=$'\t'"ServerLimit ${workers}"$'\n'
	fi
	content+=$'\t'"MaxRequestWorkers ${workers}"$'\n'"</IfModule>"

	# Do not claim a cap that was not applied: if the file cannot be written
	# (for example a read-only root filesystem), say so and keep the default.
	# A single printf is used because a failed redirect on a { } group does not
	# reliably report failure.
	if ! printf '%s\n' "$content" > "$conf"; then
		print_log "apache_setup:error" "Could not write ${conf} -- leaving Apache's default."
		rm -f "$conf" || true
		return 0
	fi

	print_log "apache_setup:info" "Apache will serve at most ${workers} requests at once."
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
	local escaped
	escaped=$(sql_str_escape "$value")
	# No --ssl-mode override: the client's default (PREFERRED) negotiates TLS when the
	# server offers it. Forcing DISABLED made MySQL 8's caching_sha2_password refuse the
	# first login ("Authentication requires secure connection"), silently skipping
	# every mail setting that needs the app user's password.
	MYSQL_PWD="$SIMPLERISK_DB_PASSWORD" mysql -u "$SIMPLERISK_DB_USERNAME" \
	      -h "$SIMPLERISK_DB_HOSTNAME" \
	      -P "$SIMPLERISK_DB_PORT" \
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

# True when the mysql client understands --ssl-mode. Oracle's client does (amd64 image). MariaDB's
# does not, and it is the only client packaged for arm64 (MySQL's apt repo has no arm64 builds), so
# there `mysql` rejects it with "unknown variable 'ssl-mode=REQUIRED'". If the client cannot be asked,
# assume Oracle's, which is what these flags were written for.
mysql_client_supports_ssl_mode() {
	local help
	help=$(mysql --help 2>/dev/null) || return 0
	[ -n "$help" ] || return 0
	grep -q -- '--ssl-mode' <<< "$help"
}

set_db_ssl_flags(){
	# Some databases require the privileged setup/delete mysql client to send
	# its credential via the cleartext auth plugin, which the server only
	# accepts over TLS (e.g. when DB_SETUP_PASS is a short-lived auth token
	# rather than a static password). Set DB_SSL_ENABLED=true to opt in.
	DB_SSL_FLAGS=""
	if [ "${DB_SSL_ENABLED:-}" = "true" ]; then
		if mysql_client_supports_ssl_mode; then
			DB_SSL_FLAGS="--ssl-mode=REQUIRED --enable-cleartext-plugin"
		else
			# MariaDB client: --ssl makes TLS mandatory and --skip-ssl-verify-server-cert matches
			# REQUIRED (encrypt, do not verify the certificate). The cleartext plugin is built in;
			# --enable-cleartext-plugin is obsolete there and only prints a warning.
			DB_SSL_FLAGS="--ssl --skip-ssl-verify-server-cert"
		fi
	fi
}

delete_db(){
	print_log "db_deletion: prepare" "Performing database deletion"

	# Pass password via env var to avoid shell interpretation of special characters in the value
	mysql_setup <<EOSQL || fatal_error "Was not able to apply settings on database. Check error above. Exiting."
	SET sql_mode = 'ANSI_QUOTES';
	DROP DATABASE "$(sql_ident_escape "$SIMPLERISK_DB_DATABASE")";
	USE mysql;
	DROP USER '$(sql_str_escape "$SIMPLERISK_DB_USERNAME")'@'%';
	FLUSH PRIVILEGES;
EOSQL

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
	# Using sql_mode = ANSI_QUOTES for identifiers; string values are single-quoted
	# and escaped, so no value is interpreted by a shell or by the SQL parser.
	local db_ident user_str pass_str
	db_ident=$(sql_ident_escape "$SIMPLERISK_DB_DATABASE")
	user_str=$(sql_str_escape "$SIMPLERISK_DB_USERNAME")
	pass_str=$(sql_str_escape "$SIMPLERISK_DB_PASSWORD")
	mysql_setup <<EOSQL || fatal_error "Was not able to apply settings on database. Check error above. Exiting."
	SET sql_mode = 'ANSI_QUOTES';
	CREATE DATABASE "${db_ident}";
	USE "${db_ident}";
	\. ${SCHEMA_FILE}
	CREATE USER '${user_str}'@'%' IDENTIFIED BY '${pass_str}';
EOSQL
	# Needed to separate the GRANT statement from the rest because it was providing a syntax error
	mysql_setup <<EOSQL || fatal_error "Was not able to apply settings on database. Check error above. Exiting."
	SET sql_mode = 'ANSI_QUOTES';
	GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON "${db_ident}".* TO '${user_str}'@'%';
EOSQL

	print_log "initial_setup:info" "Setup has been applied successfully!"
	print_log "initial_setup:info" "Removing schema file..."
	exec_cmd "rm ${SCHEMA_FILE}"

	# Create admin user if ADMIN_USERNAME is provided (optional, non-fatal)
	if [ -n "${ADMIN_USERNAME:-}" ]; then
		exec_cmd_nobail "php /docker/configure-admin.php" || print_log "initial_setup:warn" "Admin user creation failed; check output above"
	fi

	# shellcheck disable=SC2015
	[ "${DB_SETUP:-}" = "automatic-only" ] && print_log "initial_setup:info" "Running setup only (automatic-only). Container will be discarded." && exit 0 || true
}

db_upgrade(){
	# Headless schema upgrade: run SimpleRisk's core release-by-release schema
	# upgrade (run_database_upgrade_structured) via /db-upgrade.php against the
	# instance's own database. config.php is already rendered by set_config. For
	# automatic-only (the one-shot Job), exit with the CLI's status so a failed
	# upgrade fails the Job; otherwise continue to serve.
	print_log "initial_info:upgrade" "Running headless database schema upgrade"
	local rc=0
	php /db-upgrade.php || rc=$?
	if [ "${DB_UPGRADE:-}" = "automatic-only" ]; then
		# shellcheck disable=SC2015
		[ "$rc" -eq 0 ] \
			&& print_log "initial_setup:info" "Upgrade only (automatic-only). Container will be discarded." \
			|| print_log "initial_setup:error" "Schema upgrade failed (exit $rc). Container will be discarded."
		exit "$rc"
	fi
	return "$rc"
}

unset_variables() {
	unset DB_SETUP
	unset DB_SETUP_USER
	unset DB_SETUP_PASS
	unset DB_SETUP_WAIT
	unset DB_UPGRADE
	unset DB_SSL_ENABLED
	unset DB_SSL_FLAGS
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
	load_file_envs

	set_ssl_certificate

	# Detect whether the operator has opted into Docker-managed config
	# provisioning. If no DB env vars are set, leave config.php absent so
	# SimpleRisk's web installer runs on first request.
	local docker_managed_config=false
	if [ -n "${DB_SETUP:-}" ] \
	    || [ -n "${SIMPLERISK_DB_HOSTNAME:-}" ] \
	    || [ -n "${SIMPLERISK_DB_PORT:-}" ] \
	    || [ -n "${SIMPLERISK_DB_USERNAME:-}" ] \
	    || [ -n "${SIMPLERISK_DB_PASSWORD:-}" ] \
	    || [ -n "${SIMPLERISK_DB_DATABASE:-}" ] \
	    || [ -n "${SIMPLERISK_DB_FOR_SESSIONS:-}" ] \
	    || [ -n "${SIMPLERISK_DB_SSL_CERT_PATH:-}" ]; then
		docker_managed_config=true
	fi

	if [ "$docker_managed_config" = true ]; then
		validate_db_setup
		validate_db_upgrade
		set_config
	else
		print_log "initial_setup:info" "No DB env vars provided; config.php will not be written. The SimpleRisk web installer will run at first request."
	fi

	set_apache_workers

	set_cron

	if [[ -n ${DB_SETUP:-} ]]; then
	  DB_SETUP_USER="${DB_SETUP_USER:-root}"
	  DB_SETUP_PASS="${DB_SETUP_PASS:-root}"
	  set_db_ssl_flags
	fi

	if [[ -n ${SIMPLERISK_CSRF_SECRET:-} ]]; then
	  set_csrf_secret
	fi

	if [ "$docker_managed_config" = true ]; then
		# shellcheck disable=SC2015
		[[ "${DB_SETUP:-}" == "delete" ]] && delete_db || true
		# shellcheck disable=SC2015
		[[ "${DB_SETUP:-}" = automatic* ]] && db_setup || true
		# shellcheck disable=SC2015
		[[ "${DB_UPGRADE:-}" = automatic* ]] && db_upgrade || true
		set_mail_settings
	fi

	unset_variables
	exec "$@"
}

_main "$@"
