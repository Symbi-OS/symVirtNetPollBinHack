#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

void usage(int argc, char **argv)
{
  fprintf(stderr, "%s: <addr>\n"
	  "      read bytes from stdin and writes them to <addr>\n",
	  argv[0]);
}

void *
getPageVPN(void *addr)
{
  return NULL;
}

uint64_t
getPagePermissions(void *VPN)
{
  return 0;
}

uint64_t
setPagePermissions(void *VPN, uint64_t perms)
{
  return 0;
}

bool
isPageWriteAble(uint64_t perms)
{
  return true;
}

bool
isPageReadAble(uint64_t perms)
{
  return true;
}

uint64_t
setPageWriteAble(uint64_t perms)
{
  return 0;
}

uint64_t
setPageReadAble(uint64_t perms)
{
  return 0;
}

void
fixPagePerms(void *vpn, uint64_t *origPagePerms, uint64_t *newPagePerms)
{
  uint64_t operms, nperms;
  
  operms = getPagePermissions(vpn);
  if (!isPageWriteAble(operms)) {
      nperms = setPageWriteAble(operms);
      setPagePermissions(vpn, nperms);
  } else { // no need to update
    nperms = operms;
  }
  
  *origPagePerms = operms;
  *newPagePerms = nperms;
}

void
restorePagePerms(void *vpn, uint64_t origPagePerms, uint64_t newPagePerms)
{
  if (origPagePerms != newPagePerms) {
    setPagePermissions(vpn, origPagePerms);
  }
}

int
main(int argc, char **argv)
{
  char c;
  int optind;
  bool vflag = false;
  void *curVPN=NULL, *tmpVPN=NULL;
  uint64_t origPagePerms, newPagePerms;
  
  while ((c = getopt (argc, argv, "v")) != -1) {
    switch (c) {
    case 'v':
      vflag = true;
      break;
    default:
      usage(argc, argv);
      exit(-1);
    }
  }
  if (optind != (argc-1)) {
    exit(-1);
  }
  
  char *addr = (void *) strtoll(argv[1],NULL,16);
  
  while ((c=getchar())!=EOF) {
    tmpVPN = getPageVPN(addr);
    if (tmpVPN != curVPN) {
      // crossed a page boundary or first page
      // restore permissions on old page if needed
      if (curVPN!=NULL) restorePagePerms(curVPN, origPagePerms, newPagePerms);
      curVPN = tmpVPN; // update current page to new page
      // fix new page permissions if needed
      fixPagePerms(curVPN, &origPagePerms, &newPagePerms);
    }
    *addr = c;
    addr++;
  }
  // restore last page permissions if needed
  if (curVPN!=NULL) restorePagePerms(curVPN, origPagePerms, newPagePerms);
  return 0;
}

  
			     
