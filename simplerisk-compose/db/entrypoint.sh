#!/bin/bash
set -eo pipefail
set -u

# -------------------------
# Logging function
# -------------------------
print_log() {
    echo "$(date -u +"[%a %b %e %X.%6N %Y]") [$1] $2"
}

# -------------------------
# Generate random password
# -------------------------
generate_random_password() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c32
}

# -------------------------
# Ensure password files exist
# -------------------------
setup_passwords() {
    [ -f /passwords/pass_mysql_root.txt ] || generate_random_password > /passwords/pass_mysql_root.txt
    [ -f /passwords/pass_simplerisk.txt ] || generate_random_password > /passwords/pass_simplerisk.txt

    print_log "startup:passwords" "Using MySQL root password: $(cat /passwords/pass_mysql_root.txt | head -c8)****"
    print_log "startup:passwords" "Using SimpleRisk password: $(cat /passwords/pass_simplerisk.txt | head -c8)****"
}

# -------------------------
# Start MySQL
# -------------------------
_main() {
    setup_passwords

    export MYSQL_ROOT_PASSWORD_FILE=/passwords/pass_mysql_root.txt
    export MYSQL_PASSWORD_FILE=/passwords/pass_simplerisk.txt

    print_log "startup:mysql" "Starting MySQL server..."
    
    exec docker-entrypoint.sh mysqld
}

_main "$@"
