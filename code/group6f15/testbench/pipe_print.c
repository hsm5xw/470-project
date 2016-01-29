/*
 *  pipe_print.c - Print instructions as they pass through the verisimple
 *                 pipeline.  Must compile with the '+vc' vcs flag.
 *
 *  Doug MacKay <dmackay@umich.edu> Fall 2003
 */

#include <stdio.h>
#include "DirectC.h"

#define NOOP_INST 0x47ff041f

int cycle_count = 0;
static FILE* ppfile = NULL;
static FILE* rob0file = NULL;
static FILE* rob1file = NULL;
static FILE* prffile = NULL;
static FILE* ratfile = NULL;
static FILE* rsfile = NULL;
static FILE* icachefile = NULL;
static FILE* ratprffile = NULL;
static FILE* instfile = NULL;
static FILE* dcachefile = NULL;
static FILE* lb0file = NULL;
static FILE* sq0file = NULL;
static FILE* lb1file = NULL;
static FILE* sq1file = NULL;
static FILE* wb0file = NULL;
static FILE* wb1file = NULL;

void print_header(char* str) {
  if (ppfile == NULL) {
    ppfile        = fopen("debug/pipeline.out", "w");
    rob0file      = fopen("debug/rob0.out", "w");
    rob1file      = fopen("debug/rob1.out", "w");
    prffile       = fopen("debug/prf.out", "w");
    ratfile       = fopen("debug/rat.out", "w");
    ratprffile    = fopen("debug/ratprf.out", "w");
    rsfile        = fopen("debug/rs.out", "w");
    icachefile    = fopen("debug/icache.out", "w");
    instfile      = fopen("debug/inst.out", "w");
    dcachefile    = fopen("debug/dcache.out", "w");
    lb0file       = fopen("debug/lb0.out", "w");
    sq0file       = fopen("debug/sq0.out", "w");
    lb1file       = fopen("debug/lb1.out", "w");
    sq1file       = fopen("debug/sq1.out", "w");
    wb0file       = fopen("debug/wb0.out", "w");
    wb1file       = fopen("debug/wb1.out", "w");
  }

  fprintf(ppfile, "%s", str);
  fprintf(rob0file, "%s", str);
  fprintf(rob1file, "%s", str);
  fprintf(prffile, "%s", str);
  fprintf(ratfile, "%s", str);
  fprintf(rsfile, "%s", str);
  fprintf(icachefile, "%s", str);
  fprintf(ratprffile, "%s", str);
  fprintf(instfile, "%s", str);
  fprintf(dcachefile, "%s", str);
  fprintf(lb0file, "%s", str);
  fprintf(sq0file, "%s", str);
  fprintf(lb1file, "%s", str);
  fprintf(sq1file, "%s", str);
}

void print_prefetch_entry(int i, int tag, int addr) {
  fprintf(icachefile, "\n(%2d) tag:%2d addr:%d", i, tag, addr);
}

void print_wb0(int commit, int valid, int pc, int arn, int val1, int val0, int cycle) {
  if(commit) {
    if(valid)
      fprintf(wb0file, "PC=%4d, CYCLE=%4d, REG[%2d]=%x%x\n", pc, cycle, arn, val1, val0);
    else
      fprintf(wb0file, "PC=%4d, CYCLE=%4d, ---\n", pc, cycle);
  }
}

void print_wb1(int commit, int valid, int pc, int arn, int val1, int val0, int cycle) {
  if(commit) {
    if(valid)
      fprintf(wb1file, "PC=%4d, CYCLE=%4d, REG[%2d]=%x%x\n", pc, cycle, arn, val1, val0);
    else
      fprintf(wb1file, "PC=%4d, CYCLE=%4d, ---\n", pc, cycle);
  }
}

void print_inst_entry(char* str, int valid, int pc, int thread_id) {
  if(!valid)
    fprintf(instfile, "\n(%s) ----------", str);
  else
    fprintf(instfile, "\n(%s)  pc:%d   thread:%2d", str, pc, thread_id);
}

void print_inst_empty_line() {
  fprintf(instfile, "\n");
}

void print_inst_line(char* s, int n) {
  fprintf(instfile, "\n%s: %2d", s, n);
}

