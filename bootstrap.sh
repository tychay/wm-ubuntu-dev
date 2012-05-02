#!/bin/bash
# vim:set tabstop=4 shiftwidth=4 softtabstop=4 foldmethod=marker:
#
# This boostraps the dev environment (port from TGIFramework
# <https://github.com/tychay/TGIFramework>).
#
# To use, start with a vanilla install of ubuntu server, drop this in and run
# $ ./install

# functions {{{
check_dpkg() { dpkg -l $1 | grep ^ii | wc -l; }
is_eth0() { ifconfig | grep eth0 | wc -l; }
get_ip() { ifconfig | grep 'inet addr' |  awk -F: '{ print $2 }' | awk '{ print $1 }' | grep -v 127.0.0.1; }
pear_installed () { pear list -a | grep ^$1 | wc -l ; }
PHP_EXT_TEST=./extension_installed.php
# {{{  pecl_update_or_install()
# $1 = package name
# $2 = package name in pecl (may have -beta or the like)
# $3 = if set, package name in ubuntu
pecl_update_or_install () {
	if [ `$PHP_EXT_TEST $1` ]; then
		if [ $DO_UPGRADE ]; then
			if [ "$3" != '' ]; then
				echo "### Updating $1...";
				$SUDO apt-get update $3
			else
				echo "### Upgrading $1...";
				$SUDO pecl upgrade $2
			fi
		fi
	else
		echo "### Installing $1...";
		if [ "$3" != '' ]; then
			$SUDO apt-get install $3
		else
			$SUDO pecl install $2
			if [ "$1" = 'xdebug' ]; then
				echo '### Be sure to add to your php.ini: zend_extension="<something>/xdebug.so" NOT! extension=xdebug.so'
			else
				echo "### Be sure to add to your php.ini: extension=$1.so"
				# Let's add config for stuff manually
				echo "extension=${1}.so" | $SUDO tee /etc/php5/conf.d/${1}.ini
				$SUDO cp /etc/php5/conf.d/${1}.ini /etc/php5/conf.d/${1}.ini
			fi
		fi
		PACKAGES_INSTALLED="$1 $PACKAGES_INSTALLED"
	fi
}
# }}}
# }}}
# Set up environment ($EDITOR) {{{
SUDO='sudo'
#DO_UPGRADE='1' #Set this to upgrade
if [ !$EDITOR ]; then
	echo -n "Choose your preferred editor: "
	read EDITOR
	EDITOR=`which ${EDITOR}`
fi
if [ $EDITOR == '' ]; then
	EDITOR="/usr/bin/pico"
fi
# }}}
# Fix broken networking on clone {{{
if [ `is_eth0` = 0 ]; then
	echo "### Your networking is broken."
	echo "### Odds are because you have the parent image  MAC address."
	echo -n '### Delete the first PCI line, In second replace NAME="eth1" with NAME="eth0":'
	read IGNORE
	$SUDO $EDITOR  /etc/udev/rules.d/70-persistent-net.rules
	echo "### Rebooting in order to rebuild networking from startup rules..."
	$SUDO reboot
fi
# }}}
# Computer renaming (set $HOSTNAME) {{{
if [ $1 ]; then
	HOSTNAME=$1
else
	echo -n "### If you wish to change the hostname (cloned an instance), please type in subdomain name: "
	read HOSTNAME
fi

if [ $HOSTNAME ]; then
	echo "$HOSTNAME" | $SUDO tee /etc/hostname
	echo "127.0.0.1   $HOSTNAME" | $SUDO tee -a /etc/hosts
	echo -n "### You may want to clean up this file to remove old hostnames:"
	read IGNORE
	$SUDO $EDITOR /etc/hosts
	echo -n "### Reboot for hostname to take effect: "
	read IGNORE
	# Reboot for hostname to take effect
	$SUDO reboot
