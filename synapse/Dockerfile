FROM ubuntu

RUN apt-get update && \
	apt-get install -y build-essential ruby-dev haproxy jq && \
	gem install synapse && \
	sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/haproxy

ADD haproxy.cfg /etc/haproxy/haproxy.cfg

ADD haproxy.sh /haproxy.sh
ADD run.sh /run.sh

ENTRYPOINT ["/run.sh"]