void print_start_cycle() {
  fprintf(rob0file, "\n@@@@@@@@@@@ rob0 %2d @@@@@@@@@@@@@@", cycle_count);
  fprintf(rob1file, "\n@@@@@@@@@@@ rob1 %2d @@@@@@@@@@@@@@", cycle_count);
  fprintf(prffile, "\n@@@@@@@@@@@ prf %2d @@@@@@@@@@@@@", cycle_count);
  fprintf(ratfile, "\n@@@@@@@@@@@ rat %2d @@@@@@@@@@@@@", cycle_count);
  fprintf(rsfile, "\n@@@@@@@@@@@ rs %2d @@@@@@@@@@@@@", cycle_count);
  fprintf(icachefile, "\n@@@@@@@@@@@ icache %2d @@@@@@@@@@@@@", cycle_count);
  fprintf(ratprffile, "\n@@@@@@@@@@@ ratprf %2d @@@@@@@@@@@@@", cycle_count);
  fprintf(instfile, "\n@@@@@@@@@@@ inst %2d @@@@@@@@@@@@@", cycle_count);
  fprintf(dcachefile, "\n@@@@@@@@@@@ dcache %2d @@@@@@@@@@@@@@", cycle_count);
  fprintf(lb0file, "\n@@@@@@@@@@@ lb0 %2d @@@@@@@@@@@@@@", cycle_count);
  fprintf(sq0file, "\n@@@@@@@@@@@ sq0 %2d @@@@@@@@@@@@@@", cycle_count);
  fprintf(lb1file, "\n@@@@@@@@@@@ lb1 %2d @@@@@@@@@@@@@@", cycle_count);
  fprintf(sq1file, "\n@@@@@@@@@@@ sq1 %2d @@@@@@@@@@@@@@", cycle_count);
}

void print_sq0_line(char* s, int n) {
  fprintf(sq0file, "\n%s: %2d", s, n);
}

void print_lb0_entry(int i, int available, int base_addr_ready, int ready_to_go, int ready_cdb, int base_addr_PRN, int address, int base_addr) {
  fprintf(lb0file, "\n(%d) free:%d base_addr_ready:%d ready_to_go:%d ready_cdb:%d base_addr_PRN:%3d address:%3d req_succeed:%3d",
          i, available, base_addr_ready, ready_to_go, ready_cdb, base_addr_PRN, address, base_addr);
}

void print_lb0_line(char* s, int n) {
  fprintf(lb0file, "\n%s: %x", s, n);
}

void print_lb0_status_entry(int i, int n0, int n1, int n2, int n3, int n4, int n5, int n6, int n7) {
  fprintf(lb0file, "\n(%d)  %2d  %2d  %2d  %2d  %2d  %2d  %2d  %2d", i, n0, n1, n2, n3, n4, n5, n6, n7);
}

void print_sq0_entry(int i, int valid, int ready, int value, int base_addr_PRN, int address) {
  fprintf(sq0file, "\n(%2d) valid:%d ready:%2d value:%2d base_addr_PRN:%3d address:%3d", i, valid, ready, value, base_addr_PRN, address);
}

void print_lb1_entry(int i, int available, int base_addr_ready, int ready_to_go, int ready_cdb, int base_addr_PRN, int address, int base_addr) {
  fprintf(lb1file, "\n(%d) free:%d base_addr_ready:%d ready_to_go:%d ready_cdb:%d base_addr_PRN:%3d address:%3d req_succeed:%3d",
          i, available, base_addr_ready, ready_to_go, ready_cdb, base_addr_PRN, address, base_addr);
}

void print_sq1_entry(int i, int valid, int ready, int value, int base_addr_PRN, int address) {
  fprintf(sq1file, "\n(%2d) valid:%d ready:%2d value:%2d base_addr_PRN:%3d address:%3d", i, valid, ready, value, base_addr_PRN, address);
}

void print_dcache_entry(int i, int valid, int tag, int data1, int data0) {
  fprintf(dcachefile, "\n(%2d) valid:%2d tag:%2d data:%x%x", i, valid, tag, data1, data0);
}

void print_buffer_request_entry(int i, int addr, int response) {
  fprintf(dcachefile, "\n(%2d) addr:%2d response:%2d", i, addr, response);
}