fi
HOSTNAME=`cat /etc/hostname`
# }}}
IP_ADDRESS=`get_ip`
echo "### Your IP address is ${IP_ADDRESS}"
# Install LAMP {{{
# http://www.howtoforge.com/ubuntu_lamp_for_newbies
if [ `check_dpkg apache2` = 0 ]; then
	echo "### Installing apache2..."
	$SUDO apt-get install apache2
	echo "### You may want to add the following line to your client's /etc/hosts"
	echo "$IP_ADDRESS   $HOSTNAME"
	echo -n "### Test out Apache by going to http://${IP_ADDRESS}/:"
	read IGNORE
fi
if [ `check_dpkg libapache2-mod-php5` = 0 ]; then
	echo "### Installing php..."
	$SUDO apt-get install php5 libapache2-mod-php5
	$SUDO service apache2 graceful
	echo "<?php phpinfo(); ?>" | $SUDO tee /var/www/phpinfo.php
	echo -n "### Test out Apache by going to http://${IP_ADDRESS}/phpinfo.php:"
	read IGNORE
fi
if [ `check_dpkg mysql-server` = 0 ]; then
	echo "### Installing mysql..."
	$SUDO apt-get install mysql-server
	echo "### (Optional) May want to add"
	echo "bind address = ${IP_ADDRESS}"
	echo -n "### so outside IPs can bind:"
	read IGNORE
	$SUDO $EDITOR /etc/mysql/my.cnf
	sudo service mysql restart
fi
if [ `check_dpkg phpmyadmin` = 0 ]; then
	echo "### Installing phpmyadmin interfaces..."
	$SUDO apt-get install libapache2-mod-auth-mysql php5-mysql phpmyadmin
	$SUDO service apache2 graceful
	echo -n "### Test out PHPMyAdmin by going to http://${IP_ADDRESS}/phpmyadmin/:"
	read IGNORE
fi
echo "### LAMP installed"
# }}}
# Install PHP Compile environment {{{
# http://ubuntuforums.org/showthread.php?t=525257
if [ `check_dpkg php5-dev` = 0 ]; then
	echo "### Installing PHP dev libraries..."
	$SUDO apt-get install php5-dev
fi
if [ `check_dpkg php-pear` = 0 ]; then
	echo "### Installing PEAR libraries..."
	$SUDO apt-get install php-pear
fi
# }}}
PACKAGES_INSTALLED=""
# Install APC {{{
pecl_update_or_install apc apc-beta php-apc
# }}}
# Install igbinary (used for libmemcached) {{{
pecl_update_or_install igbinary igbinary
# }}}
# Install memcached (with igbinary) {{{
# http://www.neanderthal-technology.com/2011/11/ubuntu-10-install-php-memcached-with-igbinary-support/
# TODO: -enable-memcached-igbinary (in php-pecl-memcached)
if [ `check_dpkg libmemcached6` = 0 ]; then
	echo "### Installing libmemcached libraries..."
	$SUDO apt-get install libmemcached6 libmemcached-dev
fi
if [ `$PHP_EXT_TEST memcached` ]; then
	# TODO: upgrade memcached?
	if [ $DO_UPGRADE ]; then
		echo '### Add upgrader for memcached here?'
	fi
else
	echo "### Installing memcached extension..."
	if [ ! -f memcached-*.tgz ]; then
		$SUDO pecl download memcached
	fi
	if [ ! -d memcached-* ]; then
		tar zxf memcached-*.tgz
		rm -f packet.xml channel.xml
	fi
	pushd memcached-*
		phpize
		chmod a+x configure
		./configure -enable-memcached-igbinary --with-libmemcached-dir=/usr
		make
		$SUDO make install
		echo "### Be sure to add to your php.ini: extension=memcached.so"
		echo "extension=memcached.so" | $SUDO tee /etc/php5/conf.d/memcached.ini
		$SUDO cp /etc/php5/conf.d/memcached.ini /etc/php5/conf.d/memcached.ini
		PACKAGES_INSTALLED="$1 $PACKAGES_INSTALLED"
	popd
fi
# }}}
# Install XDEBUG {{{
pecl_update_or_install xdebug xdebug php5-xdebug
# }}}
# Install Graphviz (used for showing callgraphs in inclued or xhprof) {{{
if [ `check_dpkg graphviz` = 0 ]; then
	echo "### Installing GraphViz...";
	$SUDO apt-get install graphviz
