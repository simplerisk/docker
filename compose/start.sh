# Replace password on config
cat /var/www/simplerisk/includes/config.php | sed "s/DB_PASSWORD', 'simplerisk/DB_PASSWORD', '`echo $SIMPLERISK_PASS`/" > /var/www/simplerisk/includes/config.php
# Start Apache
/usr/sbin/apache2ctl -D FOREGROUND
