#!/bin/sh
bindir=`dirname $0`
rootdir=$1
destdir=${2:-'~/.vim'}
destdir2=`eval echo -n $destdir`

umask 002

[ -f ${rootdir}/etc/os-release ] || { echo "no os-release found in ${rootdir}/etc"; exit 1; }
which git >/dev/null 2>&1 || { echo "no git found!"; exit 1; }

echo "destdir=$destdir"
echo "source $destdir/vimrc" >~/.vimrc

mkdir -p $destdir2/bundles
mkdir -p $destdir2/templates
cp -f ${bindir}/vimrc $destdir2/
cp -f ${bindir}/personal.templates $destdir2/templates/personal.templates
sed -ir "s@\(let s:rtpath=\).*@\1'$destdir/bundles'@" $destdir2/vimrc

[ -d $destdir2/bundles/Vundle.vim ] && ( cd $destdir2/bundles/Vundle.vim; git pull )
[ -d $destdir2/bundles/Vundle.vim ] || git clone https://github.com/VundleVim/Vundle.vim $destdir2/bundles/Vundle.vim

vim -c:PluginInstall
