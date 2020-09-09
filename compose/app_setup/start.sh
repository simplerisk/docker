#!/bin/bash

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

SETUP_COMPLETED='/tmp/database_completed'
if [ ! -z $FIRST_TIME_SETUP ] && [ ! -f $SETUP_COMPLETED ]; then
    echo "First time setup. Will wait"
    sleep `echo ${FIRST_TIME_SETUP_WAIT:-20}s`

    echo "Starting database set up"

    echo "Downloading schema..."
    SCHEMA_FILE='/tmp/simplerisk.sql'
    curl -sL https://github.com/simplerisk/database/raw/master/simplerisk-en-`cat /tmp/version`.sql > $SCHEMA_FILE

    FIRST_TIME_SETUP_USER="{$FIRST_TIME_SETUP_USER:-root}"
    FIRST_TIME_SETUP_PASS="{$FIRST_TIME_SETUP_PASS:-root}"

    echo "Applying changes to MySQL database..."
    mysql --protocol=socket -u $FIRST_TIME_SETUP_USER -p $FIRST_TIME_SETUP_PASS -h $SIMPLERISK_DB_HOSTNAME -P $SIMPLERISK_DB_PORT <<EOSQL
    CREATE DATABASE ${SIMPLERISK_DB_DATABASE};
    USE ${SIMPLERISK_DB_DATABASE};
    \. /tmp/simplerisk.sql 
    CREATE USER ${SIMPLERISK_DB_USERNAME}@'%' IDENTIFIED BY '${SIMPLERISK_DB_PASSWORD}';
    GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON ${SIMPLERISK_DB_DATABASE}.* TO ${SIMPLERISK_DB_USERNAME}@'%';
EOSQL

    echo "Setup has been applied successfully!"
    touch $SETUP_COMPLETED

fi

# Start Apache
/usr/sbin/apache2ctl -D FOREGROUND