fi
# }}}
# Install inclued {{{
# No fedora package for inclued
INCLUED='inclued-beta' #2010-02-22 it went beta, see http://pecl.php.net/package/inclued
pecl_update_or_install inclued $INCLUED
# }}}
# TODO: xhprof
# TODO: Webgrind
if [ "$PACKAGES_INSTALLED" ]; then
	echo '### You may need to add stuff to your $PHP_INI (or /etc/php.d/) and restart'
	echo "###  $PACKAGES_INSTALLED"
fi
$SUDO service apache2 graceful
exit







# EDITME: Set the full path to binaries {{{
if [ $1 ]; then
	DISTRIBUTION=$1
else
	if [ "`which port`" != '' ]; then
		DISTRIBUTION='macports'
	elif [ "`which yum`" != '' ]; then
		DISTRIBUTION='fedora'
	elif [ "`which apt-get`" != '' ]; then
		DISTRIBUTION='ubuntu'
	else
		DISTRIBUTION='???'
	fi
fi
echo "### Distribution is $DISTRIBUTION";
# Should it run as sudo? 
SUDO='sudo'


PHP=`which php`
if [ $PHP != '/usr/bin/php' ]; then
	echo "### Do to env POSIXness on Linux, we can not depend on /usr/bin/env. Files such as generate_gloabl_version.php assumes PHP are located at /usr/bin/php which is not the case for you. You may need to update these bin/* scripts for this to work."
fi
APACHECTL=`which apachectl`
PHP_INI=/etc/php.ini # TODO: check php --ini

# MacPorts: {{{
if [ $DISTRIBUTION = "macports" ]; then
# Instructions for installing: {{{
# http://forums.macnn.com/79/developer-center/322362/tutorial-installing-apache-2-php-5-a/
# 0) Have XCode installed
# 1) install MacPorts Pkg http://www.macports.org/install.php
# 2) create a new terminal
# 3) $ sudo port -v selfupdate						  #update ports
# 4) $ sudo port install apache2						#install apache
#	$ sudo port install mysql5 +server				 #install mysql
#	$ sudo port install php5 +apache2 +pear
#													   #install php+pear
# 5) $ cd /opt/local/apache2/modules					$install mod_php
#	$ sudo /opt/local/apache2/bin/apxs -a -e -n "php5" libphp5.so
# 6) $ sudo vim /opt/local/apache2/conf/httpd.conf
#	#DocumentRoot "/opt/local/apache2/htdocs"		  #preserve default site
#	DocumentRoot "/Library/WebServer/Documents"
#	...
#	# User home directories
#	Include conf/extra/httpd-userdir.conf			  # user home dirs
#	Include conf/extra/mod_php.conf					# mod php loader
#	# If you generated a cert into: /opt/local/apache2/conf/server.crt
#	Include conf/extra/httpd-ssl.conf				  # ssl support
#	#also consider conf/extra/httpd-autoindex.conf (Fancy directory listing)
#	#			  conf/extra/httpd-default.conf (Some default settings)
#	#			  conf/extra/httpd-vhosts.conf (virtual hosts)
#	....
#	#DirectoryIndex index.html
#	DirectoryIndex index.html index.php
# 6) $ vim ~/.profile
#	alias apache2ctl='sudo /opt/local/apache2/bin/apachectl'
#	alias mysqlstart='sudo mysqld_safe5 &'
#	alias mysqlstop='mysqladmin5 -u root -p shutdown' 
#	
#	# remember to start a new shell
# 7) $ sudo launchctl load -w /Library/LaunchDaemons/org.macports.apache2.plist
#	$ sudo launchctl load -w /Library/LaunchDaemons/org.macports.mysql5.plist
# 8) $ sudo mkdir /opt/local/var/db/mysql5
#	$ sudo chown mysql:mysql /opt/local/var/db/mysql5
#	$ sudo -u mysql mysql_install_db5
#	$ mysqlstart
#	$ mysqladmin5 -u root password [yourpw]
# 9) $ sudo cp /opt/local/etc/php5/php.ini-production /opt/local/etc/php5/php.ini
# 10)# TODO: PDO mysql is missing!!!!  # http://c6s.co.uk/webdev/119
#	$ sudo port install php5-sqlite 
#	$ sudo port install php5-mysql 
#	$ sudo port install php5-tidy 
#	$ sudo port install php5-zip 
#	$ sudo port install php5-curl 
#	$ sudo port install php5-big_int   #bcmath substitute
#	# copy other ini files as necessary (most of them are in res/php.ini, but
#	# be sure to edit xdebug.ini before copying
# 11)$ apache2ctl start
# AFTER:
# --)$ sudo port load memcached
# install sqlite3
# }}}
	if [ $DO_UPGRADE ]; then
		$SUDO port -v selfupdate
		#$SUDO port upgrade outdated
	fi
	$SUDO port install memcached
	#PHP=/opt/local/bin/php
	APACHECTL=/opt/local/apache2/bin/apachectl
	#PHP_INI=/opt/local/etc
	PHP_INI=/opt/local/etc/php5/php.ini
	# Set path to libmemcached (to use php-memcached instead of php-memcache)
	LIBMEMCACHED=/opt/local
