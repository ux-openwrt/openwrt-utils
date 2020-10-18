#!/bin/sh

bindir=$(dirname $0)

vendor=centos
releasever=7
basearch=$(uname -m)
#vendor=fedora
#releasever=30
destdir=
mirror=
baseurl=
mirrorlist=

main()
{
    while getopts ':alb:c:d:m:r:v:' opt
    do
        case "$opt" in
            a) archive=1;;
            b) basearch=$OPTARG;;
            d) destdir=$OPTARG;;
            l) mirrorlist=1;;
            m) mirror=$OPTARG;;
            r) releasever=$OPTARG;;
            v) vendor=$OPTARG;;
            ?) echo "unknown option -$OPTARG";exit 1;;
            *) echo "unknown option $opt";exit 1;;
        esac
    done

    shift $((OPTIND-1))
    [ -n "$destdir" ] || destdir=$vendor-$releasever-$basearch
    
    bootstrap_repo

    echo "vendor: $vendor"
    echo "releasever: $releasever"
    echo "basearch: $basearch"
    echo "destdir: $destdir"
    echo "baseurl: $baseurl"
    echo "mirrorlist: $mirrorlist"

    bootstrap_setup "$@"
}

bootstrap_repo()
{
    local release=${releasever%%.*}
    [ -n "$archive" -a -n "$mirrorlist" ] && { echo "unset mirrorlist!"; unset mirrorlist; }
    [ -n "$archive" -a -n "$mirror" ] && { echo "unset mirror!"; unset mirror; }
    [ -n "$mirrorlist" -a -n "$mirror" ] && { echo "unset mirror!"; unset mirror; }
    
    case "$vendor" in
        centos)
            [ -n "$archive" ] && mirror="http://vault.centos.org"
            if [ -n "$mirror" ]; then
                if [ "$release" -ge "7" -a "$basearch" != "x86_64" -a -n "$archive" ]; then
                    mirror="$mirror/altarch"
                fi
                if [ "$release" -ge 8 ]; then
                    baseurl="$mirror/$releasever/BaseOS/$basearch/os/"
                else
                    baseurl="$mirror/$releasever/os/$basearch/"
                fi
            else
                if [ "$release" -ge 8 ]; then
                    mirrorlist="http://mirrorlist.centos.org/?release=$release&arch=$basearch&repo=BaseOS&infra=stock"
                else
                    mirrorlist="http://mirrorlist.centos.org/?release=$release&arch=$basearch&repo=os&infra=stock"
                fi
            fi
            ;;
        fedora)
            [ -n "$archive" ] && mirror="https://archives.fedoraproject.org/pub/archive/fedora"
            if [ -n "$mirror" ]; then
                baseurl="$mirror/linux/releases/$releasever/Everything/$basearch/os/"
            else
                mirrorlist="https://mirrors.fedoraproject.org/metalink?repo=$vendor-$releasever&arch=$basearch"
            fi
            ;;
        *) echo "vendor $vendor is not support";exit 1;;
    esac
}

bootstrap_setup()
{
    yum=$(which yum)

    if [ ! -e "$destdir" ]; then
        mkdir -p "$destdir"
        chown ${SUDO_UID:-$(id -u)}:${SUDO_GID:-$(id -g)} "$destdir"
    fi
    destdir=$(cd "$destdir"; pwd)
    make_repo 
    call_yum install bash $vendor-release "$@"
    #call_yum search $vendor-release
    make_nodes
    init_login
    #clean_cache
}

call_yum()
{
    if [ -f "$destdir/bootstrap.repo" ]; then
        mkdir -p "$destdir/var/cache/yum/bootstrap/packages"
        $yum -c "$destdir/bootstrap.repo" --disablerepo=* --enablerepo=bootstrap \
            --noplugins --nogpgcheck --forcearch=$basearch --releasever=$releasever \
            --installroot="$destdir" \
            "$@"
    else
        $yum --noplugins --nogpgcheck --forcearch=$basearch --releasever=$releasever \
            --installroot="$destdir" \
            "$@"
    fi
}

