#!/bin/bash

function split { echo $1 | cut -d : -f $2; }

function error {
    echo "$1" >&2
    help
}

function help {
    echo >&2 <<< EOF
Usage: docker run -e SERVICE_HOST=<host_ip> [VOLUMES] nerve [ARGUMENTS]

Arguments:
  -s, --service                 Service
                                  format: service_name:service_type:service_port:discovery_path | service_name:service_type:container_name:container_port:discovery_path
  -d, --discovery               Discovery
                                  format: <zk|etcd>://<servers comma separated>/<base_path>
  -r, --raw                     Add a raw jq query to configure dynamically a service
                                  format: service_name:jq_query

Volumes:
  To be able to obtain automatically the container port you must share the following volumes with nerve:

  -v /usr/bin/docker:/usr/bin/docker:ro 
  -v /lib64/libdevmapper.so.1.02:/lib/libdevmapper.so.1.02:ro 
  -v  /var/run/docker.sock:/var/run/docker.sock

EOF
    exit 1
}


function set_reporter {
    local filter="$1"
    REPORTER_TYPE=$(echo "$filter" | sed -e 's/:.*$//')
    
    case $REPORTER_TYPE in
       zk)
         REPORTER='.reporter_type="zookeeper"|.zk_hosts=[]'
       
         local hosts=$(echo "$filter" | sed -e 's/zk:\/\///i' -e 's:/.*$::')
         IFS=',' read -a splitted_hosts <<< "$hosts"
         local i=0
         for host in "${splitted_hosts[@]}"
         do
           REPORTER=$REPORTER"|.zk_hosts[$i]=\"$host\""
           i=$((i+1))
         done
       
         local base_path=$(echo "$filter" | sed -e 's/zk:\/\///i' -e 's/^[^/]*//')
         REPORTER=$REPORTER"|.zk_path=\"$base_path"
       ;;
       etcd)
         local full_host=$(echo "$filter" | sed -e 's/etcd:\/\///i' -e 's:/.*$::')
         local host=$(split $full_host 1)
         local port=$(split $full_host 2)
         local base_path=$(echo "$filter" | sed -e 's/etcd:\/\///i' -e 's/^[^/]*//')
         REPORTER=".reporter_type=\"etcd\"|.etcd_host=\"$host\"|.etcd_port=$port|.etcd_path=\"$base_path"
       ;;
       *)
         error "Wrong reporter type"
       ;;
     esac
}

function process_services {
    for service in "${SERVICES[@]}"
    do
      local service_name=$(split $service 1)
      local service_type=$(split $service 2)
      local service_port=$(split $service 3)
      local service_path=$(split $service 4)

      local re='^[0-9]+$'
      if ! [[ "$service_port" =~ $re ]]
      then
         service_port=$(split $(docker port $service_port $service_path) 2)
         service_path=$(split $service 5)
      fi

      if [ -z "$service_name" ]; then error "You have to supply a service name"; fi
      if [ -z "$service_type" ]; then error "You have to supply a service type"; fi
      if [ -z "$service_port" ]; then error "You have to supply a service port"; fi
      if [ -z "$service_path" ]; then error "You have to supply a service path"; fi
         
      cat "/services/${service_type}.json" | jq ".host=\"$SERVICE_HOST\"|.port=$service_port|${REPORTER}${service_path}\"" > /nerve/${service_name}.json
    done
}

function process_raw {
    for raw in "${RAW[@]}"
    do
     local service_name=$(split $raw 1)
     local filter=$(echo "$raw" | sed -e 's/^[^:]*://')

     if [ -z "$service_name" ]; then error "You have to supply a service name"; fi
     if [ -z "$filter" ]; then error "You have to supply a valid filter"; fi

     local new=$(cat "/nerve/${service_name}.json" | jq "$filter")
     echo "$new" > /nerve/${service_name}.json
    done
}
mkdir -p /nerve

INSTANCE_ID=${INSTANCE_ID:-nerve}

echo '{}' | jq ".instance_id=\"$INSTANCE_ID\"|.service_conf_dir=\"/nerve\"" > /config.json

declare -a SERVICES;
declare -a RAW;

OPTS=`getopt -o "s:r:d:" -l "service:,raw:,discovery:" -- "$@"`

if [ $? != 0 ]; then error "Error parsing arguments"; fi

eval set -- "$OPTS"

while true ; do
  case $1 in
    -s|--service)
      SERVICES+=($2)
      shift 2;;
    -r|--raw)
      RAW+=($2)
      shift 2;;
    -d|--discovery)
      set_reporter $2
      shift 2;;
    --) shift; break;;
  esac
done

if [ -z "$REPORTER" ]; then error "You have to set a service discovery"; fi

if [ -z "$SERVICE_HOST" ]; then error "You have to set the service host"; fi

process_services
process_raw

echo "Config: "
cat /config.json

for service in /nerve/*
do
    echo "$service:"
    cat $service
done

nerve -c /config.json
