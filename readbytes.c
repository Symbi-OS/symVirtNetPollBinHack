#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include "Symbi-OS/Apps/include/headers/sym_lib.h"

void
usage(int argc, char **argv)
{
  fprintf(stderr,
	  "USAGE: %s <addr> <len>\n"
	  "  copies <len> bytes from <addr> to standard out\n",
	  argv[0]);
}

int
main(int argc, char **argv)
{
  if (argc != 3) {
    usage(argc, argv);
    exit(-1);
  }
  
  uint64_t addr = strtoll(argv[1],NULL,16);
  int len = atoi(argv[2]);

  sym_elevate();
  write(STDOUT_FILENO, (void *)addr, len);
  sym_lower();
  
  return 0;
}