fi
# }}}
# Fedora/CentOS: {{{
if [ $DISTRIBUTION = 'fedora' ]; then
	# Set path to libmemcached (to use php-memcached instead of php-memcache)
	LIBMEMCACHED=/usr
fi
# }}}
# Ubuntu/Debian: {{{
if [ $DISTRIBUTION = 'ubuntu' ]; then
	check_dpkg() { dpkg -l $1 | grep ^ii | wc -l; }
	# Set path to libmemcached (to use php-memcached instead of php-memcache)
	LIBMEMCACHED=/usr
	# ubuntu has separate ini files for apache vs. cli.
	PHP_INI=/etc/php5/apache2/php.ini
	# build environment for installing on ubuntu
	if [ $DO_UPGRADE ]; then
		$SUDO apt-get update
	fi
	# Need libpcre3-dev to compile APC
	if [ `check_dpkg libpcre3-dev` ]; then
		$SUDO apt-get install libpcre3-dev
	fi
	# Need curl to grab packages
	if [ `check_dpkg curl` ]; then
		$SUDO apt-get install curl
	fi
	# Needed to unzip YUI packages
	if [ `check_dpkg zip` ]; then
		$SUDO apt-get install zip
	fi
	# Needed to execute YUI compressor
	if [ `check_dpkg default-jre` ]; then
		$SUDO apt-get install default-jre
	fi
	# Needed to generate version numbers
	if [ `check_dpkg git` ]; then
		$SUDO apt-get install git
	fi
	echo "### REMEMBER! On ubuntu, there are two different directories for CLI PHP and APACHE2 PHP configuration. Both must be updated for this script to work properly"
fi
# }}}
# }}}
# shell function declarations {{{
# {{{  pear_update_or_install()
# $1 = package name
# $2 = package name in pear (may have -beta or the like)
# $3 = pear channel
pear_update_or_install () {
	if [ $2 ]; then
		pkg_path=$2;
	else
		pkg_path=$1;
	fi
	if [ `pear_installed $1` ]; then
		echo "### UPGRADING $1...";
		$SUDO pear upgrade $pkg_path
	else
		echo "### INSTALLING $1";
		if [ $3 ]; then
			$SUDO pear channel-discover $3
		fi
		$SUDO pear install $pkg_path
	fi
}
# }}}
# }}}
# UTILS {{{
PHP_VERSION_TEST=$BASE_DIR/bs/version_compare.php
# }}}
# PACKAGES {{{
# php extensions {{{
# RUNKIT {{{
#RUNKIT='runkit'
# Runkit is still in beta.
# New version at https://github.com/zenovich/runkit/
RUNKIT='channel://pecl.php.net/runkit-0.9'
# Note that Runkit 0.9 doesn't compile in PHP 5.2+
if [ `$PHP_VERSION_TEST 5.2` ]; then
	RUNKIT='cvs'
