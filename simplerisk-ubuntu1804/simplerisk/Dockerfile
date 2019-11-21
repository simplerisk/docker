# Use the bionic image
FROM ubuntu:bionic

# Maintained by SimpleRisk
LABEL maintainer="SimpleRisk <support@simplerisk.com>"

# Make necessary directories
RUN mkdir -p /var/log
RUN mkdir -p /etc/apache2/ssl
RUN mkdir -p /var/www/simplerisk

# Update the image to the latest packages
RUN apt-get update && apt-get install -y --no-install-recommends apt-utils && apt-get upgrade -y

# Install required packages
RUN dpkg-divert --local --rename /usr/bin/ischroot && ln -sf /bin/true /usr/bin/ischroot
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 php php-mysql php-json mysql-client php-dev libmcrypt-dev php-pear php-ldap php7.2-mbstring nfs-common chrony
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install python-setuptools vim-tiny sendmail openssl ufw supervisor
RUN pecl channel-update pecl.php.net
RUN yes '' | pecl install mcrypt-1.0.1
RUN sed -i 's/;extension=xsl/;extension=xsl\nextension=mcrypt.so/g' /etc/php/7.2/apache2/php.ini
RUN sed -i 's/;extension=xsl/;extension=xsl\nextension=mcrypt.so/g' /etc/php/7.2/cli/php.ini

# Install and configure supervisor
ADD ./supervisord.conf /etc/supervisord.conf
RUN service supervisor restart

# Configure Apache
ADD ./foreground.sh /etc/apache2/foreground.sh
RUN chmod 755 /etc/apache2/foreground.sh
ADD ./envvars /etc/apache2/envvars
ADD ./000-default.conf /etc/apache2/sites-enabled/000-default.conf
ADD ./default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf
RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 5M/g' /etc/php/7.2/apache2/php.ini
ADD ./start.sh /start.sh

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
ADD https://github.com/simplerisk/bundles/raw/master/simplerisk-20190930-001.tgz /simplerisk.tgz

# Extract the SimpleRisk files
RUN rm -rf /var/www/html
RUN cd /var/www && tar xvzf /simplerisk.tgz
RUN chown -R www-data: /var/www/simplerisk
RUN cp /var/www/simplerisk/includes/config.php /var/www/config.orig.php

EXPOSE 80
EXPOSE 443

# Start Apache and MySQL
CMD ["/bin/bash", "/start.sh"]
