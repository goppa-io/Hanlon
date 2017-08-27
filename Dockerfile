# Hanlon server
#
# VERSION 3.0.1

FROM iidlx/ruby:2.2
MAINTAINER Denver Williams <denver@ii.org.nz>

WORKDIR /home/hanlon
RUN git clone https://gitlab.ii.org.nz/iichip/Hanlon.git -b rpi3 /home/hanlon
RUN git submodule update --init --recursive

#AFTPD

RUN cp atftpd/run.sh /
RUN cp atftpd/build.yml /
RUN cp atftpd/atftp.yml /
RUN cp atftpd/menu.c32 /
RUN cp atftpd/pxelinux.0 /
RUN mkdir -p /tftpboot/pxelinux.cfg/ \
    && cp atftpd/default /tftpboot/pxelinux.cfg/
RUN cp atftpd/ipxe/ipxe-debug.lkrn /
RUN cp atftpd/ipxe/ipxe-debug.pxe /
RUN cp atftpd/ipxe/ipxe.lkrn /
RUN cp atftpd/ipxe/ipxe.pxe /
RUN cp atftpd/ipxe/undionly-debug.kpxe /
RUN cp atftpd/ipxe/undionly.kpxe /

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

RUN mkdir /home/dhcpd \
    && cp dnsmasq/dnsmasq.hanlon.conf /home/dhcpd/ \
    && cp dnsmasq/dnsmasq.sh /home/dhcpd/

RUN chmod +x /home/dhcpd/dnsmasq.sh

RUN DEBIAN_FRONTEND=noninteractive apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install dnsmasq freeipmi ipmitool openipmi lsof sipcalc
RUN cp dnsmasq/etc/default/* /etc/default/

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
	&& apt-get install -y libxml2 gettext libfuse-dev libattr1-dev git build-essential libssl-dev p7zip-full fuseiso ipmitool libbz2-dev net-tools \
	# && mkdir -p /usr/src/wimlib-code \
	&& mkdir -p /home/hanlon \
	# && git clone git://wimlib.net/wimlib /usr/src/wimlib-code \
	# && cd /usr/src/wimlib-code \
	# && ./bootstrap \
	# && ./configure --without-ntfs-3g --prefix=/usr \
	# && make -j"$(nproc)" \
	# && make install \
	&& apt-get purge -y --auto-remove \
	gettext \
	# && rm -Rf /usr/src/wimlib-code \
	&& apt-get -y autoremove \
    	&& apt-get -y clean \
    	&& rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*


# We don't need gem docs
RUN echo "install: --no-rdoc --no-ri" > /etc/gemrc

RUN gem install bundle \
	&& cd /home/hanlon \
	&& bundle install --system

ENV WIMLIB_IMAGEX_USE_UTF8 true
ENV HANLON_WEB_PATH /home/hanlon/web

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh


# Hanlon by default runs at TCP 8026
EXPOSE 8026
EXPOSE 69/udp

# # Chef
# RUN gem install chef-zero
# RUN chmod +x /home/hanlon/Chef/entrypoint.sh
# RUN git clone -b resin https://gitlab.ii.org.nz/iichip/chef-provisioning-k8s.git /home/hanlon/Chef/chef-provisioning-k8s
# RUN gem install bundle \
#         && cd /home/hanlon/Chef/chef-provisioning-k8s \
#         && bundle install --system

# supervisor base configuration
COPY supervisor.conf /etc/supervisor.conf
RUN cp atftpd/atftpd.sv.conf /etc/supervisor/conf.d/
COPY hanlon.sv.conf /etc/supervisor/conf.d/ 
RUN cp dnsmasq/dnsmasq.sv.conf /etc/supervisor/conf.d/
# ADD Chef/chef.sv.conf /etc/supervisor/conf.d/

# default command
CMD ["supervisord", "-c", "/etc/supervisor.conf"]
