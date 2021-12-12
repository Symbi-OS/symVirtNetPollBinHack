#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

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
  switch (level) {
  case PG_LEVEL_4K:
    return ~(((1ULL<<12)-1));
  case PG_LEVEL_2M:
    return ~(((1ULL<<20)-1));
  case PG_LEVEL_1G:
    return ~(((1ULL<<29)-1));
  case PG_LEVEL_512G:
    return ~(((1ULL<<38)-1));
  default:
    assert(0);
  }	    
  return 0;
}

void *
getPageDesc(uint64_t addr, unsigned int *level)
{
  //  returns a copy of the page descriptor
  return  sym_get_pte(addr, level);
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

int
main(int argc, char **argv)
{
  char c;
  int optind;
  bool vflag = false;
  bool pgupdated;
  void *pgdesc;
  unsigned int pglvl;
  uint64_t vpnmsk;
  uint64_t curvpn, tmpvpn;
  
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
  
  uint64_t addr =  strtoll(argv[1],NULL,16);
  pgdesc = getPageDesc(addr, &pglvl);
  vpnmsk = getVPNMask(pglvl);
  curvpn = 0; // initlize
  
  while ((c=getchar())!=EOF) {
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
    *((char *)addr) = c;
    addr++;
  }
  // restore last page permissions if needed
  if (pgupdated) updateWriteIfNeeded(pgdesc);
  return 0;
}

  
			     
