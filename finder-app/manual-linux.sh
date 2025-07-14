#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo

set -e
set -u

# Variables
OUTDIR=${OUTDIR:-/tmp/aeld}
ARCH=arm64
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
CROSS_COMPILE=aarch64-linux-gnu-

#Optional Argument
OUTDIR="/tmp/aeld"

if [ $# -lt 1 ]
then
    echo "Defect Directory ${OUTDIR}"
else
    OUTDIR=$1
    echo "Especific Directory: ${OUTDIR}"
fi

OUTDIR=$(realpath "$OUTDIR")

echo "Using absolute directory: ${OUTDIR}"

# Create Directory 
mkdir -p "${OUTDIR}"
if [ $? -ne 0 ]; then
    echo "Error: Directoy no created ${OUTDIR}"
    exit 1
fi

# Change the directory
cd "${OUTDIR}"
if [ $? -ne 0 ]; then
    echo "Error: Directoy no changed ${OUTDIR}"
    exit 1
fi

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

if [ ! -f "${OUTDIR}/Image" ]; then
    echo "❌ Error: Kernel image is not found${OUTDIR}"
    exit 1
else
    echo "Kernel image OK ${OUTDIR}/Image"
fi

# ----------- Create rootfs ----------------

echo "Preparing rootfs..."

cd "${OUTDIR}"

# Remove existing rootfs if it exists
if [ -d "${OUTDIR}/rootfs" ]; then
    echo "Deleting existing rootfs"
    sudo rm -rf "${OUTDIR}/rootfs"
fi

# Create base directory structure
mkdir -p rootfs/{bin,sbin,etc,proc,sys,usr/{bin,sbin},lib,lib64,dev,home}

echo "Base rootfs structure created"

#Cross-compile writer using ARM toolchain

echo "Compiling writer.c for ARM architecture..."
WRITER_SRC="${FINDER_APP_DIR}/writer.c"
echo "DEBUG: WRITER_SRC = $WRITER_SRC"

${CROSS_COMPILE}gcc -o writer "$WRITER_SRC"

# Copy writer to rootfs
cp writer "${OUTDIR}/rootfs/home/"
echo "writer copied to rootfs/home"
rm writer

# 🔹 Copy scripts and config files from Assignment 2
cp "${FINDER_APP_DIR}/finder.sh" \
   "${FINDER_APP_DIR}/conf/username.txt" \
   "${FINDER_APP_DIR}/conf/assignment.txt" \
   "${FINDER_APP_DIR}/finder-test.sh" \
   "${FINDER_APP_DIR}/autorun-qemu.sh" \
   "${OUTDIR}/rootfs/home/"

echo "Scripts and configuration files copied to rootfs/home"

# 🔹 Update path to assignment.txt in finder-test.sh
sed -i 's|\.\./conf/assignment.txt|conf/assignment.txt|' "${OUTDIR}/rootfs/home/finder-test.sh"
echo "finder-test.sh updated to use conf/assignment.txt"

# 🔹 autorun-qemu.sh to home
cp "${FINDER_APP_DIR}/autorun-qemu.sh" "${OUTDIR}/rootfs/home/"
echo "autorun-qemu.sh copied"

# 🔹 Change ownership to root
cd "${OUTDIR}/rootfs"
echo "Adjusting file ownership..."
sudo chown -R root:root *

# 🔹 Create initramfs.cpio.gz
echo "Creating initramfs.cpio.gz..."
find . | cpio -H newc -ov --owner root:root | gzip > "${OUTDIR}/initramfs.cpio.gz"

echo "initramfs.cpio.gz generated at ${OUTDIR}"



# ----------- Cloning and compile BusyBox ----------------

cd "$OUTDIR"

if [ ! -d "${OUTDIR}/busybox" ]; then
    echo "Cloning BusyBox..."
    git clone https://github.com/mirror/busybox.git
    cd busybox
    git checkout 1_33_1
else
    cd busybox
fi

# Limpia configuraciones previas
make distclean

# Configuración por defecto
make defconfig

# Elimina la opción que activa tc para evitar errores de compilación
sed -i '/CONFIG_TC/d' .config

# Compila BusyBox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)

#Copy to rootfs
echo "Installing BusyBox to rootfs (requires sudo)..."
sudo make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX="${OUTDIR}/rootfs" install
echo "#!/bin/sh" > "${OUTDIR}/rootfs/init"
echo "/home/autorun-qemu.sh" >> "${OUTDIR}/rootfs/init"
chmod +x "${OUTDIR}/rootfs/init"

# ----------- Copy necessary libraries ----------------

echo "Copy necessary libraries..."
SYSROOT=/usr/aarch64-linux-gnu

sudo cp -a /usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib
sudo cp -a /usr/aarch64-linux-gnu/lib/libm.so.6 ${OUTDIR}/rootfs/lib64
sudo cp -a /usr/aarch64-linux-gnu/lib/libresolv.so.2 ${OUTDIR}/rootfs/lib64
sudo cp -a /usr/aarch64-linux-gnu/lib/libc.so.6 ${OUTDIR}/rootfs/lib64


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
