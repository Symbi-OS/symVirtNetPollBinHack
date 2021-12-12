VERSION=linux-5.14
TGZ=${VERSION}.tar.gz
KSRCURL=https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/${TGZ}
VERSION_INSTALLED=.${VERSION}_installed
ARCH=x86

LINE=1545
FILE=virtio_net.c
VMLINUX=${VERSION}/vmlinux

SYMBI_DIR=Symbi-OS
SYMBI_PGFLT_REPO=git@github.com:Symbi-OS/Apps.git
SYMBI_PGFLT_DIR=${SYMBI_DIR}/Apps
SYMBI_PGFLT_HEADER=${SYMBI_PGFLT_DIR}/include/headers/sym_lib_page_fault.h
SYMBI_PGFLT_LIB=${SYMBI_DIR}/Apps/include/libsym.a

.PHONEY: clean dist-clean all download extract config prepare vmlinux

all: old.dump new.dump writebytes

writebytes: writebytes.c ${SYMBI_PGFLT_HEADER} ${SYMBI_PGFLT_LIB}
	cc -o $@ $< ${SYMBI_PGFLT_LIB}

${SYMBI_PGFLT_LIB}: ${SYMBI_PGFLT_HEADER}
	make -C ${SYMBI_DIR}/Apps/include

${SYMBI_PGFLT_HEADER}:
	cd Symbi-OS && git clone git@github.com:Symbi-OS/Apps.git

new.o: new.S
	gcc -c new.S -o new.o

new.opcodes: new.o
	./bin/getOpcodes $< 0: > $@

new.xxd: new.opcodes
	cut -f 2 $< > $@

new.bin: new.xxd
	xxd -ps -r $< > $@

new.dump: new.bin old.addr
	ndisasm -o 0x$(shell cat old.addr) -b 64 -p intel $< > $@

old.addr: 
	./bin/getLineAddr ${VMLINUX} ${FILE} ${LINE} > $@

old.opcodes: old.addr
	./bin/getOpcodes ${VMLINUX} $(shell cat old.addr) > $@

old.xxd: old.opcodes
	cut -f 2 $< > $@

old.bin: old.xxd
	xxd -ps -r $< > $@

old.dump: old.bin old.addr
	ndisasm -o 0x$(shell cat old.addr) -b 64 -p intel $< > $@


${TGZ}:
	wget ${KSRCURL}
download: ${TGZ}

${VERSION_INSTALLED}: ${TGZ}
	tar -zxf ${TGZ}
	touch ${VERSION_INSTALLED}
extract: ${VERSION_INSTALLED}

${VERSION}/.config:  defconfig_virtio_khacking ${VERSION_INSTALLED}
	cp $< $@
	make -C ${VERSION} oldconfig
config: ${VERSION}/.config

${VERSION}/arch/${ARCH}/include/generated/asm/rwonce.h: config
	make -C ${VERSION} prepare
prepare: ${VERSION}/arch/${ARCH}/include/generated/asm/rwonce.h

${VERSION}/vmlinux: ${VERSION}/.config
	make -j4 -C ${VERSION} vmlinux
vmlinux: ${VERSION}/vmlinux

#$(VERSION}/include/arch/
clean:
	-rm -rf $(wildcard *.i *.o *.out *~ *.bin *.dump *.addr *.opcodes *.xxd)

dist-clean: clean
	-rm -rf $(wildcard ${VERSION_INSTALLED} ${VERSION} ${TGZ} ${SYMBI_PGFLT_DIR})
