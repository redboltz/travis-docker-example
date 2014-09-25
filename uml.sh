#!/bin/bash

# Exit on first error
set -e


save_and_shutdown() {
  # save built for host result
  # force clean shutdown
  halt -f
}

# make sure we shut down cleanly
trap save_and_shutdown EXIT SIGINT SIGTERM

# go back to where we were invoked
cd $WORKDIR

# configure path to include /usr/local
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# can't do much without proc!
mount -t proc none /proc

# pseudo-terminal devices
mkdir -p /dev/pts
mount -t devpts none /dev/pts

# shared memory a good idea
mkdir -p /dev/shm
mount -t tmpfs none /dev/shm

# sysfs a good idea
mount -t sysfs none /sys

# pidfiles and such like
mkdir -p /var/run
mount -t tmpfs none /var/run

# takes the pain out of cgroups
cgroups-mount

# mount /var/lib/docker with a tmpfs
mount -t tmpfs none /var/lib/docker

# enable ipv4 forwarding for docker
echo 1 > /proc/sys/net/ipv4/ip_forward

# configure networking
ip addr add 127.0.0.1 dev lo
ip link set lo up
ip addr add 10.1.1.1/24 dev eth0
ip link set eth0 up
ip route add default via 10.1.1.254

# configure dns (google public)
mkdir -p /run/resolvconf
echo 'nameserver 8.8.8.8' > /run/resolvconf/resolv.conf
mount --bind /run/resolvconf/resolv.conf /etc/resolv.conf

# Start docker daemon
docker -d &
sleep 5

# Use docker
#WORKSPACE=/home/travis/build/redboltz/travis-docker-example
branch=poc/0.6
compiler=gcc

if [ -d work ]; then
    rm -rf work
fi
mkdir work

if [ "$compiler" = "gcc" ]; then
    cc="gcc"
    cxx="g++"
fi
if [ "$compiler" = "clang" ]; then
    cc="clang"
    cxx="clang++"
fi

/bin/echo -ne '#!/bin/sh\ngit clone https://github.com/redboltz/msgpack-c.git ' > $WORKDIR/work/do_docker.sh
/bin/echo -ne '&& cd msgpack-c && git checkout ' >> $WORKDIR/work/do_docker.sh
/bin/echo -ne $branch                            >> $WORKDIR/work/do_docker.sh
/bin/echo -ne ' && CC='                          >> $WORKDIR/work/do_docker.sh
/bin/echo -ne $cc                                >> $WORKDIR/work/do_docker.sh
/bin/echo -ne ' CXX='                            >> $WORKDIR/work/do_docker.sh
/bin/echo -ne $cxx                               >> $WORKDIR/work/do_docker.sh
/bin/echo -ne ' ci/build_'                       >> $WORKDIR/work/do_docker.sh
/bin/echo -ne $BUILD                             >> $WORKDIR/work/do_docker.sh
/bin/echo -ne '.sh '                             >> $WORKDIR/work/do_docker.sh
/bin/echo -ne $CPP_VERSION                       >> $WORKDIR/work/do_docker.sh
/bin/echo -ne '\n'                               >> $WORKDIR/work/do_docker.sh
/bin/echo -ne 'echo $? > /work/result\n'         >> $WORKDIR/work/do_docker.sh

cat $WORKDIR/work/do_docker.sh
docker pull redboltz/msgpack-test-$DISTRO:latest
docker run -v $WORKDIR/work:/work redboltz/msgpack-test-$DISTRO:latest /bin/sh -ex /work/do_docker.sh
cat $WORKDIR/work/result
#docker run ubuntu /bin/echo hello world
