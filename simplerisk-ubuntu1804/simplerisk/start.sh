#!/bin/bash

# Update the Apache config from the ENV vars
mkdir -p /etc/apache2/ssl/ssl.key
echo ${PRIVATE_KEY} | sed 's/\\n/\n/g' > /etc/apache2/ssl/ssl.key/simplerisk.key
mkdir -p /etc/apache2/ssl/ssl.crt
echo ${CERTIFICATE} | sed 's/\\n/\n/g' > /etc/apache2/ssl/ssl.crt/simplerisk.crt

# Update the SimpleRisk config file from the ENV vars
cat /var/www/config.orig.php | sed "s/DB_HOSTNAME', 'localhost/DB_HOSTNAME', 'database/" | sed "s/DB_PASSWORD', 'simplerisk/DB_PASSWORD', '$MYSQL_PASSWORD/" > /var/www/simplerisk/includes/config.php

# Start Apache
/usr/sbin/apache2ctl -D FOREGROUND
