#!/bin/bash

set -e

# FIX directory permissions and switch user
# Note, don't use "-R" with chown, we only need to fix permission if user attaches new
# data volume to the container, in which case these directories are supposed to be empty.
if [[ "$(id -u)" -eq 0 ]]; then
    chown openmetric:openmetric /openmetric/data/ /openmetric/log/
    #exec su-exec openmetric $0 "$@"
fi

help() {
    echo "Usage:"
    echo "    Run specific components:"
    echo "        docker run -v conf:/openmetric/conf ... openmetric/openmetric [relay] [carbon] [api]"
    echo ""
    echo "    Run system command:"
    echo "        docker run -v conf:/openmetric/conf ... openmetric/openmetric <command-in-path> [<command-options>]"
}

assert_file_exist() {
    if ! test -f "$1"; then
        echo "Required file does not exist: $1"
        exit 1
    fi
}

if [[ -z "$1" ]]; then
    help
    exit 0
fi

# parse args
ENABLE_RELAY=false
ENABLE_CARBON=false
ENABLE_API=false

first_arg=true
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        relay|carbon-c-relay)
            echo "Enabling carbon-c-relay"
            ENABLE_RELAY=true
            ;;
        carbon|go-carbon)
            echo "Enabling go-carbon"
            ENABLE_CARBON=true
            ;;
        api|carbonapi)
            echo "Enabling carbonapi (carbonzipper is always enabled together with carbonapi)"
            ENABLE_API=true
            ;;
        *)
            if [[ "$first_arg" == "true" ]]; then
                if command -v "$1" >/dev/null; then
                    exec su-exec openmetric "$@"
                else
                    echo "Unknown command: $1"
                fi
            else
                echo "Unknown param: $1"
                help
                exit 0
            fi
    esac
    first_arg=false
    shift
done

if [[ "$ENABLE_CARBON" == "true" ]]; then
    assert_file_exist /openmetric/conf/carbon.conf
    assert_file_exist /openmetric/conf/schemas.conf
    ln -snf /openmetric/supervisor.d/carbon.ini /etc/supervisord.d/carbon.ini
fi

if [[ "$ENABLE_RELAY" == "true" ]]; then
    assert_file_exist /openmetric/conf/relay.conf
    ln -snf /openmetric/supervisor.d/relay.ini /etc/supervisord.d/relay.ini
fi

if [[ "$ENABLE_API" == "true" ]]; then
    assert_file_exist /openmetric/conf/zipper.conf
    assert_file_exist /openmetric/conf/api.conf
    ln -snf /openmetric/supervisor.d/api.ini /etc/supervisord.d/api.ini
fi

exec su-exec openmetric supervisord -c /etc/supervisord.conf
