#!/bin/bash

# Create the passwords
if [ ! -f "/bootstrap/pass_openssl.txt" ]; then
    echo "Creating passwords"
    pwgen -cn 20 1 > /bootstrap/pass_openssl.txt
    pwgen -cn 20 1 > /bootstrap/pass_mysql_root.txt
    pwgen -cn 20 1 > /bootstrap/pass_simplerisk.txt
else
    echo "Passwords already exist"
fi

# Generate SSL certificates
if [ ! -f "/bootstrap/simplerisk.key" ]; then
    echo "Creating certificates"
    openssl genrsa -des3 -passout pass:/bootstrap/pass_openssl.txt -out /bootstrap/simplerisk.pass.key
    openssl rsa -passin pass:/bootstrap/pass_openssl.txt -in /bootstrap/simplerisk.pass.key -out /bootstrap/simplerisk.key
    rm /bootstrap/simplerisk.pass.key
    openssl req -new -key /bootstrap/simplerisk.key -out  /bootstrap/simplerisk.csr -subj "/CN=simplerisk"
    openssl x509 -req -days 365 -in /bootstrap/simplerisk.csr -signkey /bootstrap/simplerisk.key -out /bootstrap/simplerisk.crt
else
    echo "Certificates already exist"
fi

# Generate .env
echo "Generating .env"
echo "MYSQL_DATABASE=simplerisk" > /bootstrap/.env
echo "MYSQL_USER=simplerisk" >> /bootstrap/.env
echo -n "MYSQL_PASSWORD=" >> /bootstrap/.env
cat /bootstrap/pass_simplerisk.txt >> /bootstrap/.env
echo -n "MYSQL_ROOT_PASSWORD=" >> /bootstrap/.env
cat /bootstrap/pass_mysql_root.txt >> /bootstrap/.env
echo -n "PRIVATE_KEY=" >> /bootstrap/.env
sed ':a;N;$!ba;s/\n/\\n/g' /bootstrap/simplerisk.key >> /bootstrap/.env
echo -n "CERTIFICATE=" >> /bootstrap/.env
sed ':a;N;$!ba;s/\n/\\n/g' /bootstrap/simplerisk.crt >> /bootstrap/.env