fi
# }}}
# APC {{{
#http://pecl.php.net/package/apc
APC='apc'
if [ `$PHP_VERSION_TEST 5.3` ]; then
	APC='apc-beta'
fi
#APC='http://pecl.php.net/get/APC'
# }}}
# }}}
# pear packages {{{
#SAVANT='http://phpsavant.com/Savant3-3.0.0.tgz'
#FIREPHP_CHANNEL='pear.firephp.org'
#FIREPHP='FirePHPCore'
#PHPDOC='PhpDocumentor'
# }}}
# downloads {{{
# YUI & YUI compressor {{{
YUI='yui'
YUI_VERSION='2.9.0'
YUI_BIN="yui_${YUI_VERSION}"
YUI_PKG="${YUI_BIN}.zip"
#YUI_URL="http://yuilibrary.com/downloads/yui2/${YUI_PKG}"
YUI_URL="http://yui.zenfs.com/releases/yui2/${YUI_PKG}"

YUIC='yuicompressor'
YUIC_VERSION='2.4.7'
YUIC_BIN="${YUIC}-${YUIC_VERSION}"
YUIC_PKG="${YUIC_BIN}.zip"
#YUIC_URL="http://www.julienlecomte.net/yuicompressor/${YUIC_PKG}"
YUIC_URL="http://yui.zenfs.com/releases/yuicompressor/${YUIC_PKG}"
# }}}
# WEBGRIND {{{
WEBGRIND='webgrind'
WEBGRIND_VERSION='1.0'
WEBGRIND_BIN="${WEBGRIND}-release-${WEBGRIND_VERSION}"
WEBGRIND_PKG="${WEBGRIND_BIN}.zip"
WEBGRIND_URL="http://webgrind.googlecode.com/files/${WEBGRIND_PKG}"
# }}}
# RUNKIT {{{
RUNKIT='runkit'
RUNKIT_VERSION='1.0.3'
RUNKIT_DIR="${RUNKIT}-${RUNKIT_VERSION}"
RUNKIT_PKG="${RUNKIT_DIR}.tgz"
RUNKIT_URL="https://github.com/downloads/zenovich/runkit/${RUNKIT_PKG}"
# }}}
# }}}
# }}}
# Make directories {{{
if [ ! -d packages ]; then
	mkdir packages
fi
if [ ! -d build ]; then
	mkdir build
fi
# }}}
# Install/update PEAR {{{
if [ `which pear` ]; then
	$SUDO pear config-set php_bin $PHP
	if [ $DO_UPGRADE ]; then
		$SUDO pear list-upgrades
		if [ $DISTRIBUTION = 'fedora' ]; then
			$SUDO pear uninstall apc
			$SUDO pear uninstall memcache
		fi
		$SUDO pear upgrade-all
		$SUDO pear channel-update pear.php.net
		$SUDO pear channel-update pecl.php.net
	fi
else
	$SUDO $PHP -q bs/go-pear.php
fi
if [ `which pecl` ]; then
	$SUDO pear config-set php_ini $PHP_INI
	$SUDO pecl config-set php_ini $PHP_INI
fi
# }}}
# Install big_int {{{ http://pecl.php.net/package/big_int
#pecl_update_or_install big_int big_int
# BUG: Cannot find config.m4 (in big_int-1.0.7)
if [ `$PHP_EXT_TEST big_int` ]; then
	if [ $DO_UPGRADE ]; then
		echo "### No way to hande upgrading with big_int currently"
	fi
else
	#$SUDO pecl install $2
	pushd packages
		$SUDO pecl download big_int
		tar zxf big_int-*.tgz
		pushd big_int-*
			phpize
			chmod a+x configure
			./configure
			make
			sudo make install
		popd
	popd
	echo "### Be sure to add to your php.ini: extension=$1.so"
	PACKAGES_INSTALLED="big_int $PACKAGES_INSTALLED"
