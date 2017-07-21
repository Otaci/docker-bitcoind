FROM ubuntu:xenial
MAINTAINER Otaci <otaci@protonmail.com>
# based on https://hub.docker.com/r/kylemanna/bitcoind/ by Kyle Manna <kyle@kylemanna.com>

# TODO:
#	- consolidate apt-get install
#	- clean up apt-get and /tmp, /var/tmp
#	- different base? python image?

ARG USER_ID
ARG GROUP_ID

ENV HOME /bitcoin

# add user with specified (or default) user/group ids
ENV USER_ID ${USER_ID:-1000}
ENV GROUP_ID ${GROUP_ID:-1000}

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -g ${GROUP_ID} bitcoin \
	&& useradd -u ${USER_ID} -g bitcoin -s /bin/bash -m -d /bitcoin bitcoin

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C70EF1F0305A1ADB9986DBD8D46F45428842CE5E && \
    echo "deb http://ppa.launchpad.net/bitcoin/bitcoin/ubuntu xenial main" > /etc/apt/sources.list.d/bitcoin.list

RUN apt-get update && apt-get install -y --no-install-recommends \
		bitcoind \
	&& apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates \
		wget \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true 

# install cpuminer
RUN cd /usr/local/bin  \
        && wget https://github.com/pooler/cpuminer/releases/download/v2.5.0/pooler-cpuminer-2.5.0-linux-x86_64.tar.gz \
        && zcat pooler-cpuminer-2.5.0-linux-x86_64.tar.gz | tar x  \
        && rm pooler-cpuminer-2.5.0-linux-x86_64.tar.gz 

# install eloipool
RUN cd /usr/local \
        && apt-get -y --no-install-recommends install git python3 python3-pip python3-setuptools \
	&& pip3 install --upgrade pip \
	&& pip3 install python-bitcoinrpc python-bitcoinlib json-rpc base58 \
	&& git clone https://github.com/luke-jr/eloipool.git \
	&& chown -R bitcoin:bitcoin /usr/local/eloipool

ADD ./bin /usr/local/bin

VOLUME ["/bitcoin"]

EXPOSE 18444 18443

WORKDIR /bitcoin

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["btc_oneshot"]
