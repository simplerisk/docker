# Use the trusty image
FROM ubuntu:trusty

# Maintained by SimpleRisk
MAINTAINER SimpleRisk <support@simplerisk.com>

# Make necessary directories
RUN mkdir -p /passwords
RUN mkdir -p /configurations
RUN mkdir -p /var/log
RUN mkdir -p /var/lib/mysql
RUN mkdir -p /etc/apache2/ssl
RUN mkdir -p /var/www/simplerisk

# Update the image to the latest packages
RUN apt-get update && apt-get upgrade -y

# Install required packages
RUN dpkg-divert --local --rename /usr/bin/ischroot && ln -sf /bin/true /usr/bin/ischroot
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install libapache2-mod-php5 pwgen python-setuptools vim-tiny php5-mysql mysql-client mysql-server apache2 sendmail php5-json php5-mcrypt php5-ldap openssl ufw

# Create the OpenSSL password
RUN pwgen -cn 20 1 > /passwords/pass_openssl.txt

# Create the MySQL root password
RUN pwgen -cn 20 1 > /passwords/pass_mysql_root.txt

# Create the SimpleRisk password
RUN pwgen -cn 20 1 > /passwords/pass_simplerisk.txt

# Install and configure supervisor
RUN easy_install supervisor
ADD ./supervisord.conf /etc/supervisord.conf
RUN mkdir /var/log/supervisor/

# Configure MySQL
ADD ./my.cnf /etc/mysql/my.cnf

# Configure Apache
ADD ./foreground.sh /etc/apache2/foreground.sh
RUN chmod 755 /etc/apache2/foreground.sh
ADD ./envvars /etc/apache2/envvars
ADD ./000-default.conf /etc/apache2/sites-enabled/000-default.conf
ADD ./default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf

# Create SSL Certificates for Apache SSL
RUN mkdir -p /etc/apache2/ssl/ssl.crt
RUN mkdir -p /etc/apache2/ssl/ssl.key
RUN openssl genrsa -des3 -passout pass:/passwords/pass_openssl.txt -out /etc/apache2/ssl/ssl.key/simplerisk.pass.key
RUN openssl rsa -passin pass:/passwords/pass_openssl.txt -in /etc/apache2/ssl/ssl.key/simplerisk.pass.key -out /etc/apache2/ssl/ssl.key/simplerisk.key
RUN rm /etc/apache2/ssl/ssl.key/simplerisk.pass.key
RUN openssl req -new -key /etc/apache2/ssl/ssl.key/simplerisk.key -out  /etc/apache2/ssl/ssl.crt/simplerisk.csr -subj "/CN=simplerisk"
RUN openssl x509 -req -days 365 -in /etc/apache2/ssl/ssl.crt/simplerisk.csr -signkey /etc/apache2/ssl/ssl.key/simplerisk.key -out /etc/apache2/ssl/ssl.crt/simplerisk.crt

# Activate Apache modules
RUN php5enmod mcrypt
RUN php5enmod ldap
RUN a2enmod rewrite
RUN a2enmod ssl

RUN echo %sudo  ALL=NOPASSWD: ALL >> /etc/sudoers

# Download SimpleRisk
ADD https://github.com/simplerisk/database/raw/master/simplerisk-en-20190331-001.sql /simplerisk.sql
ADD https://github.com/simplerisk/bundles/raw/master/simplerisk-20190331-001.tgz /simplerisk.tgz

# Extract the SimpleRisk files
RUN rm -rf /var/www/html
RUN cd /var/www && tar xvzf /simplerisk.tgz
RUN chown -R www-data: /var/www/simplerisk

# Update the SimpleRisk config file
RUN cat /var/www/simplerisk/includes/config.php | sed "s/DB_PASSWORD', 'simplerisk/DB_PASSWORD', '`cat /passwords/pass_simplerisk.txt`/" > /var/www/simplerisk/includes/config.php

EXPOSE 80
EXPOSE 443

# Initialize the MySQL database
#ADD ./mysql_setup.sh /mysql_setup.sh
#RUN chmod 755 /mysql_setup.sh
#CMD ["/bin/bash", "/mysql_setup.sh"]

# Run Apache
#CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]

# Create the start script and set permissions
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

# Data to save
VOLUME /passwords
VOLUME /configurations
VOLUME /var/log
VOLUME /var/lib/mysql
VOLUME /etc/apache2/ssl
VOLUME /var/www/simplerisk

# Start Apache and MySQL
CMD ["/bin/bash", "/start.sh"]
