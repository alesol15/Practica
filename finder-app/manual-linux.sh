#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo

set -e
set -u

# Variables
OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

#Optional Argument
if [ $# -lt 1 ]
then
    echo "Defect Directory ${OUTDIR}"
else
    OUTDIR=$1
    echo "Especific Directory: ${OUTDIR}"
fi

# Create Directory 
mkdir -p ${OUTDIR}
cd "$OUTDIR"

# ----------- Clone and compile Kernel ----------------

if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "Cloning Linux ${KERNEL_VERSION} en ${OUTDIR}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Compiling Kernel..."
    git checkout ${KERNEL_VERSION}
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

    #Fix possible mistakes
    export FLEX=flex
    export YACC=bison
    export LEX=flex
    export KBUILD_BUILD_VERSION=1

    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
fi

echo "Copy image of kernel"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

# ----------- Create rootfs ----------------

echo "Preparing rootfs..."
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]; then
    echo "Delete rootfs"
    sudo rm -rf ${OUTDIR}/rootfs
fi

mkdir -p rootfs/{bin,sbin,etc,proc,sys,usr/{bin,sbin},lib,lib64,dev,home}

# ----------- Cloning and compile BusyBox ----------------

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]; then
    echo "Cloning BusyBox..."
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    make distclean
    make defconfig
else
    cd busybox
fi

echo "Compile and install BusyBox..."
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

# ----------- Copy necessary libraries ----------------

echo "Copy necessary libraries..."
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

cp -a $SYSROOT/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib || true
cp -a $SYSROOT/lib64/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib64 || true
cp -a $SYSROOT/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64
cp -a $SYSROOT/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64
cp -a $SYSROOT/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64

# ----------- Crear nodos de dispositivo ----------------

echo "Creando nodos de dispositivo..."
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

# ----------- Copiar programas de usuario ----------------

echo "Copiando aplicaciones de usuario..."
cp ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/ || echo "No se encontró writer"
cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/ || echo "No se encontró finder.sh"
cp ${FINDER_APP_DIR}/conf/username.txt ${OUTDIR}/rootfs/home/ || echo "No se encontró username.txt"

# ----------- Create initramfs (cpio.gz) ----------------

echo "Packing initramfs..."
cd ${OUTDIR}/rootfs
sudo chown -R root:root *
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
cd ${OUTDIR}
gzip -f initramfs.cpio

echo "Kernel, rootfs y initramfs READY."
