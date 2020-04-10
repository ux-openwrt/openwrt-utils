#!/bin/sh

do_echo()
{
    local cmd=$1
    shift
    if [ "$cmd" = "sh" -a "x$1" = "x-c" ]; then
        shift
        printf '%s\n' "$*"
        sh -c "$@"
    else
        printf '%s %s\n' $cmd "$*"
        $cmd "$@"
    fi
}

do_build()
{
    echo make "$@"
    local d1=`date +%s`
    date '+%Y-%m-%d %H:%M:%S' --date=@$d1
    make "$@"
    local d2=`date +%s`
    date '+%Y-%m-%d %H:%M:%S' --date=@$d2
    local dt=$((d2 - d1))
    date -u '+%H:%M:%S' --date=@$dt
}

cmd_build()
{
    local logfile=build.log
    local opt destdir cfgfile foreground mirror proxy
    local user=compile
    local host=uxgood.org
    unset http_proxy https_proxy DOWNLOAD_MIRROR
    while [ -n "$1" ]
    do
        case "$1" in
            -c) cfgfile=$2;shift;shift;;
            -C) destdir=$2;shift;shift;;
            -f) foreground=1;shift;;
            -i) opt="$opt IGNORE_ERRORS=1";shift;;
            -m) export DOWNLOAD_MIRROR=$2;shift;shift;;
            -p) export http_proxy=$2 https_proxy=$2;shift;shift;;
            --) shift;break;;
            *) break;;
        esac
    done

    opt="CONFIG_KERNEL_BUILD_USER=$user $opt"
    opt="CONFIG_KERNEL_BUILD_DOMAIN=$host $opt"
    opt="BUILD_LOG=1 $opt"

    if [ -n "$destdir" ]; then
        [ -d "$destdir" ] || { echo "$destdir not exists!"; exit 1; }
        opt="$opt -C $destdir"
    else
        destdir=.
    fi

    if [ -n "$cfgfile" ]; then
        [ -e "$cfgfile" ] || { echo "$cfgfile not exists!"; exit 1; }
        [ -e "$destdir/.config" ] && do_echo sh -c "cd '$destdir'; mv -f .config .config.bak"
        do_echo cp -f "$cfgfile" "$destdir/.config"
    fi

    do_echo make $opt oldconfig 0</dev/null
    if [ -n "$foreground" ]; then
        do_build $opt "$@"
    else
        (exec 1>$destdir/$logfile;exec 2>&1;exec 0</dev/null;do_build $opt "$@") &
        do_echo tail --pid=$! -f $destdir/$logfile
    fi
}

cmd_mklink()
{
    local srcdir destdir
    [ $# -gt 2  ] && { echo 'too more options!'; exit 1; }
    [ $# -lt 1  ] && { echo 'too less options!'; exit 1; }
    [ $# -eq 2  ] && { srcdir=$1;destdir=$2; }
    [ $# -eq 1  ] && { srcdir=.;destdir=$1; }
    [ -d "$srcdir" ] || { echo "$srcdir not exists!"; exit 1; }
    [ -e "$destdir" ] && { echo "$destdir exists!";return; }
    destdir2=$(mkdir -p "$destdir";cd "$destdir";echo -n $PWD;cd - >/dev/null;rm -d "$destdir")
    do_echo sh -c "cd '$srcdir'; ./scripts/symlink-tree.sh '$destdir2/'"
    [ -d "$srcdir/feeds" ] && do_echo sh -c "cd '$srcdir'; ln -s \"\$PWD/feeds\" '$destdir2/'"
    [ -L "$destdir/.git" ] && do_echo rm -f "$destdir/.git"
}

cmd_checklog()
{
    local destdir=$1
    local logfile=$1
    [ -n "$destdir" ] || destdir=.
    if [ -d "$destdir" ]; then
        do_echo sh -c "grep -E '\*\*\* \[' -r $destdir/logs/ | awk -F: '{print \$1}' | uniq"
    else
        do_echo sh -c "grep -E '\*\*\* \[.*\/(compile|install)\]' $logfile | sed -E 's#.*\*\*\* \[(.*)\/(compile|install)\].*#\1#' | uniq"
    fi
}

cmd_menuconfig()
{
    local destdir cfgfile new diff opt
    while [ -n "$1" ]
    do
        case "$1" in
            -c) cfgfile=$2;shift;shift;;
            -C) destdir=$2;shift;shift;;
            -d) diff=1;shift;;
            -n) new=1;shift;;
            --) shift;break;;
            *) break;;
        esac
    done

    if [ -n "$destdir" ]; then
        [ -d "$destdir" ] || { echo "$destdir not exists!"; exit 1; }
        opt="$opt -C $destdir"
    else
        destdir=.
    fi

    if [ -n "$cfgfile" ]; then
        [ -e "$cfgfile" ] || { echo "$cfgfile not exists!"; exit 1; }
        [ -e "$destdir/.config" ] && do_echo sh -c "cd '$destdir'; mv -f .config .config.bak"
        do_echo cp -f "$cfgfile" "$destdir/.config"
    fi
    [ -n "$cfgfile" ] || { [ -n "$new" ] && do_echo rm -f $destdir/.config; }

    do_echo make $opt menuconfig "$@"
    do_echo make $opt oldconfig "$@" 0</dev/null
    if [ -n "$diff" ]; then
        do_echo sh -c "cd '$destdir'; ./scripts/diffconfig.sh > .config.new"
    else
        do_echo sh -c "cd '$destdir'; cp -f .config .config.new"
    fi
}

cmd_oldconfig()
{
    local destdir cfgfile diff opt
    while [ -n "$1" ]
    do
        case "$1" in
            -c) cfgfile=$2;shift;shift;;
            -C) destdir=$2;shift;shift;;
            -d) diff=1;shift;;
            --) shift;break;;
            *) break;;
        esac
    done

    if [ -n "$destdir" ]; then
        [ -d "$destdir" ] || { echo "$destdir not exists!"; exit 1; }
        opt="$opt -C $destdir"
    else
        destdir=.
    fi

    if [ -n "$cfgfile" ]; then
        [ -e "$cfgfile" ] || { echo "$cfgfile not exists!"; exit 1; }
        [ -e "$destdir/.config" ] && do_echo sh -c "cd '$destdir'; mv -f .config .config.bak"
        do_echo cp -f "$cfgfile" "$destdir/.config"
    fi

    do_echo make $opt oldconfig "$@" 0</dev/null
    if [ -n "$diff" ]; then
        do_echo sh -c "cd '$destdir'; ./scripts/diffconfig.sh > .config.new"
    else
        do_echo sh -c "cd '$destdir'; cp -f .config .config.new"
    fi
}

cmd_tail()
{
    local opt
    local logfile=$1
    [ -n "$logfile" ] || { echo 'no logfile!'; exit 1; }
    [ -f "$logfile" ] || { echo "$logfile is not a file!"; exit 2; }
    local pid="$(fuser "$logfile" 2>/dev/null)"
    if [ -n "$pid" ]; then
        pid="$(ps -h -opid,comm $pid | grep $progname | cut -d\  -f1)"
        [ -n "$pid" ] && opt="-f --pid=$pid"
    fi
    do_echo tail $opt $logfile
}

set -e

progname=$(basename $0)
func=cmd_$1
type $func >/dev/null 2>&1 || { echo utils $1 is not exists.; exit 2; }

shift
$func "$@"
