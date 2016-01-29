/*
 *  pipe_print.c - Print instructions as they pass through the verisimple
 *                 pipeline.  Must compile with the '+vc' vcs flag.
 *
 *  Doug MacKay <dmackay@umich.edu> Fall 2003
 */

#include <stdio.h>
#include "DirectC.h"

#define NOOP_INST 0x47ff041f

static int cycle_count = 0;
static FILE* dcachefile = NULL;
static FILE* lb0file = NULL;
static FILE* sq0file = NULL;
static FILE* lb1file = NULL;
static FILE* sq1file = NULL;

void print_header(char* str) {
  if (dcachefile == NULL) {
    dcachefile = fopen("debug/dcache.out", "w");
    lb0file    = fopen("debug/lb0.out", "w");
    sq0file    = fopen("debug/sq0.out", "w");
    lb1file    = fopen("debug/lb1.out", "w");
    sq1file    = fopen("debug/sq1.out", "w");
  }
  fprintf(dcachefile, "%s", str);
  fprintf(lb0file, "%s", str);
  fprintf(sq0file, "%s", str);
  fprintf(lb1file, "%s", str);
  fprintf(sq1file, "%s", str);
}

void print_start_cycle() {
  if (dcachefile != NULL) {
    fprintf(dcachefile, "\n@@@@@@@@@@@ dcache %2d @@@@@@@@@@@@@@", cycle_count);
    fprintf(lb0file, "\n@@@@@@@@@@@ lb0 %2d @@@@@@@@@@@@@@", cycle_count);
    fprintf(sq0file, "\n@@@@@@@@@@@ sq0 %2d @@@@@@@@@@@@@@", cycle_count);
    fprintf(lb1file, "\n@@@@@@@@@@@ lb1 %2d @@@@@@@@@@@@@@", cycle_count);
    fprintf(sq1file, "\n@@@@@@@@@@@ sq1 %2d @@@@@@@@@@@@@@", cycle_count);
  }
}

void print_lb0_entry(int i, int available, int base_addr_ready, int ready_to_go, int ready_cdb, int base_addr_PRN) {
  fprintf(lb0file, "\n(%d) free:%d base_addr_ready:%d ready_to_go:%d ready_cdb:%d base_addr_PRN:%d",
          i, available, base_addr_ready, ready_to_go, ready_cdb, base_addr_PRN);
}

void print_sq0_entry(int i, int ready, int value, int base_addr_PRN) {
  fprintf(sq0file, "\n(%2d) ready:%2d value:%2d base_addr_PRN:%x", i, ready, value, base_addr_PRN);
}

void print_lb1_entry(int i, int available, int base_addr_ready, int ready_to_go, int ready_cdb, int base_addr_PRN) {
  fprintf(lb1file, "\n(%d) free:%d base_addr_ready:%d ready_to_go:%d ready_cdb:%d base_addr_PRN:%d",
          i, available, base_addr_ready, ready_to_go, ready_cdb, base_addr_PRN);
}

void print_sq1_entry(int i, int ready, int value, int base_addr_PRN) {
  fprintf(sq1file, "\n(%2d) ready:%2d value:%2d base_addr_PRN:%x", i, ready, value, base_addr_PRN);
}

void print_dcache_entry(int i, int valid, int tag, int data) {
  fprintf(dcachefile, "\n(%2d) valid:%2d tag:%2d data:%x", i, valid, tag, data);
}

void print_buffer_request_entry(int i, int addr, int response) {
  fprintf(dcachefile, "\n(%2d) addr:%2d response:%2d", i, addr, response);
}

void print_dcache_line(char* s, int n) {
  fprintf(dcachefile, "\n%s: %x", s, n);
}

void print_dcache_empty_line() {
  fprintf(dcachefile, "\n");
}

void print_end_cycle() {
  if (dcachefile != NULL) {
    fprintf(dcachefile, "\n\n");
    fprintf(lb0file, "\n\n");
    fprintf(sq0file, "\n\n");
    fprintf(lb1file, "\n\n");
    fprintf(sq1file, "\n\n");
  }
}

void increment_cycle() {
  cycle_count++;
}
