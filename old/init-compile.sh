#!/bin/sh
bindir=`dirname $0`
rootdir=$1
uid=$SUDO_UID
umask 002
[ -n "${rootdir}" ] || rootdir=.
[ -f ${rootdir}/etc/centos-release -o -f ${rootdir}/etc/redhat-release ] || exit 1

${bindir}/yum ${rootdir} install `grep -v '^#' ${bindir}/compile.lst`
chroot ${rootdir} /usr/sbin/useradd -g 0 -u $uid compile
sed -E -i -e '/^umask |EDITOR=|LANG=/d' -e '$aumask 002\nexport EDITOR=vim\nexport LANG=en_US.UTF-8\n' ${rootdir}/home/*/.bashrc
