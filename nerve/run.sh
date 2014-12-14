#!/bin/bash

function join { local IFS="$1"; shift; echo "$*"; }
function split { echo $1 | cut -d : -f $2; }

function error {
    echo "$1" >&2
    help
}

function help {
    echo "TBD"
    exit 1
}

function check_env_vars {
    if [ -z "$SERVICE" ]; then error "You must specify a service path"; fi
    if [ -z "$SERVICE_HOST" ]; then error "You must specify a service host"; fi
    if [ -z "$SERVICE_PORT" ]; then error "You must specify a service port"; fi

    INSTANCE_ID=${INSTANCE_ID:-nerve}
    CHECK_INTERVAL=${CHECK_INTERVAL:-2}

    C_TIMEOUT=${C_TIMEOUT:-0.2}
    C_RISE=${C_RISE:-3}
    C_FAIL=${C_FAIL:-2}

    ZK_PATH=${ZK_PATH:-/nerve/services/}

    ETCD_PATH=${ETCD_PATH:-/nerve/services/}
    ETCD_PORT=${ETCD_PORT:-4001}
}

function set_name_idx {
    local NAME=$1
    if [ ! ${NAMES[$NAME]+_} ]
    then
	NAMES[$NAME]=$NAME_IDX
	FILTERS+=(".services.default.checks[$NAME_IDX]={}")
	NAME_IDX=$((NAME_IDX+1))
    fi
}

function set_zk_hosts {
    if [ -z "$ZK_HOSTS" ]; then error "No Zookeeper hosts specified"; fi

    local IFS=","
    local IDX=0
    read -ra SERVERS <<< "$ZK_HOSTS"
    for i in "${SERVERS[@]}"
    do
        FILTERS+=(".services.default.zk_hosts[$IDX]=\"$i\"")
        IDX=$((IDX+1))
    done
}

function init {
    check_env_vars

    FILTERS+=(".instance_id=\"$INSTANCE_ID\"")
    FILTERS+=(".services={}")
    FILTERS+=(".services.default={}")

    FILTERS+=(".services.default.host=\"$SERVICE_HOST\"")
    FILTERS+=(".services.default.port=$SERVICE_PORT")
    FILTERS+=(".services.default.check_interval=$CHECK_INTERVAL")

    FILTERS+=(".services.default.checks=[]")
}

function set_zookeeper {
    FILTERS+=(".services.default.reporter_type=\"zookeeper\"")
    FILTERS+=(".services.default.zk_path=\"$ZK_PATH$SERVICE\"")
    FILTERS+=(".services.default.zk_hosts=[]")

    set_zk_hosts
    REPORTER=true
}

function set_etcd {
    if [ -z "$ETCD_HOST" ]; then error "You must specify an etcd host"; fi

    FILTERS+=(".services.default.reporter_type=\"etcd\"")
    FILTERS+=(".services.default.etcd_path=\"$ETCD_PATH$SERVICE\"")
    FILTERS+=(".services.default.etcd_host=\"$ETCD_HOST\"")
    FILTERS+=(".services.default.etcd_port=$ETCD_PORT")

    REPORTER=true
}

function set_filter {
    local NAME=$(split $1 1)
    local OPTION_NAME=$(split $1 2)
    local VALUE=$(split $1 3)

    set_name_idx $NAME
    IDX=${NAMES[$NAME]}

    FILTERS+=(".services.default.checks[$IDX].$OPTION_NAME=\"$VALUE\"")
}

function set_standard_filter {
    set_filter "$1:name:$1"
    set_filter "$1:type:$1"
    set_filter "$1:timeout:$C_TIMEOUT"
    set_filter "$1:rise:$C_RISE"
    set_filter "$1:fail:$C_FAIL"
}

NAME_IDX=0
declare -A NAMES;
declare -a FILTERS;

init

OPTS=`getopt -o "c:o:" -l "http:,tcp,rabbitmq:,zk,etcd" -- "$@"`

if [ $? != 0 ]; then error "Error parsing arguments"; fi

eval set -- "$OPTS"

while true ; do
  case $1 in
    -c)	
      NAME=$(split $2 1)
      TYPE=$(split $2 2)
      set_filter "$NAME:name:$NAME"
      set_filter "$NAME:type:$TYPE"
      shift 2;;
    -o)
      set_filter $2
      shift 2;;
    --zk)
      set_zookeeper
      shift;;
    --etcd)
      set_etcd
      shift;;
    --tcp)
      set_standard_filter "tcp"
      shift;;
    --http)
      set_standard_filter "http"
      set_filter "http:uri:$2"
      shift 2;;
    --rabbitmq)
      set_standard_filter "rabbitmq"
      USERNAME=$(split $2 1)
      PASSWORD=$(split $2 2)
      set_filter "rabbitmq:username:$USERNAME"
      set_filter "rabbitmq:password:$PASSWORD"
      shift 2;;
    --) shift; break;;
  esac
done

if [ -z "$REPORTER" ]; then error "You have to set at least one reporter"; fi

JQ_FILTERS=$(join "|" "${FILTERS[@]}")

echo '{}' | jq $JQ_FILTERS > /config.json

echo "Config: "
cat /config.json

nerve -c /config.json
