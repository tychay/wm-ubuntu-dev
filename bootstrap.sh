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
	echo -n "### Choose your preferred editor: "
	read EDITOR
	EDITOR=`which ${EDITOR}`
fi
if [ $EDITOR = '' ]; then
	EDITOR="/usr/bin/pico"
fi
# }}}
# {{{ $1 = HOSTNAME
if [ $1 ]; then
	HOSTNAME=$1
else
	echo -n "### If you wish to change the hostname (cloned an instance), please type in subdomain name: "
	read HOSTNAME
fi
# }}}
# $2 = CONFIG_DIR {{{
if [ $2 ]; then
	CONFIG_DIR=$2
fi
if [ ! $CONFIG_DIR ]; then
	echo -n "### Set directory to store configs: "
	read CONFIG_DIR
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
if [ $HOSTNAME ]; then
	if [ `cat /etc/hostname` != $HOSTNAME ]; then
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
fi
HOSTNAME=`cat /etc/hostname`
# }}}
IP_ADDRESS=`get_ip`
echo "### Your IP address is ${IP_ADDRESS}"
$SUDO apt-get update
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
	echo "bind-address = ${IP_ADDRESS}"
	echo -n "### so outside IPs can bind:"
	read IGNORE
	if [ $EDITOR == '/usr/bin/vim' ]; then
		$SUDO $EDITOR /etc/mysql/my.cnf +53
	else
		$SUDO $EDITOR /etc/mysql/my.cnf
	fi
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
if [ ! -d 'build' ]; then
	mkdir build
fi
# Install Git {{{
# Needed to generate version numbers and sync git repositories
if [ `check_dpkg git` ]; then
	echo "### Installing git..."
	$SUDO apt-get install git
fi
pecl_update_or_install curl curl php5-curl
# }}}
# Install Zip {{{
# Needed to unzip packages
if [ `check_dpkg zip` ]; then
	echo "### Installing zip..."
	$SUDO apt-get install zip
fi
pecl_update_or_install curl curl php5-curl
# }}}
# Install curl {{{
# Need curl to grab downloads
if [ `check_dpkg curl` ]; then
	echo "### Installing curl..."
	$SUDO apt-get install curl
fi
pecl_update_or_install curl curl php5-curl
# }}}
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
	pushd build
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
		PACKAGES_INSTALLED="memcached $PACKAGES_INSTALLED"
	popd
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
# Install xhprof (facebook) {{{
# http://stojg.se/notes/install-xhprof-for-php5-on-centos-ubuntu-and-debian/
# https://github.com/facebook/xhprof
XHPROF_URL="https://github.com/facebook/xhprof/zipball/master"
XHPROF_ZIP="facebook-xhprof.zip"
if [ `$PHP_EXT_TEST xhprof` ]; then
	if [ $DO_UPGRADE ]; then
		# TODO: upgrade xhprof?
		echo '### Add upgrader for xhprof here?'
	fi
else
	echo "### Installing xhprof extension..."
	pushd build
	if [ ! -f $XHPROF_ZIP ]; then
		echo "### Downloading xhprof from Facebook GitHub..."
		curl -L -o ${XHPROF_ZIP} ${XHPROF_URL}
	fi
	if [ ! -d 'facebook-xhprof-*' ]; then
		unzip $XHPROF_ZIP
	fi
	pushd facebook-xhprof-*/extension
		phpize
		chmod a+x configure
		./configure
		make
		$SUDO make install
		echo "### Be sure to add to your php.ini: extension=xhprof.so"
		echo "extension=xhprof.so" | $SUDO tee /etc/php5/conf.d/xhprof.ini
		$SUDO cp /etc/php5/conf.d/xhprof.ini /etc/php5/conf.d/xhprof.ini
		PACKAGES_INSTALLED="xhprof $PACKAGES_INSTALLED"
	popd
	popd
fi
# }}}
# Install XHGUI {{{
# http://blog.preinheimer.com/index.php?/archives/355-A-GUI-for-XHProf.html
# https://github.com/preinheimer/xhprof
# http://phpadvent.org/2010/profiling-with-xhgui-by-paul-reinheimer
XHPROF_GUI_GIT="git://github.com/preinheimer/xhprof.git"
XHPROF_GUI="xhprof_lib"
if [ ! -d build/${XHPROF_GUI} ]; then
	echo "### Downloading XHGui...."
	pushd build
		git clone $XHPROF_GUI_GIT
	popd
fi
# TODO: install xhprof gui (a la phpmyadmin)
# }}}
# Install V8JS and extension {{{
# http://css.dzone.com/articles/running-javascript-inside-php
# TODO: -enable-memcached-igbinary (in php-pecl-memcached)
if [ `check_dpkg libv8-dev` = 0 ]; then
	echo "### Installing V8 library..."
	$SUDO apt-get install libv8-dev libv8-dbg
fi
pecl_update_or_install v8js v8js-beta
# }}}
# TODO: Webgrind

# Move configs magic {{{
if [ ! -d $CONFIG_DIR ]; then
	echo -n "### If you wish to change the hostname (cloned an instance), please type in subdomain name: "
	mkdir $CONFIG_DIR
fi
# php config directory {{{
pushd /etc/php5
	if [ ! -d $CONFIG_DIR/phpconf.d ]; then
		cp -r conf.d $CONFIG_DIR/phpconf.d
	fi
	pushd cli
		$SUDO rm conf.d
		$SUDO ln -s $CONFIG_DIR/phpconf.d conf.d
	popd
	pushd apache2
		$SUDO rm conf.d
		$SUDO ln -s $CONFIG_DIR/phpconf.d conf.d
	popd
# }}}
# apache config directory {{{
pushd /etc/apache2
	if [ ! -d $CONFIG_DIR/apache2.d ]; then
		cp -r sites-enabled $CONFIG_DIR/apache2.d
	fi
	if [ ! -h post-load ]; then
		ln -s 
		$SUDO ln -s $CONFIG_DIR/apache2.d post-load
	fi
	if [ ! -f apache2.conf.orig ]; then
		$SUDO mv apache2.conf apache2.conf.orig
		$SUDO cat apache2.conf.orig | sed "s|sites-enabled|post-load|" | $SUDO tee apache2.conf
	fi
# }}}
# }}}

if [ "$PACKAGES_INSTALLED" ]; then
	echo '### You may need to add stuff to your $PHP_INI (or /etc/php.d/) and restart'
	echo "###  $PACKAGES_INSTALLED"
fi
$SUDO service apache2 graceful
exit



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
	# Needed to unzip YUI packages
	# Needed to execute YUI compressor
	if [ `check_dpkg default-jre` ]; then
		$SUDO apt-get install default-jre
	fi
	echo "### REMEMBER! On ubuntu, there are two different directories for CLI PHP and APACHE2 PHP configuration. Both must be updated for this script to work properly"
fi
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