fi
#echo "### big_int..."
#if [ `$PHP_EXT_TEST big_int` ]; then
#	$SUDO pecl upgrade big_int
#else
#	$SUDO pecl install big_int
#fi
# }}}
# Install mailparse {{{
# Needed fr parsing RFC822 e-mails
pecl_update_or_install mailparse mailparse php-pecl-mailparse php5-mailparse
# }}}
# Install PEAR packages: {{{ Savant, FirePHP, PhpDocumentor
# Old download was: SAVANT='http://phpsavant.com/Savant3-3.0.0.tgz'
# Old Savant PEAR repository   $SUDO pear channel-discover savant.pearified.com
$SUDO pear channel-discover phpsavant.com
pear_update_or_install Savant3 savant/Savant3 phpsavant.com
#echo '### NB: There is a bug in Savant PHP Fatal error:  Method Savant3::__tostring() cannot take arguments in /usr/share/pear/Savant3.php on line 241'
$SUDO pear channel-discover pear.firephp.org
pear_update_or_install FirePHPCore firephp/FirePHPCore pear.firephp.org
pear_update_or_install PhpDocumentor
# }}}
# FRAMEWORK: Install YUI && YUI Compressor {{{
pushd packages
	if [ ! -f ${YUI_PKG} ]; then
		echo "### Downloading $YUI_URL..."
		curl -O $YUI_URL;
	fi
	if [ ! -f ${YUIC_PKG} ]; then
		echo "### Downloading $YUIC_URL..."
		curl -O $YUIC_URL;
	fi
popd
pushd build
	if [ ! -d yui ]; then
		echo "### Unpacking ${YUI_PKG}..."
		unzip $BASE_DIR/packages/${YUI_PKG}
	fi
	if [ ! -d ${YUIC_BIN} ]; then
		echo "### Unpacking ${YUIC_PKG}..."
		unzip $BASE_DIR/packages/${YUIC_PKG}
	fi
popd
pushd framework/res
	if [ ! -f ${YUIC_BIN}.jar ]; then
		echo "### INSTALLING ${YUIC_BIN}.jar..."
		cp $BASE_DIR/build/$YUIC_BIN/build/${YUIC_BIN}.jar .
	fi
popd
pushd samples/www/m/res
	if [ ! -d yui ]; then
		mkdir yui
	fi
	if [ ! -d yui/${YUI_VERSION} ]; then
		echo "### INSTALLING yui/${YUI_VERSION}..."
		mv $BASE_DIR/build/yui ./yui/${YUI_VERSION}
	fi
popd
# }}}
# SAMPLES: Install samples {{{
echo "### Building global_version config...."
./framework/bin/generate_global_version.php samples/config/global_version.php
pushd samples
	if [ ! -d traces ]; then
		mkdir traces
		chmod 777 traces
	fi
	if [ ! -d inclued ]; then
		mkdir inclued
		chmod 777 inclued
	fi
	if [ ! -f www/.htaccess ]; then
		echo "### Building .htaccess file for samples...."
		cat res/default.htaccess | sed "s|{{{BASE_DIR}}}|${BASE_DIR}|" >www/.htaccess
	fi
	if [ ! -d www/m/dyn ]; then
		mkdir www/m/dyn
		chmod 777 www/m/dyn
	fi
popd
# }}}
# SAMPLES: Install WebGrind {{{
pushd packages
	if [ ! -f ${WEBGRIND_PKG} ]; then
		echo "### Downloading $WEBGRIND_URL..."
		curl -O $WEBGRIND_URL;
	fi
popd
pushd samples/www
	if [ ! -d ${WEBGRIND} ]; then
		echo "### Unpacking ${WEBGRIND_PKG}..."
		unzip $BASE_DIR/packages/${WEBGRIND_PKG}
	fi
	pushd $WEBGRIND
		if [ ! -f .htaccess ]; then
			cp ../../res/webgrind.htaccess .htaccess
			echo "### Update profilerDir to point to $BASE_DIR/samples/traces"
			vim +20 config.php
		fi
	popd
popd
# }}}
#echo "### Running phpdoc"
#./bs/phpdoc.sh
