FROM ubuntu

RUN apt-get update && \
	apt-get install -y build-essential ruby-dev haproxy jq && \
	gem install synapse

ADD run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]
