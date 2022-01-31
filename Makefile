VERSION=linux-5.14
TGZ=${VERSION}.tar.gz
KSRCURL=https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/${TGZ}
VERSION_INSTALLED=.${VERSION}_installed
ARCH=x86

LINE=1545
FILE=virtio_net.c
VMLINUX=${VERSION}/vmlinux

STATIC=-static

SYMBI_BASE_DIR=Symbi-OS

SYMBI_REPO=git@github.com:Symbi-OS/Apps.git
SYMBI_DIR=${SYMBI_BASE_DIR}/Apps
SYMBI_LIB_DIR=${SYMBI_DIR}/libs/symlib
SYMBI_HEADER_DIR=${SYMBI_LIB_DIR}/include
SYMBI_LIB=${SYMBI_LIB_DIR}/build/libsym.a
KALLSYM_LIB=${SYMBI_DIR}/libs/kallsymlib/libkallsym.a

.PHONEY: clean dist-clean all download extract config prepare vmlinux symbilib

all: old.dump new.dump symrd symwr 


symrd: readbytes.c ${SYMBI_LIB}
	gcc ${STATIC} ${DEBUG} -I${SYMBI_HEADER_DIR} -o $@ $< ${SYMBI_LIB}

symbilib: ${SYMBI_LIB}

${SYMBI_LIB_DIR}/Makefile:
	cd ${SYMBI_BASE_DIR} && git clone ${SYMBI_REPO}

${SYMBI_LIB}: ${SYMBI_LIB_DIR}/Makefile
	make -C ${SYMBI_LIB_DIR}

symwr: writebytes.c ${SYMBI_LIB}
	gcc ${STATIC} ${DEBUG} -I${SYMBI_HEADER_DIR} -o $@ $< ${SYMBI_LIB} ${KALLSYM_LIB}

nosymwr: writebytes.c ${SYMBI_PGFLT_HEADER} ${SYMBI_PGFLT_LIB}
	gcc -DNOSYM ${STATIC} ${DEBUG} -o $@ $< ${SYMBI_PGFLT_LIB}

#${SYMBI_PGFLT_HEADER}:
#	cd Symbi-OS && git clone ${SYMBI_PGFLT_REPO}
${SYMBI_PGFLT_LIB}: ${SYMBI_PGFLT_HEADER}
	make -C ${SYMBI_PGFLT_LIBDIR}

#new.o: new.S
#	gcc -c new.S -o new.o

#new.opcodes: new.o
#	./bin/getOpcodes $< 0: > $@

#new.xxd: new.opcodes
#	cut -f 2 $< > $@

new.bin: old.bin
	cat $< | VERBOSE=1 ./bin/rewriteJAtoJG > $@

new.dump: new.bin old.addr
	ndisasm -o 0x$(shell cat old.addr) -b 64 -p intel $< > $@

live.bin: symrd
	./symrd $(shell cat old.addr) 18 > $@

live.xxd: live.bin
	xxd  $< > $@

old.addr: 
	./bin/getLineAddr ${VMLINUX} ${FILE} ${LINE} > $@

old.opcodes: old.addr
	./bin/getOpcodes ${VMLINUX} $(shell cat old.addr) 2 > $@

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
	-rm -rf $(wildcard *.i *.o *.out *~ *.bin *.dump *.addr *.opcodes *.xxd symrd symrw)

dist-clean: clean
	-rm -rf $(wildcard ${VERSION_INSTALLED} ${VERSION} ${TGZ} ${SYMBI_PGFLT_DIR})
