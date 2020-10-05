# Use the bionic image
FROM ubuntu:bionic

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
RUN apt-get update && apt-get install -y --no-install-recommends apt-utils && apt-get upgrade -y

# Install required packages
RUN dpkg-divert --local --rename /usr/bin/ischroot && ln -sf /bin/true /usr/bin/ischroot
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 php php-mysql php-json mysql-client mysql-server php-dev libmcrypt-dev php-pear php-ldap php7.2-mbstring php-curl nfs-common chrony
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install pwgen python-setuptools vim-tiny sendmail openssl ufw supervisor
RUN pecl channel-update pecl.php.net
RUN yes '' | pecl install mcrypt-1.0.1
RUN sed -i 's/;extension=xsl/;extension=xsl\nextension=mcrypt.so/g' /etc/php/7.2/apache2/php.ini
RUN sed -i 's/;extension=xsl/;extension=xsl\nextension=mcrypt.so/g' /etc/php/7.2/cli/php.ini

# Create the OpenSSL password
RUN pwgen -cn 20 1 > /passwords/pass_openssl.txt

# Create the MySQL root password
RUN pwgen -cn 20 1 > /passwords/pass_mysql_root.txt

# Create the SimpleRisk password
RUN pwgen -cn 20 1 > /passwords/pass_simplerisk.txt

# Install and configure supervisor
ADD ./supervisord.conf /etc/supervisord.conf
#RUN mkdir /var/log/supervisor/
RUN service supervisor restart

# Configure MySQL
RUN sed -i 's/\[mysqld\]/\[mysqld\]\nsql-mode="NO_ENGINE_SUBSTITUTION"/g' /etc/mysql/mysql.conf.d/mysqld.cnf

# Configure Apache
ADD ./foreground.sh /etc/apache2/foreground.sh
RUN chmod 755 /etc/apache2/foreground.sh
ADD ./envvars /etc/apache2/envvars
ADD ./000-default.conf /etc/apache2/sites-enabled/000-default.conf
ADD ./default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf
RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 5M/g' /etc/php/7.2/apache2/php.ini

# Create SSL Certificates for Apache SSL
RUN mkdir -p /etc/apache2/ssl/ssl.crt
RUN mkdir -p /etc/apache2/ssl/ssl.key
RUN openssl genrsa -des3 -passout pass:/passwords/pass_openssl.txt -out /etc/apache2/ssl/ssl.key/simplerisk.pass.key
RUN openssl rsa -passin pass:/passwords/pass_openssl.txt -in /etc/apache2/ssl/ssl.key/simplerisk.pass.key -out /etc/apache2/ssl/ssl.key/simplerisk.key
RUN rm /etc/apache2/ssl/ssl.key/simplerisk.pass.key
RUN openssl req -new -key /etc/apache2/ssl/ssl.key/simplerisk.key -out  /etc/apache2/ssl/ssl.crt/simplerisk.csr -subj "/CN=simplerisk"
RUN openssl x509 -req -days 365 -in /etc/apache2/ssl/ssl.crt/simplerisk.csr -signkey /etc/apache2/ssl/ssl.key/simplerisk.key -out /etc/apache2/ssl/ssl.crt/simplerisk.crt

# Activate Apache modules
RUN phpenmod ldap
RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enconf security
RUN sed -i 's/SSLProtocol all -SSLv3/SSLProtocol TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf
RUN sed -i 's/#SSLHonorCipherOrder on/SSLHonorCipherOrder on/g' /etc/apache2/mods-enabled/ssl.conf
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf
RUN sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf

RUN echo %sudo  ALL=NOPASSWD: ALL >> /etc/sudoers

# Download SimpleRisk
ADD https://github.com/simplerisk/database/raw/master/simplerisk-en-20201005-001.sql /simplerisk.sql
ADD https://github.com/simplerisk/bundles/raw/master/simplerisk-20201005-001.tgz /simplerisk.tgz

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
