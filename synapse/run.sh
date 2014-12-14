#!/bin/bash

/bash-templater/templater.sh /conf.yml.tpl > conf.yml

while [ $# -ne 0 ]
do
	SERVICE=$(echo "$1" | cut -d : -f1)
	PORT=$(echo "$1" | cut -d : -f2)
	TYPE=$(echo "$1" | cut -d : -f3)

	if [ -z "$SERVICE" ] || [ -z "$PORT" ]
	then
		# TODO: Help
		exit 1
	fi

	if [ -z "$TYPE" ]
	then
		TYPE=tcp
	fi
	
	. /bash-templater/templater.sh /types/${TYPE}.yml.tpl >> /conf.yml
	shift
done

cat /conf.yml
service haproxy start
synapse -c /conf.yml
