#!/bin/sh
bindir=`dirname $0`
rootdir=$1
destdir=${2:-~/.vim}
umask 002
[ -f ${rootdir}/etc/centos-release ] || exit 1
[ -d $destdir/bundles/Vundle.vim ] && exit 1 
echo "destdir=$destdir"
echo "source $destdir/vimrc" >~/.vimrc
mkdir -p $destdir/bundles
cp -f ${bindir}/vimrc $destdir/ 
sed -i "s@let s:rtpath=.*@let s:rtpath='$destdir/bundles'@" $destdir/vimrc
git clone https://github.com/VundleVim/Vundle.vim $destdir/bundles/Vundle.vim
vim -c:PluginInstall
