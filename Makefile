all: clean chroot

chroot:chroot.c
	gcc -o $@ $<

clean:
	rm -f chroot
