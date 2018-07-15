#!/bin/sh

main()
{
    bootstrap_centos "$@"
}

bootstrap_utils()
{
:
}

bootstrap_centos()
{
    #export fakeroot=`which fakeroot`
    #export fakechroot=`which fakechroot`
    export yum=`which yum`
    local release=$1
    local basearch=$2
    local rootdir=$3
    local mirror=$4

    mkdir -p $rootdir
    rootdir=`cd $rootdir;pwd`
    make_yum_repo $release $basearch $rootdir
    call_yum $rootdir install bash
    make_device_nodes $rootdir
    clean_yum_cache $rootdir
}

bootstrap_debian()
{
:
}

call_yum()
{
    local rootdir=$1; shift
    if [ -f "$rootdir/bootstrap.repo" ]; then
        #mkdir -p "$rootdir/var/cache/yum/bootstrap/packages"
        $yum -y -c "$rootdir/bootstrap.repo" \
            --disablerepo=* --enablerepo=bootstrap \
            --noplugins --nogpgcheck \
            --installroot="$rootdir" \
            "$@"
    else
        $yum -y --noplugins --nogpgcheck \
            --installroot="$rootdir" \
            "$@"
    fi
}

make_yum_repo()
{
    local release=$1
    local basearch=$2
    local rootdir=$3
    local infra=stock
    local baserelease=${release%%.*}
    cat > "$rootdir/bootstrap.repo" <<__EOF__
[bootstrap]
name=bootstrap
failovermethod=priority
enabled=1
gpgcheck=0
__EOF__
    if [ -n "$mirror" ]; then
        echo "baseurl=$mirror/$release/os/$basearch/" >> "$rootdir/bootstrap.repo"
    elif [ "$release" != "$baserelease" ]; then
        mirror=http://vault.centos.org
        [ "$baserelease" == "7" -a "$basearch" != "x86_64" ] && mirror=$mirror/altarch/
        echo "baseurl=$mirror/$release/os/$basearch/" >> "$rootdir/bootstrap.repo"
    else
        echo "mirrorlist=http://mirrorlist.centos.org/?release=$baserelease&arch=$basearch&repo=os&infra=$infra" >> "$rootdir/bootstrap.repo"
    fi
}

make_device_nodes()
{
    local rootdir=$1
    mkdir -p ${rootdir}/dev/{mapper,shm,pts,net}
    #mkdir -p ${rootdir}/{etc,opt,work}
    #touch ${rootdir}/etc/{fstab,resolv.conf}

    mknod -m666 ${rootdir}/dev/null    c 1 3 
    mknod -m666 ${rootdir}/dev/zero    c 1 5 
    mknod -m666 ${rootdir}/dev/full    c 1 7 
    mknod -m666 ${rootdir}/dev/random  c 1 8 
    mknod -m666 ${rootdir}/dev/urandom c 1 9 
    mknod -m666 ${rootdir}/dev/tty     c 5 0 
    mknod -m600 ${rootdir}/dev/console c 5 1 
	mknod -m666 ${rootdir}/dev/ptmx    c 5 2

    mknod -m660 ${rootdir}/dev/loop0   b 7 0 
    mknod -m660 ${rootdir}/dev/loop1   b 7 1 
    mknod -m660 ${rootdir}/dev/loop2   b 7 2 
    mknod -m660 ${rootdir}/dev/loop3   b 7 3 
    mknod -m660 ${rootdir}/dev/loop4   b 7 4 
    mknod -m660 ${rootdir}/dev/loop5   b 7 5 
    mknod -m660 ${rootdir}/dev/loop6   b 7 6 
    mknod -m660 ${rootdir}/dev/loop7   b 7 7 

    mknod -m660 ${rootdir}/dev/rtc0    c 253 0

    mknod -m660 ${rootdir}/dev/mapper/control c 10 58

    mknod -m666 ${rootdir}/dev/net/tun        c 10 200 

    ln -s rtc0 ${rootdir}/dev/rtc

    ln -s /proc/self/fd ${rootdir}/dev/fd
    ln -s /proc/self/fd/2 ${rootdir}/dev/stderr
    ln -s /proc/self/fd/1 ${rootdir}/dev/stdout
    ln -s /proc/self/fd/0 ${rootdir}/dev/stdin
}

clean_yum_cache()
{
    local rootdir=$1
    rm -f "${rootdir}/bootstrap.repo"
    rm -rf "${rootdir}/var/lib/yum/repos"
    rm -rf "${rootdir}/var/lib/yum/rpmdb-indexes"
    find "${rootdir}/var/lib/rpm/" -name "__db.*" -delete
    find "${rootdir}/var/lib/yum/yumdb" -type f -delete
    find "${rootdir}/var/lib/yum/history" -type f -delete
    find "${rootdir}/var/cache/yum"  -type f -delete
}

clean_apt_cache()
{
:
}

export -f call_yum
export -f make_device_nodes
main "$@"
