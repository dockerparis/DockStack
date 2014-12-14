#!/bin/bash

function join { local IFS="$1"; shift; echo "$*"; }
function split { echo $1 | cut -d : -f $2; }

function help {
    echo "TBD"
    exit 1
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

function set_servers {
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
    FILTERS+=(".instance_id=\"$INSTANCE_ID\"")
    FILTERS+=(".services={}")
    FILTERS+=(".services.default={}")

    FILTERS+=(".services.default.host=\"$SERVICE_HOST\"")
    FILTERS+=(".services.default.port=$PORT")
    FILTERS+=(".services.default.reporter_type=\"zookeeper\"")
    FILTERS+=(".services.default.zk_path=\"/nerve/services/$ZK_PATH\"")
    FILTERS+=(".services.default.check_interval=$CHECK_INTERVAL")

    FILTERS+=(".services.default.zk_hosts=[]")
    FILTERS+=(".services.default.checks=[]")
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

if [ -z "$CHECK_INTERVAL" ]
then
    CHECK_INTERVAL=2
fi

if [ -z "$C_TIMEOUT" ]
then
    C_TIMEOUT=0.2
fi

if [ -z "$C_RISE" ]
then
    C_RISE=3
fi

if [ -z "$C_FAIL" ]
then
    C_FAIL=2
fi

NAME_IDX=0
declare -A NAMES;
declare -a FILTERS;

init
set_servers

OPTS=`getopt -o "c:o:" -l "http:,tcp,rabbitmq:" -- "$@"`
if [ $? != 0 ]
then
    help
fi

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

JQ_FILTERS=$(join "|" "${FILTERS[@]}")

echo '{}' | jq $JQ_FILTERS > /config.json

echo "Config: "
cat /config.json

nerve -c /config.json
