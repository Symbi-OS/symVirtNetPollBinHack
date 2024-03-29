#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>

#include "LINF/sym_all.h"

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
  long rc;
  int  ec=0;
  if (argc != 3) {
    usage(argc, argv);
    exit(-1);
  }
  
  uint64_t addr = strtoull(argv[1],NULL,16);
  int len = atoi(argv[2]);

  char* buff = malloc(len);

  sym_touch_stack();
  sym_touch_every_page_text();
  rc = sym_elevate();

  memcpy(buff, (void *)addr, len);
  /* if (rc<0) {     */
  /*   fprintf(stderr, "ERROR: failed to sym_elevate: rc=%ld\n", rc); */
  /*   exit(-1); */
  /* } */
  
  rc = write(STDOUT_FILENO, (void *)buff, len);
  if (rc != len) {
    fprintf(stderr, "WARNING: failed to read %d : rc=%ld\n",len, rc);
    ec = -1;
  }
  
  rc = sym_lower();
  
  /* if (rc<0) {     */
  /*   fprintf(stderr, "ERROR: failed to sym_lower: rc=%ld\n", rc); */
  /*   ec = -1; */
  /* } */
  
  return ec;
}