void print_dcache_line(char* s, int n) {
  fprintf(dcachefile, "\n%s: %d", s, n);
}

void print_dcache_empty_line() {
  fprintf(dcachefile, "\n");
}

void print_cdb(int FU_result, int prn, int rob, int valid, int mispredict, int branch_taken, int thread_id) {
  fprintf(lb0file, "\nvalid:%2d prn:%2d rob:%2d FU_result:%8x mispredict:%2d branch_taken:%2d thread_id:%2d", 
          valid, prn, rob, FU_result, mispredict, branch_taken, thread_id);
  fprintf(sq0file, "\nvalid:%2d prn:%2d rob:%2d FU_result:%8x mispredict:%2d branch_taken:%2d thread_id:%2d", 
          valid, prn, rob, FU_result, mispredict, branch_taken, thread_id);
  fprintf(instfile, "\nvalid:%2d prn:%2d rob:%2d FU_result:%8x mispredict:%2d branch_taken:%2d thread_id:%2d", 
          valid, prn, rob, FU_result, mispredict, branch_taken, thread_id);
}

void print_ex_entry(int valid, int instr_type, int op1, int op2, int rob)  {
  fprintf(rsfile, "\nvalid:%2d instr_type:%2d op1:%8x op2:%8x rob:%2d", valid, instr_type, op1, op2, rob);
}

void print_rs_line(char* s, int n) {
  fprintf(rsfile, "\n%s: %x", s, n);
}

void print_rs_empty_line() {
  fprintf(rsfile, "\n");
}

void print_rob_line(char* s, int n0, int n1) {
  fprintf(rob0file, "\n%s: %2d", s, n0);
  fprintf(rob1file, "\n%s: %2d", s, n1);
}

void print_cache_line(char* s, int n) {
  fprintf(icachefile, "\n%s: %d", s, n);
}

void print_icache_entry(int i, int valid, int tag, int data1, int data0) {
  fprintf(icachefile, "\n(%2d) valid:%2d tag:%2d data:%x%x", i, valid, tag, data1, data0);
}

void print_rs_header() {
  fprintf(rsfile, "\n    index  busy   rob_idx prn_dst opa_rdy  opa_val opa_prn opb_rdy  opb_val opb_prn thread");
}

void print_rs_entry(int i, int busy, int rob, int prn_dest, int opa_ready, int opa_value, int opa_prn, 
                    int opb_ready, int opb_value, int opb_prn, int thread) {
  fprintf(rsfile, "\n%7d %7d %7d %7d %7d %8x %7d %7d %8x %7d %7d", i, busy, rob, prn_dest, opa_ready, opa_value, opa_prn, 
          opb_ready, opb_value, opb_prn, thread);  
}

void print_rat_prf_entry(int i, int n0, int n1, int n2, int n3) {
  fprintf(ratprffile, "\n%2d   %x%x %d   %x%x %d", i, n0, n1, n1, n2, n3, n3);
}

void print_rat_enty(int i, int rat0, int rrat0, int rat1, int rrat1) {
  fprintf(ratfile, "\n(%3d) rat0:%3d rrat0:%3d rat1:%3d rrat1:%3d", i, rat0, rrat0, rat1, rrat1);
}

void print_prf_entry(int i, int value, int thread, int valid, int free_entry) {
  fprintf(prffile, "\n(%2d) value:%8x thread:%2d valid:%2d free:%2d", i, value, thread, valid, free_entry);
}

void print_rob0_entry(int i, int pc, int executed, int instr_type, int prn_dest) {
  fprintf(rob0file, "\n(%2d) pc:%4d executed:%2d type:%2d prn_dest:%2d", i, pc, executed, instr_type, prn_dest);
}

void print_rob1_entry(int i, int pc, int executed, int instr_type, int prn_dest) {
  fprintf(rob1file, "\n(%2d) pc:%4d executed:%2d type:%2d prn_dest:%2d", i, pc, executed, instr_type, prn_dest);
}

void print_end_cycle() {
  fprintf(rob0file, "\n\n");
  fprintf(rob1file, "\n\n");
  fprintf(prffile, "\n\n");
  fprintf(ratfile, "\n\n");
  fprintf(rsfile, "\n\n");
  fprintf(icachefile, "\n\n");
  fprintf(ratprffile, "\n\n");
  fprintf(instfile, "\n\n");
  fprintf(dcachefile, "\n\n");
  fprintf(lb0file, "\n\n");
  fprintf(sq0file, "\n\n");
  fprintf(lb1file, "\n\n");
  fprintf(sq1file, "\n\n");
}

