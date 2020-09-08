if [ -n $SIMPLERISK_DB_HOSTNAME ]; then
	cat /var/www/simplerisk/includes/config.php | sed "s/\('DB_HOSTNAME', '\).*\(');\)/\1`echo $SIMPLERISK_DB_HOSTNAME`\2/g" > /var/www/simplerisk/includes/config.php
fi

if [ -n $SIMPLERISK_DB_PORT ]; then
	cat /var/www/simplerisk/includes/config.php | sed "s/\('DB_PORT', '\).*\(');\)/\1`echo $SIMPLERISK_DB_PORT`\2/g" > /var/www/simplerisk/includes/config.php
fi

if [ -n $SIMPLERISK_DB_USERNAME ]; then
	cat /var/www/simplerisk/includes/config.php | sed "s/\('DB_USERNAME', '\).*\(');\)/\1`echo $SIMPLERISK_DB_USERNAME`\2/g" > /var/www/simplerisk/includes/config.php
fi

if [ -n $SIMPLERISK_DB_PASS ]; then
	cat /var/www/simplerisk/includes/config.php | sed "s/\('DB_PASSWORD', '\).*\(');\)/\1`echo $SIMPLERISK_DB_PASSWORD`\2/g" > /var/www/simplerisk/includes/config.php
fi

if [ -n $SIMPLERISK_DB_DATABASE ]; then
	cat /var/www/simplerisk/includes/config.php | sed "s/\('DB_DATABASE', '\).*\(');\)/\1`echo $SIMPLERISK_DB_DATABASE`\2/g" > /var/www/simplerisk/includes/config.php
fi

if [ -n $SIMPLERISK_DB_FOR_SESSIONS ]; then
	cat /var/www/simplerisk/includes/config.php | sed "s/\('USE_DATABASE_FOR_SESSIONS', '\).*\(');\)/\1`echo $SIMPLERISK_DB_FOR_SESSIONS`\2/g" > /var/www/simplerisk/includes/config.php
fi

if [ -n $SIMPLERISK_SSL_CERT_PATH ]; then
	cat /var/www/simplerisk/includes/config.php | sed "s/\('DB_SSL_CERTIFICATE_PATH', '\).*\(');\)/\1`echo $SIMPLERISK_DB_HOSTNAME`\2/g" > /var/www/simplerisk/includes/config.php
fi
