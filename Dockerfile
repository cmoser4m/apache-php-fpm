FROM centos:7
EXPOSE 80
EXPOSE 443

# update CentOS packages
RUN yum -y update

# devl tools required for compiling
RUN yum -y groupinstall "Development Tools"

# install the EPEL repositories (Extra Packages for Enterprise Linux), required for libmcrypt and other packages - see http://fedoraproject.org/wiki/EPEL
RUN yum -y install epel-release

# install required packages
RUN yum -y install libmcrypt libmcrypt-devel zlib zlib-devel openssl openssl-devel libxml2 libxml2-devel libcurl libcurl-devel libpng libpng-devel pcre-devel libaio

# create the www user
RUN adduser --system --create-home www && mkdir /home/www/tmp && chown -R www.www /home/www/tmp

# create temporary build directory in root
RUN mkdir /root/build

# copy and extract build files to /root/build directory
WORKDIR /root/build
COPY apr-1.5.2.tar.gz apr-util-1.5.4.tar.gz httpd-2.4.20.tar.gz php-7.0.6.tar.gz instantclient-basic-linux.x64-12.1.0.2.0.zip instantclient-sdk-linux.x64-12.1.0.2.0.zip /root/build/
RUN tar zxvf apr-1.5.2.tar.gz && tar zxvf apr-util-1.5.4.tar.gz && tar zxvf httpd-2.4.20.tar.gz && tar zxvf php-7.0.6.tar.gz
RUN unzip instantclient-basic-linux.x64-12.1.0.2.0.zip && unzip instantclient-sdk-linux.x64-12.1.0.2.0.zip

#### ORACLE INSTANT CLIENT

WORKDIR /root/build/instantclient_12_1
RUN ln -s libclntsh.so.12.1 libclntsh.so
WORKDIR /root/build
RUN mv instantclient_12_1 /usr/local/instantclient
RUN echo "/usr/local/instantclient" >> /etc/ld.so.conf.d/instantclient.conf


#### APACHE HTTPD AND RELATED

# build apr (required for compiling apache)
WORKDIR /root/build/apr-1.5.2
RUN ./configure && make && make install

# build apr-util (required for compiling apache)
WORKDIR /root/build/apr-util-1.5.4
RUN ./configure --with-apr=/usr/local/apr && make && make install

# build apache httpd
WORKDIR /root/build/httpd-2.4.20
RUN ./configure --enable-ssl && make && make install

# enable required apache modules
RUN /usr/local/apache2/bin/apxs -ea -n proxy mod_proxy.so
RUN /usr/local/apache2/bin/apxs -ea -n proxy_fcgi mod_proxy_fcgi.so
RUN /usr/local/apache2/bin/apxs -ea -n rewrite mod_rewrite.so

# add additional Listen directive for port 443 (https)
RUN echo "Listen 443" >> httpd.conf

# activate httpd.conf in the /home/www directory (all projects should have httpd.conf)
RUN echo "Include \"/home/www/app/httpd.conf\"" >> /usr/local/apache2/conf/httpd.conf

#### PHP AND RELATED

# build php
WORKDIR /root/build/php-7.0.6
RUN ./configure --with-curl --with-zlib --with-openssl --enable-mbstring=all --with-mcrypt --enable-fpm --with-fpm-user=www --with-fpm-group=www --exec-prefix=/usr/local --enable-zip && make -j 4 && make install

# copy php-fpm init scripts
WORKDIR /root/build/php-7.0.6/sapi/fpm
RUN cp init.d.php-fpm /etc/init.d/php-fpm
RUN chmod +x /etc/init.d/php-fpm

# copy php-fpm.conf and php.ini files
COPY php-fpm.conf /usr/local/etc/php-fpm.conf
COPY php.ini /usr/local/lib/php.ini

#### PHP EXTENSIONS (PDO_OCI and PCNTL)
WORKDIR /root/build/php-7.0.6/ext/pdo_oci
RUN phpize && ./configure --with-pdo-oci=instantclient,/usr/local/instantclient,12.1 && make && make install

WORKDIR /root/build/php-7.0.6/ext/pcntl
RUN phpize && ./configure && make && make install

#### COMPOSER
WORKDIR /usr/local/bin
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"


RUN /bin/bash