#!/bin/bash

CONFIG_PATH='/var/www/simplerisk/includes/config.php'

# Replacing config variables if they exist
if [ ! -z $SIMPLERISK_DB_HOSTNAME ]; then
    sed -i "s/\('DB_HOSTNAME', '\).*\(');\)/\1`echo $SIMPLERISK_DB_HOSTNAME`\2/g" $CONFIG_PATH
else
    SIMPLERISK_DB_HOSTNAME='localhost'
fi

if [ ! -z $SIMPLERISK_DB_PORT ]; then
    sed -i "s/\('DB_PORT', '\).*\(');\)/\1`echo $SIMPLERISK_DB_PORT`\2/g" $CONFIG_PATH
else
    SIMPLERISK_DB_PORT='3306'
fi

if [ ! -z $SIMPLERISK_DB_USERNAME ]; then
    sed -i "s/\('DB_USERNAME', '\).*\(');\)/\1`echo $SIMPLERISK_DB_USERNAME`\2/g" $CONFIG_PATH
else
    SIMPLERISK_DB_USERNAME='simplerisk'
fi

if [ ! -z $SIMPLERISK_DB_PASSWORD ]; then
    sed -i "s/\('DB_PASSWORD', '\).*\(');\)/\1`echo $SIMPLERISK_DB_PASSWORD`\2/g" $CONFIG_PATH
else
    SIMPLERISK_DB_PASSWORD='simplerisk'
fi

if [ ! -z $SIMPLERISK_DB_DATABASE ]; then
    sed -i "s/\('DB_DATABASE', '\).*\(');\)/\1`echo $SIMPLERISK_DB_DATABASE`\2/g" $CONFIG_PATH
else
    SIMPLERISK_DB_DATABASE='simplerisk'
fi

if [ ! -z $SIMPLERISK_DB_FOR_SESSIONS ]; then
    sed -i "s/\('USE_DATABASE_FOR_SESSIONS', '\).*\(');\)/\1`echo $SIMPLERISK_DB_FOR_SESSIONS`\2/g" $CONFIG_PATH
fi

if [ ! -z $SIMPLERISK_DB_SSL_CERT_PATH ]; then
    sed -i "s/\('DB_SSL_CERTIFICATE_PATH', '\).*\(');\)/\1`echo $SIMPLERISK_DB_SSL_CERT_PATH`\2/g" $CONFIG_PATH
fi

if [ ! -z $FIRST_TIME_SETUP ]; then
    echo "First time setup. Will wait"
    if [ -z $FIRST_TIME_SETUP_WAIT ]; then
        sleep `echo ${FIRST_TIME_SETUP_WAIT}s`
    else
        sleep 20
    fi

    echo "Starting preparation"

    echo "Downloading schema..."
    SCHEMA_FILE='/tmp/simplerisk.sql'
    curl -sL https://github.com/simplerisk/database/raw/master/simplerisk-en-`cat /tmp/version`.sql > $SCHEMA_FILE

    if [ ! -z $FIRST_TIME_SETUP_USER ]; then
        FIRST_TIME_SETUP_USER='root'
    fi
    
    if [ ! -z $FIRST_TIME_SETUP_PASS ]; then
        FIRST_TIME_SETUP_PASS='root'
    fi

    mysql --protocol=socket -u$FIRST_TIME_SETUP_USER -p$FIRST_TIME_SETUP_PASS -h$SIMPLERISK_DB_HOSTNAME -P$SIMPLERISK_DB_PORT <<EOSQL
    CREATE DATABASE '${SIMPLERISK_DB_DATABASE}';
    USE '${SIMPLERISK_DB_DATABASE}';
    \. /tmp/simplerisk.sql 
    CREATE USER '${SIMPLERISK_DB_USERNAME}'@'%' IDENTIFIED BY '${SIMPLERISK_DB_PASSWORD}';
    GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON '${SIMPLERISK_DB_DATABASE}'.* TO '${SIMPLERISK_DB_USERNAME}'@'%';
    EOSQL

fi

# Start Apache
/usr/sbin/apache2ctl -D FOREGROUND
