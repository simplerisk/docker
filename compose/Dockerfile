# Using dedicated PHP image with version 7.2 and Apache
FROM php:7.2-apache 

# Maintained by SimpleRisk
LABEL maintainer="Simplerisk <support@simplerisk.com>"

# Make necessary directories
RUN mkdir -p /etc/apache2/ssl
RUN mkdir -p /var/www/simplerisk

# Installing apt dependencies
RUN apt-get update && apt-get -y dist-upgrade && apt-get -y install libmcrypt-dev \
                                                                    libldap2-dev \
                                                                    pwgen \
                                                                    sendmail \
                                                                    openssl \
                                                                    ufw \
                                                                    supervisor
# Run configure for certain extensions
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu
# Install extensions
RUN docker-php-ext-install ldap \
                           mbstring \
                           json \
                           mysqli \
                           pdo_mysql 
# Installing mcrypt through pecl and enabling it
RUN yes | pecl install mcrypt-1.0.1 && docker-php-ext-enable mcrypt
# Performing a cleanup
RUN apt-get -y autoremove && apt-get -y purge && rm -rf /var/lib/apt/lists/*

# Create the OpenSSL password
RUN pwgen -cn 20 1 > /tmp/pass_openssl.txt

# Configure supervisor
COPY ./app_setup/supervisord.conf /etc/supervisord.conf
RUN service supervisor restart

# Configure Apache
COPY ./app_setup/foreground.sh /etc/apache2/foreground.sh
RUN chmod 755 /etc/apache2/foreground.sh
COPY ./app_setup/envvars /etc/apache2/envvars
COPY ./app_setup/000-default.conf /etc/apache2/sites-enabled/000-default.conf
COPY ./app_setup/default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf
RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 5M/g' /usr/local/etc/php/php.ini-production

# Create SSL Certificates for Apache SSL
RUN mkdir -p /etc/apache2/ssl/ssl.crt
RUN mkdir -p /etc/apache2/ssl/ssl.key
RUN openssl genrsa -des3 -passout pass:/tmp/pass_openssl.txt -out /etc/apache2/ssl/ssl.key/simplerisk.pass.key
RUN openssl rsa -passin pass:/tmp/pass_openssl.txt -in /etc/apache2/ssl/ssl.key/simplerisk.pass.key -out /etc/apache2/ssl/ssl.key/simplerisk.key
RUN rm /etc/apache2/ssl/ssl.key/simplerisk.pass.key
RUN openssl req -new -key /etc/apache2/ssl/ssl.key/simplerisk.key -out  /etc/apache2/ssl/ssl.crt/simplerisk.csr -subj "/CN=simplerisk"
RUN openssl x509 -req -days 365 -in /etc/apache2/ssl/ssl.crt/simplerisk.csr -signkey /etc/apache2/ssl/ssl.key/simplerisk.key -out /etc/apache2/ssl/ssl.crt/simplerisk.crt

# Activate Apache modules
RUN a2enmod rewrite ssl
RUN a2enconf security
RUN sed -i 's/SSLProtocol all -SSLv3/SSLProtocol TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf
RUN sed -i 's/#SSLHonorCipherOrder on/SSLHonorCipherOrder on/g' /etc/apache2/mods-enabled/ssl.conf
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf
RUN sed -i 's/#ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf

RUN echo %sudo  ALL=NOPASSWD: ALL >> /etc/sudoers

# Download and extract SimpleRisk
RUN VERSION=`curl -sL https://updates.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1` \
    && curl -sL https://github.com/simplerisk/bundles/raw/master/simplerisk-$VERSION.tgz | tar xz -C /var/www && echo $VERSION > /tmp/version
RUN chown -R www-data: /var/www/simplerisk

# Ports to expose
EXPOSE 80
EXPOSE 443

# Create the start script and set permissions
COPY ./app_setup/start.sh /start.sh
RUN chmod 755 /start.sh

# Data to save
VOLUME /var/log
VOLUME /var/lib/mysql
VOLUME /etc/apache2/ssl
VOLUME /var/www/simplerisk

# Start Apache 
CMD ["/bin/bash", "/start.sh"]
