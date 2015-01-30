FROM dockerfile/ubuntu

RUN apt-get update && \
	apt-get install -y build-essential ruby-dev jq && \
	gem install nerve 

ADD run.sh /run.sh

ADD services /services

ENTRYPOINT ["/run.sh"]
