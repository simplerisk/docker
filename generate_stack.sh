#!/usr/bin/env bash

set -euo pipefail

generate_random_password() {
    echo $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-21})
}

[ -z "${1:-}" ] && echo "No release version provided. Aborting." && exit 1 || release=$1
pass=$(generate_random_password)

cat << EOF > "stack.yml"
# Compose file generated automatically

version: '3.6'

services:
  simplerisk:
    environment:
    - FIRST_TIME_SETUP=1
    - FIRST_TIME_SETUP_PASS=$pass
    - SIMPLERISK_DB_HOSTNAME=mariadb
    image: simplerisk/simplerisk-minimal:$release
    ports:
    - "80:80"
    - "443:443"

  mariadb:
    command: mysqld --sql_mode="NO_ENGINE_SUBSTITUTION"
    environment:
    - MYSQL_ROOT_PASSWORD=$pass
    image: mariadb:10.7

  smtp:
    image: namshi/smtp
EOF
