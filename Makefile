VERSION=linux-5.14
TGZ=${VERSION}.tar.gz
KSRCURL=https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/${TGZ}
VERSION_INSTALLED=.${VERSION}_installed
ARCH=x86

LINE=1545
FILE=virtio_net.c
VMLINUX=${VERSION}/vmlinux

.PHONEY: clean dist-clean all download extract config prepare vmlinux

all: old.dump new.dump 

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
	-rm -rf $(wildcard ${VERSION_INSTALLED} ${VERSION} ${TGZ} )
