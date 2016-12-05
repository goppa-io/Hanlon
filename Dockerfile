# Hanlon server
#
# VERSION 3.0.1

FROM iidlx/ruby:2.2
MAINTAINER Joseph Callen <jcpowermac@gmail.com>

#AFTPD

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

# DNSMASQ

COPY dnsmasq/dnsmasq.hanlon.conf /home/dhcpd/
COPY dnsmasq/dnsmasq.sh /home/dhcpd/

RUN chmod +x /home/dhcpd/dnsmasq.sh

RUN DEBIAN_FRONTEND=noninteractive apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install dnsmasq freeipmi ipmitool openipmi lsof sipcalc
COPY dnsmasq/etc/default/* /etc/default/

#HANLON
# supervisor installation && 
# create directory for child images to store configuration in
RUN apt-get update && \
  apt-get -y install supervisor vim && \
  mkdir -p /var/log/supervisor && \
  mkdir -p /etc/supervisor/conf.d

# Enabling the unstable packages to install fuseiso
RUN echo 'deb http://ftp.nz.debian.org/debian unstable main non-free contrib' >> /etc/apt/sources.list \
	&& echo 'Package: *' >> /etc/apt/preferences.d/pin \
	&& echo 'Pin: release a=stable' >> /etc/apt/preferences.d/pin \
	&& echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/pin \
	&& echo '' >> /etc/apt/preferences.d/pin \
	&& echo 'Package: *' >> /etc/apt/preferences.d/pin \
	&& echo 'Pin: release a=stable' >> /etc/apt/preferences.d/pin \
	&& echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/pin


# Install the required dependencies
RUN apt-get update -y \
	&& apt-get install -y libxml2 gettext libfuse-dev libattr1-dev git build-essential libssl-dev ipmitool libbz2-dev net-tools \
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

ENV WIMLIB_IMAGEX_USE_UTF8 true
ENV HANLON_WEB_PATH /home/hanlon/web

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

WORKDIR /home/hanlon

# Hanlon by default runs at TCP 8026
EXPOSE 8026
EXPOSE 69/udp

# supervisor base configuration
ADD supervisor.conf /etc/supervisor.conf
ADD atftpd/atftpd.sv.conf /etc/supervisor/conf.d/
ADD hanlon.sv.conf /etc/supervisor/conf.d/ 
ADD dnsmasq/dnsmasq.sv.conf /etc/supervisor/conf.d/

# default command
CMD ["supervisord", "-c", "/etc/supervisor.conf"]
