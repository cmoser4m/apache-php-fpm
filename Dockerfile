FROM centos:7
EXPOSE 80
EXPOSE 443

# update CentOS packages
# dev tools required for compiling
# install EPEL repos (Extra Packages for Enterprise Linux), for libmcrypt and others - see http://fedoraproject.org/wiki/EPEL
# other required packages:

RUN yum -y update && \
	yum -y groupinstall "Development Tools" && \
	yum -y install epel-release && \
	yum -y install \
		libmcrypt \
		libmcrypt-devel \
		zlib \
		zlib-devel \
		openssl \
		openssl-devel \
		libxml2 \
		libxml2-devel \
		libcurl \
		libcurl-devel \
		libpng \
		libpng-devel \
		pcre-devel \
		libaio \
		supervisor

# create the www user
RUN adduser --system --create-home www && mkdir /home/www/tmp && chown -R www.www /home/www/tmp

# create temporary build directory in tmp
RUN mkdir /tmp/build

# copy and extract build files to /tmp/build directory
WORKDIR /tmp/build
COPY apr-1.5.2.tar.gz apr-util-1.5.4.tar.gz httpd-2.4.20.tar.gz php-7.0.6.tar.gz instantclient-basic-linux.x64-12.1.0.2.0.zip instantclient-sdk-linux.x64-12.1.0.2.0.zip /tmp/build/
RUN tar zxvf apr-1.5.2.tar.gz && tar zxvf apr-util-1.5.4.tar.gz && tar zxvf httpd-2.4.20.tar.gz && tar zxvf php-7.0.6.tar.gz
RUN unzip instantclient-basic-linux.x64-12.1.0.2.0.zip && unzip instantclient-sdk-linux.x64-12.1.0.2.0.zip

#### ORACLE INSTANT CLIENT

WORKDIR /tmp/build/instantclient_12_1
RUN ln -s libclntsh.so.12.1 libclntsh.so
WORKDIR /tmp/build
RUN mv instantclient_12_1 /usr/local/instantclient
RUN echo "/usr/local/instantclient" >> /etc/ld.so.conf.d/instantclient.conf


#### APACHE HTTPD AND RELATED

# build apr (required for compiling apache)
WORKDIR /tmp/build/apr-1.5.2
RUN ./configure && make -j 4 && make install

# build apr-util (required for compiling apache)
WORKDIR /tmp/build/apr-util-1.5.4
RUN ./configure --with-apr=/usr/local/apr && make -j 4 && make install

# build apache httpd
WORKDIR /tmp/build/httpd-2.4.20
RUN ./configure --enable-ssl && make -j 4 && make install

# enable required apache modules
RUN /usr/local/apache2/bin/apxs -ea -n proxy mod_proxy.so
RUN /usr/local/apache2/bin/apxs -ea -n proxy_fcgi mod_proxy_fcgi.so
RUN /usr/local/apache2/bin/apxs -ea -n rewrite mod_rewrite.so

#### PHP AND RELATED

# build php
WORKDIR /tmp/build/php-7.0.6
RUN ./configure --with-curl --with-zlib --with-openssl --enable-mbstring=all --with-mcrypt --enable-fpm --with-fpm-user=www --with-fpm-group=www --exec-prefix=/usr/local --enable-zip && make -j 4 && make install

# default php-fpm.conf and php.ini files
COPY php-fpm.conf /usr/local/etc/php-fpm.conf
COPY php.ini /usr/local/lib/php.ini

#### PHP EXTENSIONS (PDO_OCI and PCNTL)
WORKDIR /tmp/build/php-7.0.6/ext/pdo_oci
RUN phpize && ./configure --with-pdo-oci=instantclient,/usr/local/instantclient,12.1 && make -j 4 && make install

WORKDIR /tmp/build/php-7.0.6/ext/pcntl
RUN phpize && ./configure && make -j 4 && make install

#### COMPOSER
WORKDIR /usr/local/bin
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"

#### SUPERVISORD
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENTRYPOINT ["/usr/bin/supervisord"]
CMD ["-c", "/etc/supervisor/conf.d/supervisord.conf"]