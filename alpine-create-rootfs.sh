#!/bin/sh

#	alpine-create-rootfs
#
#	A script creates bootable (with openRC) rootfs

ARCH=$(uname -m)
DIRECT_MIRROR=
ROOT=
MINI_ROOTFS=
RELEASE=
MIRROR="https://dl-cdn.alpinelinux.org/alpine"

usage() {
	echo 'alpine-create-rootfs: creates an Alpine rootfs with openRC'
	echo 'usage:'
	echo 'alpine-create-rootfs [OPTIONS] <ROOT>'
	echo 'OPTIONS:'
	echo '	--arch		Specify architecture'
	echo '	--mirror	Specify apk mirror'
	echo '	--rootfs	Specify Alpine minimal rootfs'
	echo '	--release	Speicfy Alpine Linux release (e.g., 3.18)'
	echo '	--proxy		Set up HTTP(s) proxy'
	echo '	--direct-mirror	Connect to the mirror directly'
	echo '	--help		Print this usage'
}

summary() {
	echo "Create Alpine Linux rootfs:"
	echo "Architecture:	$ARCH"
	echo "Default rootfs:	${MINI_ROOTFS:-"Download"}"
	echo "Mirror:		$MIRROR"
	echo "Release:	$RELEASE"
	echo "Root Path:	$ROOT"
}

while ! [ $1x = x ]
do
	case $1 in
	--arch)
		ARCH=$2
		shift
		;;
	--mirror)
		MIRROR=$2
		shift
		;;
	--release)
		RELEASE=$2
		shift
		;;
	--rootfs)
		if [ -f $2 ]
		then
			echo Minimal rootfs $2 does not exist
			exit 1
		fi
		MINI_ROOTFS=$2
		shift
		;;
	--proxy)
		export http_proxy=$2
		export https_proxy=$2
		shift
		;;
	--direct-mirror)
		DIRECT_MIRROR=yes
		;;
	--help)
		usage
		exit 1
		;;
	*)
		if ! [ x$ROOT = x ]
		then
			usage
			exit 1
		fi
		ROOT=$1
		;;
	esac
	shift
done

if [ x$ROOT = x ]
then
	echo Please specify the path to root
	usage
	exit 1
fi

if [ x$RELEASE = x ]
then
	echo Please specify Alpine Linux release
	usage
	exit 1
fi

summary

if [ x$MINI_ROOTFS = x ]
then
	wget -P /tmp "https://dl-cdn.alpinelinux.org/alpine/v$RELEASE/releases/$ARCH/latest-releases.yaml"
	rootfsname=`grep -m 1 -o "alpine-minirootfs-$RELEASE.[0-9]-$ARCH.tar.gz" /tmp/latest-releases.yaml`
	MINI_ROOTFS="/tmp/$rootfsname"

	echo $rootfsname
	wget "https://dl-cdn.alpinelinux.org/alpine/v$RELEASE/releases/$ARCH/$rootfsname" \
		-P /tmp
fi

# Decompress minimal rootfs
echo Decompressing minimal rootfs
tar xzf $MINI_ROOTFS -C $ROOT

# Unset proxy-related environment variables if we want to connect to the mirror
# directly.

if ! [ x$DIRECT_MIRROR = x ]
then
	unset http_proxy
	unset https_proxy
fi

# Recreate /etc/apk/repositories
echo "Setting up mirror (/etc/apk/repositories)"
cat <<EOF >$ROOT/etc/apk/repositories
$MIRROR/v$RELEASE/main
EOF

# Complete Alpine base system
echo Installing Alpine base system
apk -p $ROOT --arch $ARCH update
apk -p $ROOT --arch $ARCH add alpine-base

# Enable essential services
echo Enabling essential serevices

add_services() {
	target=$1
	shift
	while ! [ x$1 = x ]
	do
		echo Enable $1 in runlevel $target
		ln -s /etc/init.d/$1 $ROOT/etc/runlevels/$target/
		shift
	done
}

add_services boot bootmisc hostname networking
add_services sysinit devfs mdev
add_services default acpid udev-postmount
add_services shutdown killprocs mount-ro savecache
