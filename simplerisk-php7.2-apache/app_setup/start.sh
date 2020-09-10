#!/bin/bash

set -eo pipefail

print_log(){
    echo "$(date -u +"[%a %b %e %X.%6N %Y]") [$1] $2"
}

exec_cmd(){
    exec_cmd_nobail "$1" || fatal_error "$2" $?
}

exec_cmd_nobail() {
    bash -c "$1"
}

fatal_error(){
    echo "$2"
    print_log "error" "$1"
    exit 1
}

set_config(){
    CONFIG_PATH='/var/www/simplerisk/includes/config.php'

    # Replacing config variables if they exist
    if [ ! -z $SIMPLERISK_DB_HOSTNAME ]; then
        sed -i "s/\('DB_HOSTNAME', '\).*\(');\)/\1`echo $SIMPLERISK_DB_HOSTNAME`\2/g" $CONFIG_PATH
    fi
    SIMPLERISK_DB_HOSTNAME="${SIMPLERISK_DB_HOSTNAME:-localhost}"

    if [ ! -z $SIMPLERISK_DB_PORT ]; then
        sed -i "s/\('DB_PORT', '\).*\(');\)/\1`echo $SIMPLERISK_DB_PORT`\2/g" $CONFIG_PATH
    fi
    SIMPLERISK_DB_PORT="${SIMPLERISK_DB_PORT:-3306}"

    if [ ! -z $SIMPLERISK_DB_USERNAME ]; then
        sed -i "s/\('DB_USERNAME', '\).*\(');\)/\1`echo $SIMPLERISK_DB_USERNAME`\2/g" $CONFIG_PATH
    fi
    SIMPLERISK_DB_USERNAME="${SIMPLERISK_DB_USERNAME:-simplerisk}"

    if [ ! -z $SIMPLERISK_DB_PASSWORD ]; then
        sed -i "s/\('DB_PASSWORD', '\).*\(');\)/\1`echo $SIMPLERISK_DB_PASSWORD`\2/g" $CONFIG_PATH
    fi
    SIMPLERISK_DB_PASSWORD="${SIMPLERISK_DB_PASSWORD:-simplerisk}"

    if [ ! -z $SIMPLERISK_DB_DATABASE ]; then
        sed -i "s/\('DB_DATABASE', '\).*\(');\)/\1`echo $SIMPLERISK_DB_DATABASE`\2/g" $CONFIG_PATH
    fi
    SIMPLERISK_DB_DATABASE="${SIMPLERISK_DB_DATABASE:-simplerisk}"

    if [ ! -z $SIMPLERISK_DB_FOR_SESSIONS ]; then
        sed -i "s/\('USE_DATABASE_FOR_SESSIONS', '\).*\(');\)/\1`echo $SIMPLERISK_DB_FOR_SESSIONS`\2/g" $CONFIG_PATH
    fi

    if [ ! -z $SIMPLERISK_DB_SSL_CERT_PATH ]; then
        sed -i "s/\('DB_SSL_CERTIFICATE_PATH', '\).*\(');\)/\1`echo $SIMPLERISK_DB_SSL_CERT_PATH`\2/g" $CONFIG_PATH
    fi
}

db_setup(){
    print_log "info" "First time setup. Will wait..."
    exec_cmd "sleep `echo ${FIRST_TIME_SETUP_WAIT:-2O}`s > /dev/null 2>&1" "FIRST_TIME_SETUP_WAIT variable is set incorrectly. Exiting."

    print_log "info" "Starting database set up"

    print_log "info" "Downloading schema..."
    SCHEMA_FILE='/tmp/simplerisk.sql'
    exec_cmd "curl -sL https://github.com/simplerisk/database/raw/master/simplerisk-en-`cat /tmp/version`.sql > $SCHEMA_FILE 2&>1" "Could not download schema from Github. Exiting."

    FIRST_TIME_SETUP_USER="${FIRST_TIME_SETUP_USER:-root}"
    FIRST_TIME_SETUP_PASS="${FIRST_TIME_SETUP_PASS:-root}"

    print_log "info" "Applying changes to MySQL database... (MySQL error will be printed to console as guidance)"
    exec_cmd "mysql --protocol=socket -u $FIRST_TIME_SETUP_USER -p$FIRST_TIME_SETUP_PASS -h$SIMPLERISK_DB_HOSTNAME -P$SIMPLERISK_DB_PORT <<EOSQL
    CREATE DATABASE ${SIMPLERISK_DB_DATABASE};
    USE ${SIMPLERISK_DB_DATABASE};
    \. /tmp/simplerisk.sql 
    CREATE USER ${SIMPLERISK_DB_USERNAME}@'%' IDENTIFIED BY '${SIMPLERISK_DB_PASSWORD}';
    GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON ${SIMPLERISK_DB_DATABASE}.* TO ${SIMPLERISK_DB_USERNAME}@'%';
EOSQL" "Was not able to apply settings on database. Check error above. Exiting."

    print_log "info" "Setup has been applied successfully!"

    if [ ! -z $FIRST_TIME_SETUP_ONLY ]; then
        print_log "info" "Running on setup only. Container will be discarded."
        exit 0
    fi
}

_main() {
    
    set_config
    if [ ! -z $FIRST_TIME_SETUP ]; then
      db_setup
    fi
    /usr/sbin/apache2ctl -D FOREGROUND
}

_main