#!/bin/bash

# Start MySQL and wait 10 seconds
/etc/init.d/mysql start
sleep 10s

# If MySQL hasn't already been configured
if [ ! -f /configurations/mysql-configured ]; then
	# Set the MySQL root password
	mysqladmin -u root password `cat /passwords/pass_mysql_root.txt`

	# Create the SimpleRisk database
	mysql -uroot -p`cat /passwords/pass_mysql_root.txt` -e "create database simplerisk;"

	# Load the SimpleRisk database schema
	mysql -uroot -p`cat /passwords/pass_mysql_root.txt` -e "use simplerisk; \. /simplerisk.sql"

	# Set the permissions for th4e SimpleRisk database
	mysql -uroot -p`cat /passwords/pass_mysql_root.txt` -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'localhost' IDENTIFIED BY '`cat /passwords/pass_simplerisk.txt`'"

	# Create a file so this doesn't run again
	touch /configurations/mysql-configured
fi


# Start Apache
/usr/sbin/apache2ctl -D FOREGROUND
