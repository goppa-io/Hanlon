# Hanlon server
#
# VERSION 3.0.1

FROM iidlx/ruby:2.2
MAINTAINER Joseph Callen <jcpowermac@gmail.com>

COPY atftpd/run.sh /
COPY atftpd/build.yml /
COPY atftpd/atftp.yml /
COPY atftpd/menu.c32 /
COPY atftpd/pxelinux.0 /
COPY atftpd/default /tftpboot/pxelinux.cfg/
COPY atftpd/ipxe/ipxe-debug.lkrn /
COPY atftpd/ipxe/ipxe-debug.pxe /
COPY atftpd/ipxe/ipxe.lkrn /
COPY atftpd/ipxe/ipxe.pxe /
COPY atftpd/ipxe/undionly-debug.kpxe /
COPY atftpd/ipxe/undionly.kpxe /

RUN apt-get -y update \
    && apt-get -y install ansible wget \
    # && /usr/bin/ansible-playbook -c local -i localhost, /build.yml \ Disable for arm
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
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-suggests \
		mongodb \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mongodb \
	&& mv /etc/mongodb.conf /etc/mongodb.conf.orig

RUN mkdir -p /data/db /data/configdb \
	&& chown -R mongodb:mongodb /data/db /data/configdb
VOLUME /data/db /data/configdb

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