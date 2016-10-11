# Hanlon server
#
# VERSION 3.0.1

FROM ruby:2.2
MAINTAINER Joseph Callen <jcpowermac@gmail.com>

COPY atftpd/run.sh /
COPY atftpd/build.yml /
COPY atftpd/atftp.yml /
COPY atftpd/menu.c32 /
COPY atftpd/pxelinux.0 /
COPY atftpd/default /tftpboot/pxelinux.cfg/

RUN apt-get -y update \
    && apt-get -y install ansible wget \
    && /usr/bin/ansible-playbook -c local -i localhost, /build.yml \
    && /usr/bin/ansible-playbook -c local -i localhost, /atftp.yml \
    && apt-get -y purge ansible \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* \
    && chmod -R 700 /tftpboot/ \
    && chown -R nobody:nogroup /tftpboot/ \
    && chmod 755 /run.sh

# supervisor installation && 
# create directory for child images to store configuration in
RUN apt-get update && \
  apt-get -y install supervisor && \
  mkdir -p /var/log/supervisor && \
  mkdir -p /etc/supervisor/conf.d


# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mongodb && useradd -r -g mongodb mongodb

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		numactl \
	&& rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates wget

# pub   4096R/AAB2461C 2014-02-25 [expires: 2016-02-25]
#       Key fingerprint = DFFA 3DCF 326E 302C 4787  673A 01C4 E7FA AAB2 461C
# uid                  MongoDB 2.6 Release Signing Key <packaging@mongodb.com>
#
# pub   4096R/EA312927 2015-10-09 [expires: 2017-10-08]
#       Key fingerprint = 42F3 E95A 2C4F 0827 9C49  60AD D68F A50F EA31 2927
# uid                  MongoDB 3.2 Release Signing Key <packaging@mongodb.com>
#
ENV GPG_KEYS \
	DFFA3DCF326E302C4787673A01C4E7FAAAB2461C \
	42F3E95A2C4F08279C4960ADD68FA50FEA312927
RUN set -ex \
	&& for key in $GPG_KEYS; do \
		apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done

ENV MONGO_MAJOR 3.2
ENV MONGO_VERSION 3.2.10

RUN echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/$MONGO_MAJOR main" > /etc/apt/sources.list.d/mongodb-org.list

RUN set -x \
	&& apt-get update \
	&& apt-get install -y \
		mongodb-org=$MONGO_VERSION \
		mongodb-org-server=$MONGO_VERSION \
		mongodb-org-shell=$MONGO_VERSION \
		mongodb-org-mongos=$MONGO_VERSION \
		mongodb-org-tools=$MONGO_VERSION \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mongodb \
	&& mv /etc/mongod.conf /etc/mongod.conf.orig

RUN mkdir -p /data/db /data/configdb \
	&& chown -R mongodb:mongodb /data/db /data/configdb
VOLUME /data/db /data/configdb

COPY mongo-entrypoint.sh /mongo-entrypoint.sh



# Enabling the unstable packages to install fuseiso
RUN echo 'deb http://httpredir.debian.org/debian unstable main non-free contrib' >> /etc/apt/sources.list \
	&& echo 'Package: *' >> /etc/apt/preferences.d/pin \
	&& echo 'Pin: release a=stable' >> /etc/apt/preferences.d/pin \
	&& echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/pin \
	&& echo '' >> /etc/apt/preferences.d/pin \
	&& echo 'Package: *' >> /etc/apt/preferences.d/pin \
	&& echo 'Pin: release a=stable' >> /etc/apt/preferences.d/pin \
	&& echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/pin


# Install the required dependencies
RUN apt-get update -y \
	&& apt-get install -y libxml2 gettext libfuse-dev libattr1-dev git build-essential libssl-dev p7zip-full fuseiso ipmitool libbz2-dev \
	&& mkdir -p /usr/src/wimlib-code \
	&& mkdir -p /home/hanlon \
	&& git clone git://wimlib.net/wimlib /usr/src/wimlib-code \
	&& cd /usr/src/wimlib-code \
	&& ./bootstrap \
	&& ./configure --without-ntfs-3g --prefix=/usr \
	&& make -j"$(nproc)" \
	&& make install \
	&& apt-get purge -y --auto-remove \
	gettext \
	&& rm -Rf /usr/src/wimlib-code \
	&& apt-get -y autoremove \
    	&& apt-get -y clean \
    	&& rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

COPY . /home/hanlon

# We don't need gem docs
RUN echo "install: --no-rdoc --no-ri" > /etc/gemrc

RUN gem install bundle \
	&& cd /home/hanlon \
	&& bundle install --system

#ENV LANG en_US.UTF-8

ENV WIMLIB_IMAGEX_USE_UTF8 true
ENV HANLON_WEB_PATH /home/hanlon/web

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

WORKDIR /home/hanlon

# Hanlon by default runs at TCP 8026
EXPOSE 8026
EXPOSE 69/udp
EXPOSE 27017

# Install Extra Deps
RUN apt-get update && \
    apt-get -y install wget

# supervisor base configuration
ADD supervisor.conf /etc/supervisor.conf
ADD mongo/mongo.sv.conf /etc/supervisor/conf.d
ADD atftpd/atftpd.sv.conf /etc/supervisor/conf.d
ADD hanlon.sv.conf /etc/supervisor/conf.d 

# default command
CMD ["supervisord", "-c", "/etc/supervisor.conf"]