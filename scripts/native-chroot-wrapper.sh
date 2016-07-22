#!/bin/sh

# This script assumes it is copied in the staging or final dir
# Folders bin, usr/bin, lib, /usr/lib are subdirectories there

# Get full path to this script
SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)
SYSROOT=${SCRIPT_PATH}

# sanity check
if [ "${SYSROOT}" = "" -o ${SYSROOT} = "/" ]; then
	echo "Bad SYSROOT"
	exit 1
fi

# List of directory to mount as a binding with host
readonly MOUNT_POINTS="proc dev dev/pts"
readonly UMOUNT_POINTS="dev/pts dev proc"

# Help ?
if [ "$1" = "--help" ]; then
	echo "usage: $0 [--root] prog..."
	echo "       $0 [--help|--mount|--umount]"
	echo "  --root  : switch to root user"
	echo "  --help  : display this help message"
	echo "  --mount : mount proc, dev and dev/pts as a binding with host"
	echo "  --umount: un-mount proc, dev and dev/pts"
	echo "  prog... : program to execute (default: /bin/sh)"
	exit 0
fi

# Need to be root ?
OPT_ROOT=0
if [ "$1" = "--root" ]; then
	OPT_ROOT=1
	shift
fi

# Program to execute
OPT_PROG="/bin/sh -l"
if [ "$#" != "0" ]; then
	OPT_PROG="$@"
fi

# Check if a directory is actually mounted as a binding with host
# $1: directory to check
is_mounted()
{
	mount | grep "on ${SYSROOT}/$1 type" > /dev/null
	return $?
}

# Mount a directory as a binding with host
# $1: directory to mount
do_mount()
{
	echo "Mounting /$d as ${SYSROOT}/$1"
	mkdir -p ${SYSROOT}/$1
	sudo mount --bind /$1 ${SYSROOT}/$1
	return $?
}

# Un-mount a directory that was a binding with host
# $1: directory to un-mount
do_umount()
{
	sudo umount ${SYSROOT}/$1
	return $?
}

# Mount everything
if [ "$1" = "--mount" ]; then
	for d in ${MOUNT_POINTS}; do
		is_mounted $d
		if [ "$?" != "0" ]; then
			do_mount $d
		fi
	done
	exit
fi

# Un-mount everything
if [ "$1" = "--umount" ]; then
	for d in ${UMOUNT_POINTS}; do
		is_mounted $d
		if [ "$?" = "0" ]; then
			do_umount $d
		fi
	done
	exit
fi

# Check mount points
for d in ${MOUNT_POINTS}; do
	is_mounted $d
	if [ "$?" != "0" ]; then
		echo "$d is not mounted"
	fi
done

# Need to be root to chroot, but then go back to initial user
if [ "${OPT_ROOT}" = "0" ]; then
	sudo chroot --userspec=$(id -u):$(id -g) ${SYSROOT} ${OPT_PROG}
else
	sudo chroot ${SYSROOT} ${OPT_PROG}
fi