make_repo()
{
    cat > "$destdir/bootstrap.repo" <<__EOF__
[bootstrap]
name=bootstrap
failovermethod=priority
enabled=1
gpgcheck=0
${mirrorlist:+#}baseurl=$baseurl
${baseurl:+#}mirrorlist=$mirrorlist
__EOF__
}

make_nodes()
{
    mkdir -p ${destdir}/dev/{mapper,shm,pts,net}

    mknod -m666 ${destdir}/dev/null    c 1 3 
    mknod -m666 ${destdir}/dev/zero    c 1 5 
    mknod -m666 ${destdir}/dev/full    c 1 7 
    mknod -m666 ${destdir}/dev/random  c 1 8 
    mknod -m666 ${destdir}/dev/urandom c 1 9 
    mknod -m666 ${destdir}/dev/tty     c 5 0 
    mknod -m600 ${destdir}/dev/console c 5 1 
    mknod -m666 ${destdir}/dev/ptmx    c 5 2

    mknod -m660 ${destdir}/dev/loop0   b 7 0 
    mknod -m660 ${destdir}/dev/loop1   b 7 1 
    mknod -m660 ${destdir}/dev/loop2   b 7 2 
    mknod -m660 ${destdir}/dev/loop3   b 7 3 
    mknod -m660 ${destdir}/dev/loop4   b 7 4 
    mknod -m660 ${destdir}/dev/loop5   b 7 5 
    mknod -m660 ${destdir}/dev/loop6   b 7 6 
    mknod -m660 ${destdir}/dev/loop7   b 7 7 

    mknod -m660 ${destdir}/dev/rtc0    c 253 0

    mknod -m660 ${destdir}/dev/mapper/control c 10 58

    mknod -m666 ${destdir}/dev/net/tun        c 10 200 

    ln -s rtc0 ${destdir}/dev/rtc

    ln -s /proc/self/fd ${destdir}/dev/fd
    ln -s /proc/self/fd/2 ${destdir}/dev/stderr
    ln -s /proc/self/fd/1 ${destdir}/dev/stdout
    ln -s /proc/self/fd/0 ${destdir}/dev/stdin
}

init_login()
{
    cat > "$destdir/login.sh" <<__EOF__
#!/bin/sh
if [ "\$UID" == "" ]; then
    UID=\$(/usr/bin/id -u)
fi
GID=\$(/usr/bin/id -g)
USER="\$(/usr/bin/id -un)"
LOGNAME=\$USER
HOME=\$(grep "^\$USER:[^:]:\$UID:\$GID:" /etc/passwd | cut -d: -f6)
SHELL=\$(grep "^\$USER:[^:]:\$UID:\$GID:" /etc/passwd | cut -d: -f7)
if [ "\$TERM" == "dumb" ]; then
    TERM=xterm
fi
if [ "\$LANG" == "" ]; then
    LANG=en_US.UTF-8
fi
export UID GID USER LOGNAME HOME SHELL TERM LANG
unset SUDO_UID SUDO_GID SUDO_USER SUDO_COMMAND 
cd ~
if [ "\$SHELL" == "/bin/bash" ]; then
    if [ "\$#" == 0 ]; then
        exec \$SHELL --login -i
    else
        exec \$SHELL --login "\$@"
    fi
else
    exec \$SHELL
fi
__EOF__
    cat > "$destdir/chroot.sh" <<__EOF__
#!/bin/sh
rootdir=\$(dirname \$0)
uid=\${uid:-\${SUDO_UID:-0}}
exec chroot --userspec=\$uid \$rootdir /bin/env -i TERM=$TERM /login.sh "\$@"
__EOF__
    chmod +x "$destdir/login.sh"
    chown --reference="$destdir" "$destdir/login.sh"
    chmod +x "$destdir/chroot.sh"
    chown --reference="$destdir" "$destdir/chroot.sh"

}

clean_cache()
{
    rm -f "${destdir}/bootstrap.repo"
    rm -rf "${destdir}/var/lib/yum/repos"
    rm -rf "${destdir}/var/lib/yum/rpmdb-indexes"
    find "${destdir}/var/lib/rpm/" -name "__db.*" -delete
    find "${destdir}/var/lib/yum/yumdb" -type f -delete
    find "${destdir}/var/lib/yum/history" -type f -delete
    find "${destdir}/var/cache/yum"  -type f -delete
}

main "$@"
