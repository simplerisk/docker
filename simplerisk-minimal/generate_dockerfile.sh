#!/usr/bin/env bash

set -euo pipefail

readonly MYSQL_KEY_URL='http://repo.mysql.com/RPM-GPG-KEY-mysql-2023'

if [ $# -eq 1 ]; then
  release=$1
  [ "$release" == "testing" ] && images=('8.1') || images=('8.1' '8.3')
else
  echo "No release version provided. Aborting." && exit 1
fi

for image in "${images[@]}"
do
image_dir="php${image:0:1}${image: -1}"
[ -d "$image_dir" ] || mkdir -p "$image_dir"
cat << EOF > "$image_dir/Dockerfile"
# Dockerfile generated by script
# Using dedicated PHP image with version $image and Apache
FROM php:$image-apache

# Maintained by SimpleRisk
LABEL maintainer="Simplerisk <support@simplerisk.com>"

WORKDIR /var/www

# Creating keyring env and installing apt dependencies
RUN mkdir -p /etc/apt/keyrings && \\
    apt-get update && \\
    apt-get install -y gnupg2 wget && \\
    wget -qO - $MYSQL_KEY_URL | gpg --dearmor -o /etc/apt/keyrings/mysql.gpg && \\
    echo 'deb [signed-by=/etc/apt/keyrings/mysql.gpg] http://repo.mysql.com/apt/\$(lsb_release -si | tr '[:upper:]' '[:lower:]')/ \$(lsb_release -sc) mysql-8.0' | tee /etc/apt/sources.list.d/mysql.list && \\
    apt-key adv --keyserver pgp.mit.edu --recv-keys A8D3785C && \\
    echo "deb http://repo.mysql.com/apt/debian bookworm mysql-8.0" > /etc/apt/sources.list.d/mysql.list && \\
    apt-get update && \\
    apt-get -y install libldap2-dev \\
                       libicu-dev \\
                       libcap2-bin \\
                       libcurl4-gnutls-dev \\
                       libpng-dev \\
                       libzip-dev \\
                       supervisor \\
                       cron \\
                       mysql-community-client && \\
    rm -rf /var/lib/apt/lists/*
# Configure all PHP extensions
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu && \\
    docker-php-ext-install ldap \\
                           mysqli \\
                           pdo_mysql \\
                           curl \\
                           zip \\
                           gd \\
                           intl
# Setting up setcap for port mapping without root and removing packages
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/apache2 && \\
    chmod gu+s /usr/sbin/cron && \\
    apt-get -y remove libcap2-bin && \\
    apt-get -y autoremove && \\
    apt-get -y purge

# Copying all files
COPY common/foreground.sh /etc/apache2/foreground.sh
COPY common/envvars /etc/apache2/envvars
COPY common/000-default.conf /etc/apache2/sites-enabled/000-default.conf
COPY common/default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf
COPY common/entrypoint.sh /entrypoint.sh

# Configure Apache
RUN echo 'upload_max_filesize = 5M' >> /usr/local/etc/php/conf.d/docker-php-uploadfilesize.ini && \\
	echo 'memory_limit = 256M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini && \\
	echo 'max_input_vars = 3000' >> /usr/local/etc/php/conf.d/docker-php-maxinputvars.ini && \\
	echo 'log_errors = On' >> /usr/local/etc/php/conf.d/docker-php-error_logging.ini && \\
	echo 'error_log = /dev/stderr' >> /usr/local/etc/php/conf.d/docker-php-error_logging.ini && \\
	echo 'display_errors = Off' >> /usr/local/etc/php/conf.d/docker-php-error_logging.ini && \\
# Create SSL Certificates for Apache SSL
	echo \$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c\${1:-32}) > /tmp/pass_openssl.txt && \\
	mkdir -p /etc/apache2/ssl/ssl.crt /etc/apache2/ssl/ssl.key && \\
	openssl genrsa -des3 -passout pass:/tmp/pass_openssl.txt -out /etc/apache2/ssl/ssl.key/simplerisk.pass.key && \\
	openssl rsa -passin pass:/tmp/pass_openssl.txt -in /etc/apache2/ssl/ssl.key/simplerisk.pass.key -out /etc/apache2/ssl/ssl.key/simplerisk.key && \\
	rm /etc/apache2/ssl/ssl.key/simplerisk.pass.key /tmp/pass_openssl.txt && \\
	openssl req -new -key /etc/apache2/ssl/ssl.key/simplerisk.key -out  /etc/apache2/ssl/ssl.crt/simplerisk.csr -subj "/CN=simplerisk" && \\
	openssl x509 -req -days 365 -in /etc/apache2/ssl/ssl.crt/simplerisk.csr -signkey /etc/apache2/ssl/ssl.key/simplerisk.key -out /etc/apache2/ssl/ssl.crt/simplerisk.crt && \\
# Activate Apache modules
	a2enmod headers rewrite ssl && \\
	a2enconf security && \\
	sed -i 's/\\(SSLProtocol\\) all -SSLv3/\1 TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf && \\
	sed -i 's/#\\(SSLHonorCipherOrder on\\)/\\1/g' /etc/apache2/mods-enabled/ssl.conf && \\
	sed -i 's/\\(ServerTokens\\) OS/\\1 Prod/g' /etc/apache2/conf-enabled/security.conf && \\
	sed -i 's/#\\(ServerSignature\\) On/\\1 Off/g' /etc/apache2/conf-enabled/security.conf

# Download and extract SimpleRisk, plus saving release version for database reference
RUN rm -rf /var/www/html && \\
EOF

# shellcheck disable=SC2015
[ ! "$release" == "testing" ] && echo "    curl -sL https://simplerisk-downloads.s3.amazonaws.com/public/bundles/simplerisk-$release.tgz | tar xz -C /var/www && \\" >> "$image_dir/Dockerfile" || true
echo "    echo $release > /tmp/version" >> "$image_dir/Dockerfile"
if [ "$release" == "testing" ]; then
    cat << EOF >> "$image_dir/Dockerfile"
COPY ./simplerisk/ /var/www/simplerisk
COPY common/simplerisk.sql /var/www/simplerisk/simplerisk.sql
EOF
fi

cat << EOF >> "$image_dir/Dockerfile"

# Creating Simplerisk user on www-data group and setting up ownerships
RUN useradd -G www-data simplerisk && \\
	chown -R simplerisk:www-data /var/www/simplerisk /etc/apache2 /var/run/ /var/log/apache2 && \\
	chmod -R 770 /var/www/simplerisk /etc/apache2 /var/run/ /var/log/apache2 && \\
	chmod 755 /entrypoint.sh /etc/apache2/foreground.sh

# Data to save
VOLUME [ "/var/log/apache2", "/etc/apache2/ssl", "/var/www/simplerisk" ]

# Using simplerisk user from here
USER simplerisk

# Setting up entrypoint
ENTRYPOINT [ "/entrypoint.sh" ]

# Ports to expose
EXPOSE 80
EXPOSE 443

HEALTHCHECK --interval=1m \\
	CMD curl --fail http://localhost || exit 1

# Start Apache 
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
EOF
done
