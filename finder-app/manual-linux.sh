#!/bin/bash
# Script outline to install and build kernel.
# Author original: Siddhant Jajoo. Adaptado por Alejandra.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}
cd "$OUTDIR"

# ----------- Clonar y Compilar el Kernel ----------------

if [ ! -d "${OUTDIR}/linux-stable" ]; then
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
	cd linux-stable
	echo "Checking out version ${KERNEL_VERSION}"
	git checkout ${KERNEL_VERSION}

	echo "Cleaning kernel build"
	make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper

	echo "Defconfig kernel"
	make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

	echo "Building kernel"
	# Evitar error con DTC: declarar explícitamente herramientas léxicas
	export FLEX=flex
	export YACC=bison
	export LEX=flex
	export KBUILD_BUILD_VERSION=1

	make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
fi

echo "Adding the Image in outdir"

# ------------- Preparar rootfs --------------------

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]; then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
	sudo rm -rf ${OUTDIR}/rootfs
fi

mkdir -p rootfs/{bin,sbin,etc,proc,sys,usr/{bin,sbin},lib,lib64,dev,home}

# ------------- Clonar y Compilar BusyBox ----------------

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]; then
	echo "Cloning BusyBox"
	git clone git://busybox.net/busybox.git
	cd busybox
	git checkout ${BUSYBOX_VERSION}

	echo "Configuring BusyBox"
	make distclean
	make defconfig
else
	cd busybox
fi

echo "Building and installing BusyBox"
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

# ------------- Ver dependencias de librerías ----------------

echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library"

# ------------- Aquí podrías agregar: copiar librerías, writer, scripts, nodos ----------------
# Ejemplo de nodos:
# sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
# sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

# ------------- Final ----------------

echo "Kernel and BusyBox setup completed!"
