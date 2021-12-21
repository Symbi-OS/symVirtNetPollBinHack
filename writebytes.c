#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#include "Symbi-OS/Apps/include/headers/sym_lib.h"
#include "Symbi-OS/Apps/include/headers/sym_lib_hacks.h"
#include "Symbi-OS/Apps/include/headers/sym_lib_page_fault.h"


// when we add support for kernel source get this
// from arch/x86/include/asm/pgtable_types.h
enum pg_level {
	       PG_LEVEL_NONE,
	       PG_LEVEL_4K,
	       PG_LEVEL_2M,
	       PG_LEVEL_1G,
	       PG_LEVEL_512G,
	       PG_LEVEL_NUM
};

void usage(int argc, char **argv)
{
  fprintf(stderr, "%s: <addr>\n"
	  "      read bytes from stdin and writes them to <addr>\n",
	  argv[0]);
}

uint64_t
getVPNMask(unsigned int level)
{
  uint64_t mask = 0; 
  switch (level) {
  case PG_LEVEL_4K:
    mask = ~(((1ULL<<12)-1));
    break;
  case PG_LEVEL_2M:
    mask = ~(((1ULL<<20)-1));
    break;
  case PG_LEVEL_1G:
    mask =  ~(((1ULL<<29)-1));
    break;
  case PG_LEVEL_512G:
    mask =  ~(((1ULL<<38)-1));
    break;
  default:
    assert(0);
  }
  fprintf(stderr, "%s(%d) : %llx\n", __func__, level, mask);
  return mask;
}

void *
getPageDesc(uint64_t addr, unsigned int *level)
{
  //  returns a copy of the page descriptor
  void *rc = sym_get_pte(addr, level);
  fprintf(stderr, "%s(%llx) : %p pglvl: %d\n", __func__, addr, rc, *level);
  return  rc;
}


static inline bool
isPageWriteable(void *desc)
{
  struct pte * pte = desc;
  return sym_is_pte_writeable(*pte);
}

static inline void
setPageWriteable(void *desc)
{
  struct pte *pte = desc;
  sym_set_pte_writeable(pte);
}

static inline void
clearPageWriteable(void *desc)
{
  struct pte *pte = desc;
  sym_clear_pte_writeable(pte);
}

bool updateWriteIfNeeded(void *desc)
{
  bool curWritable;
  
  if (isPageWriteable(desc)) return false;
  setPageWriteable(desc);
  return true;
}

long sym_init(void)
{
  sym_touch_stack();
  sym_touch_every_page_text();
  return sym_elevate();
}

long sym_done(void)
{
  return  sym_lower();
}

int
main(int argc, char **argv)
{
  int c;
  int optind;
  bool vflag = false;
  bool pgupdated;
  void *pgdesc;
  unsigned int pglvl;
  uint64_t vpnmsk;
  uint64_t curvpn, tmpvpn;

#if 0
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
#endif
 uint64_t addr =  strtoull(argv[1],NULL,16);
 fprintf(stderr, "%s : %s addr=%llx\n", __func__, argv[1], addr);
 
 // symbiote initilization
#ifndef NOSYM
 sym_init();
#endif
 
  fprintf(stderr, "sys_init(): done\n");

#ifndef NOSYM  
  pgdesc = getPageDesc(addr, &pglvl);
  vpnmsk = getVPNMask(pglvl);
#else
  pgdesc = 0;
  vpnmsk = 0;
#endif
  
  curvpn = 0; // initlize
  
  while ((c=getchar())!=EOF) {
#ifndef NOSYM
    tmpvpn = addr & vpnmsk;
    if (tmpvpn != curvpn) {
      // crossed a page boundary or first page
      // restore permissions on old page if needed
      if (curvpn != 0 && pgupdated) clearPageWriteable(pgdesc);
      pgdesc = getPageDesc(addr, &pglvl);
      vpnmsk = getVPNMask(pglvl);
      curvpn = tmpvpn; 
      // fix new page permissions if needed
      pgupdated = updateWriteIfNeeded(pgdesc);
    }
#endif
    fprintf(stderr, "0x%llx <- 0x%02hhx\n", addr, c);
#ifndef NOSYM
    *((char *)addr) = c;
#endif
    addr++;
  }
  
  // restore last page permissions if needed
#ifndef NOSYM
  if (pgupdated) updateWriteIfNeeded(pgdesc);
  sym_done();
#endif 
  
  return 0;
}

  
			     
