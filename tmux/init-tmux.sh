#!/bin/sh
bindir=$(dirname $0)
rcfile=~/.bashrc
if [ -f $rcfile ]; then
    sed -i '/^PS1=/d' $rcfile
    echo "PS1='\[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >>$rcfile
fi
cp -f $bindir/tmux.conf ~/.tmux.conf
