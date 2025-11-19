#!/bin/bash
set -eo pipefail
set -u  # Treat unset variables as errors

print_log() {
    echo "$(date -u +"[%a %b %e %X.%6N %Y]") [$1] $2"
}

wait_for_mysql() {
    print_log "startup:mysql" "Waiting for MySQL at $DB_HOST:$DB_PORT..."
    local timeout=60
    until mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$ROOT_PASSWORD" -e ";" || [ $timeout -le 0 ]; do
        sleep 1
        timeout=$((timeout-1))
    done
    if [ $timeout -le 0 ]; then
        print_log "startup:mysql" "MySQL did not become ready in time!"
        exit 1
    fi
    print_log "startup:mysql" "MySQL is ready!"
}

set_config() {
    if [ ! -f /configurations/simplerisk-config-configured ]; then
        print_log "initial_setup:config" "Setting up SimpleRisk configuration"

        CONFIG_PATH='/var/www/simplerisk/includes/config.php'

        SIMPLERISK_DB_HOSTNAME="${DB_HOST:-db}"
        SIMPLERISK_DB_PORT="${DB_PORT:-3306}"
        SIMPLERISK_DB_USERNAME="${DB_USER:-simplerisk}"
        SIMPLERISK_DB_DATABASE="${DB_NAME:-simplerisk}"
        ROOT_PASSWORD="$(cat /passwords/pass_mysql_root.txt)"
        SIMPLERISK_PASSWORD="$(cat /passwords/pass_simplerisk.txt)"

        sed -i "s/\('DB_HOSTNAME', '\).*\(');\)/\1$SIMPLERISK_DB_HOSTNAME\2/g" "$CONFIG_PATH"
        sed -i "s/\('DB_PORT', '\).*\(');\)/\1$SIMPLERISK_DB_PORT\2/g" "$CONFIG_PATH"
        sed -i "s/\('DB_USERNAME', '\).*\(');\)/\1$SIMPLERISK_DB_USERNAME\2/g" "$CONFIG_PATH"
        sed -i "s/\('DB_PASSWORD', '\).*\(');\)/\1$SIMPLERISK_PASSWORD\2/g" "$CONFIG_PATH"
        sed -i "s/\('DB_DATABASE', '\).*\(');\)/\1$SIMPLERISK_DB_DATABASE\2/g" "$CONFIG_PATH"

        # Enable testing URLs if version is "testing"
        [ "${version:-}" == "testing" ] && sed -i "s|//\(define('.*_URL\)|\1|g" "$CONFIG_PATH" || true

        touch /configurations/simplerisk-config-configured
        print_log "initial_setup:config" "SimpleRisk configuration file set properly"
    fi
}

_main() {
    print_log "startup:general" "Starting SimpleRisk web container..."
    echo "Version is $version"

    set_config

    # Start cron in background
    cron &

    print_log "startup:general" "Container startup finished, handing over to supervisord"
    exec "$@"
}

_main "$@"
