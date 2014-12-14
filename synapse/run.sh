#!/bin/bash

function join { local IFS="$1"; shift; echo "$*"; }
function split { echo $1 | cut -d : -f $2; }
function get_value { echo $1 | sed -e 's/^[^:]*://i'; }

function error {
    echo "$1" >&2
    help
}

function help {
    echo "TBD"
    exit 1
}

function check_env_vars {
    DISCOVERY=${DISCOVERY:-zk}

    CHECK_INTERVAL=${CHECK_INTERVAL:-2}

    C_TIMEOUT=${C_TIMEOUT:-0.2}
    C_RISE=${C_RISE:-3}
    C_FAIL=${C_FAIL:-2}

    ZK_PATH=${ZK_PATH:-/nerve/services/}

    ETCD_PATH=${ETCD_PATH:-/nerve/services/}
    ETCD_PORT=${ETCD_PORT:-4001}
}

function set_zk_hosts {
    local DISCOVERY_PATH=$1

    if [ -z "$ZK_HOSTS" ]; then error "No Zookeeper hosts specified"; fi

    local IFS=","
    local IDX=0
    read -ra SERVERS <<< "$ZK_HOSTS"
    for i in "${SERVERS[@]}"
    do
        FILTERS+=("${DISCOVERY_PATH}[$IDX]=\"$i\"")
        IDX=$((IDX+1))
    done
}

function init {
    check_env_vars

    FILTERS+=(".haproxy={}")
    FILTERS+=(".haproxy.reload_command=\"/haproxy.sh reload\"")
    FILTERS+=(".haproxy.config_file_path=\"/etc/haproxy/haproxy.cfg\"")
    FILTERS+=(".haproxy.socket_file_path=\"/var/run/haproxy.sock\"")
    FILTERS+=(".haproxy.do_writes=true")
    FILTERS+=(".haproxy.do_reloads=true")
    FILTERS+=(".haproxy.do_socket=false")
    FILTERS+=(".haproxy.bind_address=\"0.0.0.0\"")

    set_multiple ".haproxy.global" "daemon\nuser haproxy\ngroup haproxy\nmaxconn 4096\nlog     127.0.0.1 local0\nlog     127.0.0.1 local1 notice\n"
#stats   socket /var/haproxy/stats.sock mode 666 level admin\n"

    set_multiple ".haproxy.defaults" "log      global\noption   dontlognull\nmaxconn  2000\nretries  3\ntimeout  connect 5s\ntimeout  client  1m\ntimeout  server  1m\noption   redispatch\nbalance  roundrobin"
    
    FILTERS+=(".services={}")
}

function set_multiple {
    local KEY="$1"
    local VALUE=$(echo -e $2)
    local IDX=0
    local cr='
';
    local IFS=$cr
    
    FILTERS+=("$KEY=[]")
    for option in $VALUE
    do
        FILTERS+=("${KEY}[$IDX]=\"$option\"")
        IDX=$((IDX+1))
    done
}

function create_zk_discovery {
    local NAME="$1"
    local DISCOVERY_PATH="$2"

    FILTERS+=(".services.$NAME.haproxy.discovery.method=\"zookeeper\"")
    FILTERS+=(".services.$NAME.haproxy.discovery.path=\"$DISCOVERY_PATH\"")
    FILTERS+=(".services.$NAME.haproxy.discovery.hosts=[]")
    set_zk_hosts ".services.$NAME.haproxy.discovery.hosts"
}

function create_discovery {
    local NAME="$1"
    local DISCOVERY_PATH="$2"

    FILTERS+=(".services.$NAME.haproxy.discovery={}")
    case $DISCOVERY in
      zk)
        create_zk_discovery "$NAME" "$DISCOVERY_PATH"
      ;;
      etcd)
        error "Etcd not yet implemented"
      ;;
    esac
}

function create_service {
    local NAME="$1"
    local SERVICE="$2"
    local PORT="$3"

    FILTERS+=(".services.$NAME={}")
    FILTERS+=(".services.$NAME.haproxy={}")
    FILTERS+=(".services.$NAME.haproxy.port=$PORT")
    FILTERS+=(".services.$NAME.haproxy.server_options=\"check inter ${CHECK_INTERVAL}s rise $C_RISE fail $C_FAIL\"")

    create_discovery "$NAME" "$SERVICE"
}
declare -a FILTERS;

init

OPTS=`getopt -o "s:m:k:a:" -l "set:,multiline:,hash:,array:,tcp:,http:" -- "$@"`

if [ $? != 0 ]; then error "Error parsing arguments"; fi

eval set -- "$OPTS"

while true ; do
  case $1 in
    -s|--set)
      KEY=$(split $2 1)
      VALUE=$(get_value $2)
      FILTERS+=("$KEY=\"$VALUE\"")
      shift 2;;
    -m|--multiline)
      KEY=$(split $2 1)
      VALUE=$(get_value $2)
      set_multiple "$KEY" "$VALUE"
      shift 2;;
    -k|--hash)
      FILTERS+=("$2={}")
      shift 2;;
    -a|--array)
      FILTERS+=("$2=[]")
      shift 2;;
    --http)
      NAME=$(split "$2" 1)
      SERVICE=$(split "$2" 2)
      PORT=$(split "$2" 3)
      CHECK=$(split "$2" 4)
      RESPONSE=$(split "$2" 5)

      create_service "$NAME" "$SERVICE" "$PORT"
      set_multiple ".services.$NAME.haproxy.listen" "mode http\noption httpchk $CHECK\nhttp-check expect string $RESPONSE"
      shift 2;;
    --tcp)
      NAME=$(split "$2" 1)
      SERVICE=$(split "$2" 2)
      PORT=$(split "$2" 3)

      create_service "$NAME" "$SERVICE" "$PORT"
      set_multiple ".services.$NAME.haproxy.listen" "mode tcp"
      shift 2;;
    --) shift; break;;
  esac
done

JQ_FILTERS=$(join "|" "${FILTERS[@]}")

echo '{}' | jq "$JQ_FILTERS" > /config.json

echo "Config: "
cat /config.json

synapse -c /conf.yml
