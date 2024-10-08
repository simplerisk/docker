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
    - DB_SETUP=automatic
    - DB_SETUP_PASS=$pass
    - SIMPLERISK_DB_HOSTNAME=mysql
    image: simplerisk/simplerisk-minimal:$release
    ports:
    - "80:80"
    - "443:443"

  mysql:
    command: mysqld --sql_mode="NO_ENGINE_SUBSTITUTION"
    environment:
    - MYSQL_ROOT_PASSWORD=$pass
    image: mysql:8.0

  smtp:
    image: namshi/smtp
EOF

sed -i -r "s/(version:) \"[0-9]{8,}-[0-9]{3,}\"/\1 \"${release}\"/g" .github/workflows/push*
