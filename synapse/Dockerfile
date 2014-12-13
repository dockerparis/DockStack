FROM ubuntu

RUN apt-get update && \
	apt-get install -y build-essential ruby-dev haproxy git && \
	gem install synapse && \
	git clone https://github.com/lavoiesl/bash-templater /bash-templater

ADD run.sh /run.sh
RUN chmod +x /run.sh

ADD conf.yml.tpl /conf.yml.tpl
ADD types /types

ENTRYPOINT ["/run.sh"]
