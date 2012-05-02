#!/usr/bin/env php
<?php
// vim:set tabstop=4 shiftwidth=4 softtabstop=4 foldmethod=marker syntax=php:
//345678901234567890123456789012345678901234567890123456789012345678901234567890
/**
 * Returns 1 if a php extension specified as $1 in installed.
 *
 * @package wm-ubuntu-dev
 * @subpackage bootstrap
 * @copyright 2012 terry chay <tychay@php.net>
 * @license GNU General Public License <http://www.gnu.org/licenses/gpl.html>
 * @author terry chay <tchay@wikimedia.org>
 */
echo extension_loaded($_SERVER['argv'][1]);
?>

