#!/bin/bash

function join { local IFS="$1"; shift; echo "$*"; }
function split { echo $1 | cut -d : -f $2; }

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

    FILTERS+=(".services.default.host=\"service\"")
    FILTERS+=(".services.default.port=$PORT")
    FILTERS+=(".services.default.reporter_type=\"zookeeper\"")
    FILTERS+=(".services.default.zk_path=\"/nerve/services/$ZK_PATH\"")
    FILTERS+=(".services.default.check_interval=$CHECK_INTERVAL")

    FILTERS+=(".services.default.zk_hosts=[]")
    FILTERS+=(".services.default.checks=[]")


}

if [ -z "$CHECK_INTERVAL" ]
then
    CHECK_INTERVAL=2
fi

NAME_IDX=0
declare -A NAMES;
declare -a FILTERS;

init
set_servers

while getopts ":c:o:" opt; do
  case $opt in
    c)	
      NAME=$(split ${OPTARG} 1)
      TYPE=$(split ${OPTARG} 2)
      
      set_name_idx $NAME
      IDX=${NAMES[$NAME]}

      FILTERS+=(".services.default.checks[$IDX].type=\"$TYPE\"")
      ;;
    o)
      NAME=$(split ${OPTARG} 1)
      OPTION_NAME=$(split ${OPTARG} 2)
      VALUE=$(split ${OPTARG} 3)

      set_name_idx $NAME
      IDX=${NAMES[$NAME]}

      FILTERS+=(".services.default.checks[$IDX].$OPTION_NAME=\"$VALUE\"")
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit
      ;;
  esac
done

shift $((OPTIND-1))

JQ_FILTERS=$(join "|" "${FILTERS[@]}")

echo '{}' | jq $JQ_FILTERS > /config.json

echo "Config: "
cat /config.json

nerve -c /config.json