void increment_cycle() {
  cycle_count++;
}

void print_cycles() {
  fprintf(ppfile, "\n%5d:", cycle_count);
}


void print_stage(char* div, int inst, int npc, int valid_inst) {
  int opcode, check;
  char *str;
  
  if(!valid_inst)
    str = "-";
  else if(inst==NOOP_INST)
    str = "nop";
  else {
    opcode = (inst >> 26) & 0x0000003f;
    check = (inst>>5) & 0x0000007f;
    switch(opcode)
    {
      case 0x00: str = (inst == 0x555) ? "halt" : "call_pal"; break;
      case 0x08: str = "lda"; break;
      case 0x09: str = "ldah"; break;
      case 0x0a: str = "ldbu"; break;
      case 0x0b: str = "ldqu"; break;
      case 0x0c: str = "ldwu"; break;
      case 0x0d: str = "stw"; break;
      case 0x0e: str = "stb"; break;
      case 0x0f: str = "stqu"; break;
      case 0x10: // INTA_GRP
         switch(check)
         {
           case 0x00: str = "addl"; break;
           case 0x02: str = "s4addl"; break;
           case 0x09: str = "subl"; break;
           case 0x0b: str = "s4subl"; break;
           case 0x0f: str = "cmpbge"; break;
           case 0x12: str = "s8addl"; break;
           case 0x1b: str = "s8subl"; break;
           case 0x1d: str = "cmpult"; break;
           case 0x20: str = "addq"; break;
           case 0x22: str = "s4addq"; break;
           case 0x29: str = "subq"; break;
           case 0x2b: str = "s4subq"; break;
           case 0x2d: str = "cmpeq"; break;
           case 0x32: str = "s8addq"; break;
           case 0x3b: str = "s8subq"; break;
           case 0x3d: str = "cmpule"; break;
           case 0x40: str = "addlv"; break;
           case 0x49: str = "sublv"; break;
           case 0x4d: str = "cmplt"; break;
           case 0x60: str = "addqv"; break;
           case 0x69: str = "subqv"; break;
           case 0x6d: str = "cmple"; break;
           default: str = "invalid"; break;
         }
         break;
      case 0x11: // INTL_GRP
         switch(check)
         {
           case 0x00: str = "and"; break;
           case 0x08: str = "bic"; break;
           case 0x14: str = "cmovlbs"; break;
           case 0x16: str = "cmovlbc"; break;
           case 0x20: str = "bis"; break;
           case 0x24: str = "cmoveq"; break;
           case 0x26: str = "cmovne"; break;
           case 0x28: str = "ornot"; break;
           case 0x40: str = "xor"; break;
           case 0x44: str = "cmovlt"; break;
           case 0x46: str = "cmovge"; break;
           case 0x48: str = "eqv"; break;
           case 0x61: str = "amask"; break;
           case 0x64: str = "cmovle"; break;
           case 0x66: str = "cmovgt"; break;
           case 0x6c: str = "implver"; break;
           default: str = "invalid"; break;
         }
         break;
      case 0x12: // INTS_GRP
         switch(check)
         {
           case 0x02: str = "mskbl"; break;
           case 0x06: str = "extbl"; break;
           case 0x0b: str = "insbl"; break;
           case 0x12: str = "mskwl"; break;
           case 0x16: str = "extwl"; break;
           case 0x1b: str = "inswl"; break;
           case 0x22: str = "mskll"; break;
           case 0x26: str = "extll"; break;
           case 0x2b: str = "insll"; break;
           case 0x30: str = "zap"; break;
           case 0x31: str = "zapnot"; break;
           case 0x32: str = "mskql"; break;
           case 0x34: str = "srl"; break;
           case 0x36: str = "extql"; break;
           case 0x39: str = "sll"; break;
           case 0x3b: str = "insql"; break;
           case 0x3c: str = "sra"; break;
           case 0x52: str = "mskwh"; break;
           case 0x57: str = "inswh"; break;
           case 0x5a: str = "extwh"; break;
           case 0x62: str = "msklh"; break;
           case 0x67: str = "inslh"; break;
           case 0x6a: str = "extlh"; break;
           case 0x72: str = "mskqh"; break;
           case 0x77: str = "insqh"; break;
           case 0x7a: str = "extqh"; break;
           default: str = "invalid"; break;
         }
         break;
      case 0x13: // INTM_GRP
         switch(check)
         {
           case 0x00: str = "mull"; break;
           case 0x20: str = "mulq"; break;
           case 0x30: str = "umulh"; break;
           case 0x40: str = "mullv"; break;
           case 0x60: str = "mulqv"; break;
           default: str = "invalid"; break;
         }
         break;
      case 0x14: str = "itfp"; break; // unimplemented
      case 0x15: str = "fltv"; break; // unimplemented
      case 0x16: str = "flti"; break; // unimplemented
      case 0x17: str = "fltl"; break; // unimplemented
      case 0x1a: str = "jsr"; break;
      case 0x1c: str = "ftpi"; break;
      case 0x20: str = "ldf"; break;
      case 0x21: str = "ldg"; break;
      case 0x22: str = "lds"; break;
      case 0x23: str = "ldt"; break;
      case 0x24: str = "stf"; break;
      case 0x25: str = "stg"; break;
      case 0x26: str = "sts"; break;
      case 0x27: str = "stt"; break;
      case 0x28: str = "ldl"; break;
      case 0x29: str = "ldq"; break;
      case 0x2a: str = "ldll"; break;
      case 0x2b: str = "ldql"; break;
      case 0x2c: str = "stl"; break;
      case 0x2d: str = "stq"; break;
      case 0x2e: str = "stlc"; break;
      case 0x2f: str = "stqc"; break;
      case 0x30: str = "br"; break;
      case 0x31: str = "fbeq"; break;
      case 0x32: str = "fblt"; break;
      case 0x33: str = "fble"; break;
      case 0x34: str = "bsr"; break;
      case 0x35: str = "fbne"; break;
      case 0x36: str = "fbge"; break;
      case 0x37: str = "fbgt"; break;
      case 0x38: str = "blbc"; break;
      case 0x39: str = "beq"; break;
      case 0x3a: str = "blt"; break;
      case 0x3b: str = "ble"; break;
      case 0x3c: str = "blbs"; break;
      case 0x3d: str = "bne"; break;
      case 0x3e: str = "bge"; break;
      case 0x3f: str = "bgt"; break;
      default: str = "invalid"; break;
    }
  }

  if (ppfile != NULL)
    fprintf(ppfile, "%s%4d:%-8s", div, npc-4, str);
}

