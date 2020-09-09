#!/bin/bash

CONFIG_PATH=/var/www/simplerisk/includes/config.php

# Replacing config variables if they exist
if [ ! -z $SIMPLERISK_DB_HOSTNAME ]; then
    echo "Using provided hostname"
    sed -i "s/\('DB_HOSTNAME', '\).*\(');\)/\1`echo $SIMPLERISK_DB_HOSTNAME`\2/g" $CONFIG_PATH
fi

if [ ! -z $SIMPLERISK_DB_PORT ]; then
    echo "Using provided port"
    sed -i "s/\('DB_PORT', '\).*\(');\)/\1`echo $SIMPLERISK_DB_PORT`\2/g" $CONFIG_PATH
fi

if [ ! -z $SIMPLERISK_DB_USERNAME ]; then
    echo "Using provided username"
    sed -i "s/\('DB_USERNAME', '\).*\(');\)/\1`echo $SIMPLERISK_DB_USERNAME`\2/g" $CONFIG_PATH
fi

if [ ! -z $SIMPLERISK_DB_PASSWORD ]; then
    echo "Using provided password"
    sed -i "s/\('DB_PASSWORD', '\).*\(');\)/\1`echo $SIMPLERISK_DB_PASSWORD`\2/g" $CONFIG_PATH
fi

if [ ! -z $SIMPLERISK_DB_DATABASE ]; then
    echo "Using provided database"
    sed -i "s/\('DB_DATABASE', '\).*\(');\)/\1`echo $SIMPLERISK_DB_DATABASE`\2/g" $CONFIG_PATH
fi

if [ ! -z $SIMPLERISK_DB_FOR_SESSIONS ]; then
    echo "Using provided sessions"
    sed -i "s/\('USE_DATABASE_FOR_SESSIONS', '\).*\(');\)/\1`echo $SIMPLERISK_DB_FOR_SESSIONS`\2/g" $CONFIG_PATH
fi

if [ ! -z $SIMPLERISK_DB_SSL_CERT_PATH ]; then
    echo "Using provided ssl"
    sed -i "s/\('DB_SSL_CERTIFICATE_PATH', '\).*\(');\)/\1`echo $SIMPLERISK_DB_SSL_CERT_PATH`\2/g" $CONFIG_PATH
fi

# Start Apache
/usr/sbin/apache2ctl -D FOREGROUND
