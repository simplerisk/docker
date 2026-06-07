#!/usr/bin/env bash

set -euo pipefail

SCRIPT_LOCATION="$(dirname "$(readlink -f "$0")")"
readonly SCRIPT_LOCATION

[ -z "${1:-}" ] && echo "No release version provided. Aborting." && exit 1 || release=$1

# Fixed bootstrap password for the bundled MySQL. It is the root password used
# ONLY for first-run schema setup; mysql is not exposed outside the stack
# network, and SimpleRisk generates its own random application DB password at
# first run. Override DB_SETUP_PASS + MYSQL_ROOT_PASSWORD below for any
# non-trial deployment. Kept literal (not randomized) so the committed
# stack.yml is deterministic across releases.
readonly bootstrap_pass="simplerisk_setup"

cat << EOF > "$SCRIPT_LOCATION/stack.yml"
# Compose file generated automatically

version: '3.6'

services:
  simplerisk:
    environment:
    - DB_SETUP=automatic
    - DB_SETUP_PASS=$bootstrap_pass
    - SIMPLERISK_DB_HOSTNAME=mysql
    image: simplerisk/simplerisk-minimal:$release
    ports:
    - "80:80"
    - "443:443"

  mysql:
    command: mysqld --sql_mode="NO_ENGINE_SUBSTITUTION"
    environment:
    - MYSQL_ROOT_PASSWORD=$bootstrap_pass
    image: mysql:8.0

  smtp:
    image: namshi/smtp
EOF