void print_close()
{
  fprintf(ppfile, "\n");
  fclose(ppfile);
  ppfile = NULL;
}

void print_membus(int proc2mem_command, int mem2proc_response,
                  int proc2mem_addr_hi, int proc2mem_addr_lo,
                  int proc2mem_data_hi, int proc2mem_data_lo)
{
  if (ppfile == NULL)
    return;

  switch(proc2mem_command)
  {
    case 1: fprintf(ppfile, "BUS_LOAD  MEM["); break;
    case 2: fprintf(ppfile, "BUS_STORE MEM["); break;
    default: return; break;
  }
  
  if((proc2mem_addr_hi==0)||
     ((proc2mem_addr_hi==-1)&&(proc2mem_addr_lo<0)))
    fprintf(ppfile, "%d",proc2mem_addr_lo);
  else
    fprintf(ppfile, "0x%x%x",proc2mem_addr_hi,proc2mem_addr_lo);
  if(proc2mem_command==1)
  {
    fprintf(ppfile, "]");
  } else {
    fprintf(ppfile, "] = ");
    if((proc2mem_data_hi==0)||
       ((proc2mem_data_hi==-1)&&(proc2mem_data_lo<0)))
      fprintf(ppfile, "%d",proc2mem_data_lo);
    else
      fprintf(ppfile, "0x%x%x",proc2mem_data_hi,proc2mem_data_lo);
  }
  if(mem2proc_response) {
    fprintf(ppfile, " accepted %d",mem2proc_response);
  } else {
    fprintf(ppfile, " rejected");
  }
}
