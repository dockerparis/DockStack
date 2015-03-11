#!/bin/bash

function split { echo $1 | cut -d : -f $2; }

function error {
    echo "$1" >&2
    help
}

function help {
    echo >&2 <<< EOF
Usage: docker run synapse [ARGUMENTS]

Arguments:
  -c, --config			Base config file
  -s, --service			Service
				  format: service_name:service_type:discovery_path
  -d, --discovery		Discovery
				  format: \<zk|etcd\>://\<servers comma separated\>/\<base_path\>
  -r, --raw			Add a raw jq query to configure dynamically a service
				  format: service_name:jq_query

EOF
    exit 1
}

function set_discovery {
    local filter="$1"
    DISCOVERY_TYPE=$(echo "$filter" | sed -e 's/:.*$//')

    case $DISCOVERY_TYPE in
       zk)
         DISCOVERY='.discovery={}|.discovery.method="zookeeper"|.discovery.hosts=[]'

         local hosts=$(echo "$filter" | sed -e 's/zk:\/\///i' -e 's:/.*$::')
         IFS=',' read -a splitted_hosts <<< "$hosts"
         local i=0
         for host in "${splitted_hosts[@]}"
         do
           DISCOVERY=$DISCOVERY"|.discovery.hosts[$i]=\"$host\""
           i=$((i+1))
         done

         local base_path=$(echo "$filter" | sed -e 's/zk:\/\///i' -e 's/^[^/]*//')
         DISCOVERY=$DISCOVERY"|.discovery.path=\"$base_path"
       ;;
       etcd)
         error "Not yet implemented"
       ;;
       *)
         error "Wrong discovery type"
       ;;
     esac
}


function process_services {
    for service in "${SERVICES[@]}"
    do
      local service_name=$(split $service 1)
      local service_type=$(split $service 2)
      local service_path=$(split $service 3)

      if [ -z "$service_name" ]; then error "You have to supply a service name"; fi
      if [ -z "$service_type" ]; then error "You have to supply a service type"; fi
      if [ -z "$service_path" ]; then error "You have to supply a service path"; fi

      if [ ! -f "/services/${service_type}.json" ]
      then
          error "The service ${service_type} does not exist"
      fi

      cat "/services/${service_type}.json" | jq "${DISCOVERY}${service_path}\"" > /synapse/${service_name}.json
    done
}

function process_raw {
    for raw in "${RAW[@]}"
    do
     local service_name=$(split $raw 1)
     local filter=$(echo "$raw" | sed -e 's/^[^:]*://')

     if [ -z "$service_name" ]; then error "You have to supply a service name"; fi
     if [ -z "$filter" ]; then error "You have to supply a valid filter"; fi

     local new=$(cat "/synapse/${service_name}.json" | jq "$filter")
     echo "$new" > /synapse/${service_name}.json
    done
}

mkdir /synapse

declare -a SERVICES;
declare -a RAW;

OPTS=`getopt -o "c:s:d:r:" -l "config:,service:,discovery:,raw:" -- "$@"`

if [ $? != 0 ]; then error "Error parsing arguments"; fi

eval set -- "$OPTS"

while true ; do
  case $1 in
    -c|--config)
      if [ ! -f "/config/${2}.json" ]
      then
          error "The config file does not exist"
      fi
      cp "/config/${2}.json" /config.json
      shift 2;;
    -s|--service)
      SERVICES+=($2)
      shift 2;;
    -d|--discovery)
      set_discovery $2
      shift 2;;
    -r|--raw)
      RAW+=($2)
      shift 2;;
    --) shift; break;;
  esac
done

if [ -z "$DISCOVERY" ]; then error "You have to set the discovery path"; fi

if [ ! -f "/config.json" ]
then
    cp /config/default.json /config.json
fi

process_services
process_raw

echo "Config: "
cat /config.json

for service in /synapse/*
do
    echo "$service:"
    cat $service
done

/haproxy.sh start &

while true
do
    echo "Starting synapse..."
    synapse -c /config.json
done
