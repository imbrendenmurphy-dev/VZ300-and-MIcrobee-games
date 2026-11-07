/* beeemu.c - headless Z80 + Microbee Premium video/keyboard model for testing EMPIRES.
 * Models: 64K RAM, F000-F7FF video RAM / attribute RAM (port 1C bit4),
 * F800-FFFF PCG bank (port 1C bits0-3) / colour RAM (port 08 bit6),
 * 6545 at 0C/0D incl. key polling through R18/R19/R31 + status bits 7,6,5,
 * PIO B (port 02) speaker bit 6 logged, CP/M BDOS console + file calls trapped.
 * Script on stdin:  frames N | key K 1/0 | shot FILE | quit | type TEXT
 * This is a test harness, not a cycle-exact Microbee.                       */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef uint8_t u8; typedef uint16_t u16; typedef int8_t s8;
static u8 blocks[32][32768]; static u8 ram[65536]; static u8 p50; static int lowblk=2, vidon=1, vid8000=0, cpm_block=2, banked=0;
static u8 vram[2048], aram[2048], cram[2048], pcg[16][2048];
static u8 p08, p1c, crtc_idx, crtc[32]; static int keys[64];
static long long tstates, frame_start; static int spk_toggles; static u8 last_b;
static int halted_exit=0;
static long long *spk_t; static int spk_n=0, spk_cap=0; static int spk_level=0; static long long wav_from=0;
static u8 cpm_ref[0x7000];
/* serial mouse: queued bytes, 7N1 at 1200 baud, bit4: mark=0 (idle), space=1 */
static long long BIT_T=2812;
static u8 sq[4096]; static long long sqt[4096]; static int sqn=0, sqh=0; static long long ser_until=0;
static int ser_inv=0;
static int serial_level(void){
  while(sqh<sqn){
    long long t0=sqt[sqh]; long long dt=tstates-t0;
    if(dt<0) return ser_inv;               /* idle before byte */
    int bit=(int)(dt/BIT_T);
    if(bit>=9){ sqh++; continue; }
    int mark;
    if(bit==0) mark=0;                      /* start bit = space */
    else if(bit<=7) mark=(sq[sqh]>>(bit-1))&1;
    else mark=1;                            /* stop */
    return (mark?0:1)^ser_inv;
  }
  return ser_inv;
}
static void ser_send(u8 b){ long long t=tstates; if(sqn>sqh && sqt[sqn-1]+9*BIT_T>t) t=sqt[sqn-1]+9*BIT_T+BIT_T/3; sq[sqn]=b; sqt[sqn]=t; sqn++; } static long long instr_count;
static long long FRAME_T=67500;

/* ---- memory ---- */
static int vidwin(u16 a){ if(!vidon) return 0; if(vid8000) return a>=0x8000&&a<0x9000; return a>=0xF000; }
static u16 vaddr(u16 a){ return vid8000? (a-0x8000+0xF000): a; }
static u8 rdv(u16 a);
static void wrv(u16 a,u8 v);
static u8 rd(u16 a){
  if(banked){ if(vidwin(a)) return rdv(vaddr(a)); return a<0x8000? blocks[lowblk][a]: blocks[0][a-0x8000]; }
  return rdv(a);
}
static void wr(u16 a,u8 v){
  if(banked){ if(vidwin(a)) { wrv(vaddr(a),v); return; } if(a<0x8000) blocks[lowblk][a]=v; else blocks[0][a-0x8000]=v; return; }
  wrv(a,v);
}
static u8 rdv(u16 a){
  if(a>=0xF000){
    if(a<0xF800) return (p1c&0x10)? aram[a&0x7ff]: vram[a&0x7ff];
    if(p08&0x40) return cram[a&0x7ff];
    return pcg[p1c&15][a&0x7ff];
  }
  return ram[a];
}
static void wrv(u16 a,u8 v){
  if(a>=0xF000){
    if(a<0xF800){ if(p1c&0x10) aram[a&0x7ff]=v; else vram[a&0x7ff]=v; return; }
    if(p08&0x40) cram[a&0x7ff]=v; else pcg[p1c&15][a&0x7ff]=v; return;
  }
  ram[a]=v;
}
static int in_vblank(void){ long long f=(tstates-frame_start)%FRAME_T; return f > FRAME_T*264/312; }
static u8 inport(u8 p){
  switch(p){
    case 0x0C: { u8 s=0x80; int code=((crtc[18]<<8)|crtc[19])>>4;
                 if(code>=0&&code<64&&keys[code]) s|=0x40;
                 if(in_vblank()) s|=0x20; return s; }
    case 0x0D: return crtc[crtc_idx&31];
    case 0x02: return 0x08 | (in_vblank()?0x80:0) | (serial_level()?0x10:0);
  }
  return 0xFF;
}
static void outport(u8 p,u8 v){
  switch(p){
    case 0x08: p08=v; break;
    case 0x1C: p1c=v; break;
    case 0x0C: crtc_idx=v&31; break;
    case 0x0D: crtc[crtc_idx&31]=v; break;
    case 0x02: if((v^last_b)&0x40){ spk_toggles++;
        if(spk_n>=spk_cap){ spk_cap=spk_cap?spk_cap*2:65536; spk_t=realloc(spk_t,spk_cap*sizeof(long long)); }
        spk_t[spk_n++]=tstates; }
      last_b=v; break;
    case 0x50: if(banked){ p50=v; int low=(v&3)^((v&4)?2:0); lowblk=(((v>>5)&7)<<2)|low; vidon=!(v&8); vid8000=(v&0x10)!=0; } break;
  }
}

/* ---- CPU ---- */
static u8 A,F,B,C,D,E,H,L,A_,F_,B_,C_,D_,E_,H_,L_,I,R,IFF;
static u16 IX,IY,SP,PC;
#define FC 1
#define FN 2
#define FP 4
#define FX 8
#define FH 16
#define FY 32
#define FZ 64
#define FS 128
static u8 parity[256];
static u16 rw(u16 a){ return rd(a)|(rd(a+1)<<8); }
static void ww(u16 a,u16 v){ wr(a,v&255); wr(a+1,v>>8); }
static u8 fetch(){ return rd(PC++); }
static u16 fetchw(){ u16 v=rw(PC); PC+=2; return v; }
static void push(u16 v){ SP-=2; ww(SP,v); }
static u16 pop(){ u16 v=rw(SP); SP+=2; return v; }
#define BC ((B<<8)|C)
#define DE ((D<<8)|E)
#define HL ((H<<8)|L)
static void setBC(u16 v){B=v>>8;C=v;} static void setDE(u16 v){D=v>>8;E=v;} static void setHL(u16 v){H=v>>8;L=v;}
static u8 szp(u8 v){ return (v&(FS|FY|FX))|(v?0:FZ)|parity[v]; }

static void add8(u8 v,int c){ int r=A+v+c; F=(r&0xff&(FS|FY|FX))|((r&0xff)?0:FZ)|((A^v^r)&FH)|(((A^~v)&(A^r)&0x80)?FP:0)|(r>0xff?FC:0); A=r; }
static void sub8(u8 v,int c,int store){ int r=A-v-c; u8 f=(r&0xff&(FS|FY|FX))|((r&0xff)?0:FZ)|((A^v^r)&FH)|(((A^v)&(A^r)&0x80)?FP:0)|(r<0?FC:0)|FN; if(!store) f=(f&~(FY|FX))|(v&(FY|FX)); F=f; if(store) A=r; }
static void alu(int op,u8 v){
  switch(op){ case 0: add8(v,0); break; case 1: add8(v,F&FC); break; case 2: sub8(v,0,1); break; case 3: sub8(v,F&FC,1); break;
    case 4: A&=v; F=szp(A)|FH; break; case 5: A^=v; F=szp(A); break; case 6: A|=v; F=szp(A); break; case 7: sub8(v,0,0); break; }
}
static u8 inc8(u8 v){ u8 r=v+1; F=(F&FC)|(r&(FS|FY|FX))|(r?0:FZ)|((r&15)==0?FH:0)|(v==0x7f?FP:0); return r; }
static u8 dec8(u8 v){ u8 r=v-1; F=(F&FC)|FN|(r&(FS|FY|FX))|(r?0:FZ)|((v&15)==0?FH:0)|(v==0x80?FP:0); return r; }
static u16 add16(u16 a,u16 b){ int r=a+b; F=(F&(FS|FZ|FP))|(((a^b^r)>>8)&FH)|((r>>8)&(FY|FX))|(r>0xffff?FC:0); return r; }
static u16 adc16(u16 a,u16 b){ int c=F&FC; int r=a+b+c; F=((r>>8)&(FS|FY|FX))|((r&0xffff)?0:FZ)|(((a^b^r)>>8)&FH)|((((a^~b)&(a^r))&0x8000)?FP:0)|(r>0xffff?FC:0); return r; }
static u16 sbc16(u16 a,u16 b){ int c=F&FC; int r=a-b-c; F=FN|((r>>8)&(FS|FY|FX))|((r&0xffff)?0:FZ)|(((a^b^r)>>8)&FH)|((((a^b)&(a^r))&0x8000)?FP:0)|(r<0?FC:0); return r; }

static u8* r8p(int r){ static u8 dummy; switch(r){case 0:return &B;case 1:return &C;case 2:return &D;case 3:return &E;case 4:return &H;case 5:return &L;case 7:return &A;} return &dummy; }
static u8 getr(int r){ return r==6? rd(HL): *r8p(r); }
static void setr(int r,u8 v){ if(r==6) wr(HL,v); else *r8p(r)=v; }
static int cond(int c){ switch(c){case 0:return !(F&FZ);case 1:return F&FZ;case 2:return !(F&FC);case 3:return F&FC;case 4:return !(F&FP);case 5:return F&FP;case 6:return !(F&FS);default:return F&FS;} }

static u8 cbop(int op,u8 v){
  u8 r; int c;
  switch(op){
    case 0: c=v>>7; r=(v<<1)|c; break;
    case 1: c=v&1; r=(v>>1)|(c<<7); break;
    case 2: c=v>>7; r=(v<<1)|(F&FC); break;
    case 3: c=v&1; r=(v>>1)|((F&FC)<<7); break;
    case 4: c=v>>7; r=v<<1; break;
    case 5: c=v&1; r=(v>>1)|(v&0x80); break;
    case 6: c=v>>7; r=(v<<1)|1; break;
    default: c=v&1; r=v>>1; break;
  }
  F=szp(r)|c; return r;
}

static void bdos(void);
static int trap_exit=0;

static int step(void);
static int exec_cb_idx(u16 addr){
  u8 op=fetch(); int x=op>>6,y=(op>>3)&7,z=op&7; u8 v=rd(addr),r;
  if(x==0){ r=cbop(y,v); wr(addr,r); if(z!=6) *r8p(z)=r; }
  else if(x==1){ F=(F&FC)|FH|((v&(1<<y))?0:(FZ|FP))|((y==7&&(v&0x80))?FS:0)|((addr>>8)&(FY|FX)); }
  else if(x==2){ r=v&~(1<<y); wr(addr,r); if(z!=6)*r8p(z)=r; }
  else { r=v|(1<<y); wr(addr,r); if(z!=6)*r8p(z)=r; }
  return 23;
}

static int exec_ed(void){
  u8 op=fetch(); int x=op>>6,y=(op>>3)&7,z=op&7,p=y>>1,q=y&1;
  if(x==1){
    switch(z){
      case 0: { u8 v=inport(C); if(y!=6) *r8p(y)=v; F=(F&FC)|szp(v); return 12; }
      case 1: outport(C,y==6?0:*r8p(y)); return 12;
      case 2: { u16 rr= p==0?BC:p==1?DE:p==2?HL:SP; u16 r= q? adc16(HL,rr): sbc16(HL,rr); setHL(r); return 15; }
      case 3: { u16 a=fetchw(); if(q){ u16 v=rw(a); if(p==0)setBC(v); else if(p==1)setDE(v); else if(p==2)setHL(v); else SP=v; } else { u16 v=p==0?BC:p==1?DE:p==2?HL:SP; ww(a,v);} return 20; }
      case 4: { u8 v=A; A=0; sub8(v,0,1); return 8; }
      case 5: PC=pop(); return 14;
      case 6: return 8;
      case 7: switch(y){ case 0: I=A; break; case 1: R=A; break; case 2: A=I; F=(F&FC)|szp(A)&~FP|(IFF?FP:0); break; case 3: A=R; F=(F&FC)|(szp(A)&~FP)|(IFF?FP:0); break;
        case 4: { u8 m=rd(HL); wr(HL,(A<<4)|(m>>4)); A=(A&0xf0)|(m&15); F=(F&FC)|szp(A); } break;
        case 5: { u8 m=rd(HL); wr(HL,(m<<4)|(A&15)); A=(A&0xf0)|(m>>4); F=(F&FC)|szp(A); } break; }
        return 9;
    }
  }
  if(x==2 && y>=4){
    int inc = (y&1)? -1: 1; int rep=y>=6;
    do{
      switch(z){
        case 0: { u8 v=rd(HL); wr(DE,v); setHL(HL+inc); setDE(DE+inc); setBC(BC-1); F=(F&(FS|FZ|FC))|(BC?FP:0); } break;
        case 1: { u8 v=rd(HL); u8 c=F&FC; sub8(v,0,0); A=A; setHL(HL+inc); setBC(BC-1); F=(F&~(FP|FC))|(BC?FP:0)|c|FN; if(rep && (F&FZ)) { tstates+=16; return 0; } } break;
        case 2: { u8 v=inport(C); wr(HL,v); setHL(HL+inc); B--; F=(B?0:FZ)|FN; } break;
        case 3: { u8 v=rd(HL); B--; outport(C,v); setHL(HL+inc); F=(B?0:FZ)|FN; } break;
      }
      tstates+=21;
      if(!rep) break;
      if(z<=1){ if(!BC) break; } else { if(!B) break; }
    } while(1);
    return 0;
  }
  return 8;
}

/* indexed opcodes (DD/FD) */
static int exec_idx(u16 *ixp){
  u8 op=fetch(); u16 ix=*ixp;
  #define IXH (ix>>8)
  #define IXL (ix&255)
  switch(op){
    case 0x09: *ixp=add16(ix,BC); return 15; case 0x19: *ixp=add16(ix,DE); return 15;
    case 0x29: *ixp=add16(ix,ix); return 15; case 0x39: *ixp=add16(ix,SP); return 15;
    case 0x21: *ixp=fetchw(); return 14;
    case 0x22: ww(fetchw(),ix); return 20;
    case 0x2A: *ixp=rw(fetchw()); return 20;
    case 0x23: (*ixp)++; return 10; case 0x2B: (*ixp)--; return 10;
    case 0x34: { s8 d=fetch(); u16 a=ix+d; wr(a,inc8(rd(a))); return 23; }
    case 0x35: { s8 d=fetch(); u16 a=ix+d; wr(a,dec8(rd(a))); return 23; }
    case 0x36: { s8 d=fetch(); u8 n=fetch(); wr(ix+d,n); return 19; }
    case 0xE1: *ixp=pop(); return 14; case 0xE5: push(ix); return 15;
    case 0xE3: { u16 t=rw(SP); ww(SP,ix); *ixp=t; return 23; }
    case 0xE9: PC=ix; return 8;
    case 0xF9: SP=ix; return 10;
    case 0xCB: { s8 d=fetch(); return exec_cb_idx(ix+d); }
    case 0x24: *ixp=(inc8(IXH)<<8)|IXL; return 8; case 0x25: *ixp=(dec8(IXH)<<8)|IXL; return 8;
    case 0x2C: *ixp=(ix&0xff00)|inc8(IXL); return 8; case 0x2D: *ixp=(ix&0xff00)|dec8(IXL); return 8;
    case 0x26: *ixp=(fetch()<<8)|IXL; return 11; case 0x2E: *ixp=(ix&0xff00)|fetch(); return 11;
  }
  int x=op>>6,y=(op>>3)&7,z=op&7;
  if(x==1 && op!=0x76){
    if(z==6){ s8 d=fetch(); *r8p(y)=rd(ix+d); return 19; }
    if(y==6){ s8 d=fetch(); wr(ix+d,*r8p(z)); return 19; }
    /* undocumented ixh/ixl */
    u8 v; if(z==4) v=IXH; else if(z==5) v=IXL; else v=*r8p(z);
    if(y==4) *ixp=(v<<8)|IXL; else if(y==5) *ixp=(ix&0xff00)|v; else *r8p(y)=v;
    return 8;
  }
  if(x==2){
    u8 v; if(z==6){ s8 d=fetch(); v=rd(ix+d);} else if(z==4) v=IXH; else if(z==5) v=IXL; else v=*r8p(z);
    alu(y,v); return 19;
  }
  /* treat as unprefixed */
  PC--; return 4;
}

static u16 hist[64]; static int histp;
static int step(void){
  hist[histp++&63]=PC;
  if(!banked || lowblk==cpm_block){
    if(PC==0x0005){ bdos(); PC=pop(); return 10; }
    if(PC==0x0000){ trap_exit=1; return 4; }
  }
  instr_count++;
  u8 op=fetch(); R=(R&0x80)|((R+1)&0x7f);
  int x=op>>6,y=(op>>3)&7,z=op&7,p=y>>1,q=y&1;
  if(op==0xCB){ u8 o=fetch(); int xx=o>>6,yy=(o>>3)&7,zz=o&7; u8 v=getr(zz);
    if(xx==0) setr(zz,cbop(yy,v));
    else if(xx==1) F=(F&FC)|FH|((v&(1<<yy))?0:(FZ|FP))|((yy==7&&(v&0x80))?FS:0)|(v&(FY|FX));
    else if(xx==2) setr(zz,v&~(1<<yy)); else setr(zz,v|(1<<yy));
    return 8; }
  if(op==0xED) return exec_ed();
  if(op==0xDD) return exec_idx(&IX);
  if(op==0xFD) return exec_idx(&IY);
  switch(x){
  case 0:
    switch(z){
      case 0: switch(y){ case 0: return 4; case 1: { u8 t=A;A=A_;A_=t;t=F;F=F_;F_=t; return 4; }
        case 2: { s8 d=fetch(); if(--B){PC+=d; return 13;} return 8; }
        case 3: { s8 d=fetch(); PC+=d; return 12; }
        default: { s8 d=fetch(); if(cond(y-4)){PC+=d; return 12;} return 7; } }
      case 1: if(!q){ u16 v=fetchw(); if(p==0)setBC(v); else if(p==1)setDE(v); else if(p==2)setHL(v); else SP=v; return 10; }
              else { u16 v=p==0?BC:p==1?DE:p==2?HL:SP; setHL(add16(HL,v)); return 11; }
      case 2: switch(y){ case 0: wr(BC,A); return 7; case 1: A=rd(BC); return 7; case 2: wr(DE,A); return 7; case 3: A=rd(DE); return 7;
        case 4: ww(fetchw(),HL); return 16; case 5: setHL(rw(fetchw())); return 16; case 6: wr(fetchw(),A); return 13; case 7: A=rd(fetchw()); return 13; }
      case 3: { int d=q?-1:1; if(p==0)setBC(BC+d); else if(p==1)setDE(DE+d); else if(p==2)setHL(HL+d); else SP+=d; return 6; }
      case 4: setr(y,inc8(getr(y))); return 4;
      case 5: setr(y,dec8(getr(y))); return 4;
      case 6: setr(y,fetch()); return 7;
      case 7: switch(y){
        case 0: { u8 c=A>>7; A=(A<<1)|c; F=(F&(FS|FZ|FP))|(A&(FY|FX))|c; return 4; }
        case 1: { u8 c=A&1; A=(A>>1)|(c<<7); F=(F&(FS|FZ|FP))|(A&(FY|FX))|c; return 4; }
        case 2: { u8 c=A>>7; A=(A<<1)|(F&FC); F=(F&(FS|FZ|FP))|(A&(FY|FX))|c; return 4; }
        case 3: { u8 c=A&1; A=(A>>1)|((F&FC)<<7); F=(F&(FS|FZ|FP))|(A&(FY|FX))|c; return 4; }
        case 4: { u8 a=A,c=0,cf=F&FC; if((F&FH)||(a&15)>9) c=6; if(cf||a>0x99){c|=0x60; cf=1;}
                  if(F&FN){ F=(F&FN)|(((a&15)<(c&15))?0:0); A=a-c; F= FN|cf|szp(A)|(((a^A)&FH)); } else { A=a+c; F=cf|szp(A)|((a^A)&FH); } return 4; }
        case 5: A=~A; F=(F&(FS|FZ|FP|FC))|FH|FN|(A&(FY|FX)); return 4;
        case 6: F=(F&(FS|FZ|FP))|(A&(FY|FX))|FC; return 4;
        case 7: F=(F&(FS|FZ|FP))|(A&(FY|FX))|((F&FC)?FH:0)|((F&FC)^FC); return 4; }
    }
  case 1:
    if(op==0x76){ halted_exit=1; return 4; }
    setr(y,getr(z)); return 4;
  case 2: alu(y,getr(z)); return 4;
  case 3:
    switch(z){
      case 0: if(cond(y)){PC=pop(); return 11;} return 5;
      case 1: if(!q){ u16 v=pop(); if(p==0)setBC(v); else if(p==1)setDE(v); else if(p==2)setHL(v); else {A=v>>8;F=v;} return 10; }
        switch(p){ case 0: PC=pop(); return 10; case 1: { u8 t; t=B;B=B_;B_=t;t=C;C=C_;C_=t;t=D;D=D_;D_=t;t=E;E=E_;E_=t;t=H;H=H_;H_=t;t=L;L=L_;L_=t; return 4; }
          case 2: PC=HL; return 4; case 3: SP=HL; return 6; }
      case 2: { u16 a=fetchw(); if(cond(y)) PC=a; return 10; }
      case 3: switch(y){ case 0: PC=fetchw(); return 10; case 2: outport(fetch(),A); return 11; case 3: A=inport(fetch()); return 11;
        case 4: { u16 t=rw(SP); ww(SP,HL); setHL(t); return 19; } case 5: { u8 t=D;D=H;H=t;t=E;E=L;L=t; return 4; }
        case 6: IFF=0; return 4; case 7: IFF=1; return 4; }
      case 4: { u16 a=fetchw(); if(cond(y)){ push(PC); PC=a; return 17;} return 10; }
      case 5: if(!q){ u16 v= p==0?BC:p==1?DE:p==2?HL:((A<<8)|F); push(v); return 11; }
        if(p==0){ u16 a=fetchw(); push(PC); PC=a; return 17; } return 4;
      case 6: alu(y,fetch()); return 7;
      case 7: push(PC); PC=y*8; return 11;
    }
  }
  return 4;
}

/* ---- CP/M BDOS (subset) ---- */
static FILE *conlog;
static FILE *openfiles[64]; static char openname[64][16];
static void fcbname(u16 fcb,char *out){ int i,k=0; for(i=1;i<=8;i++){u8 c=rd(fcb+i)&0x7f; if(c!=' ') out[k++]=c;} out[k++]='.'; for(i=9;i<=11;i++){u8 c=rd(fcb+i)&0x7f; if(c!=' ') out[k++]=c;} out[k]=0; }
static int slot_of(u16 fcb){ return rd(fcb+16)&63; }
static void bdos(void){
  int fn=C; u16 de=DE; char nm[16];
  switch(fn){
    case 0: trap_exit=1; break;
    case 2: fputc(E,conlog); break;
    case 6: if(E==0xFF){ A=0; } else fputc(E,conlog); break;
    case 9: { u16 a=de; while(rd(a)!='$') fputc(rd(a++),conlog); } break;
    case 11: A=0; break;
    case 12: setHL(0x0022); A=0x22; break;
    case 15: case 22: { fcbname(de,nm); int s; for(s=1;s<64&&openfiles[s];s++); FILE*f=fopen(nm,fn==15?"r+b":"w+b");
                 if(!f){A=0xFF;break;} openfiles[s]=f; strcpy(openname[s],nm); wr(de+16,s); wr(de+32,0); wr(de+12,0); A=0; } break;
    case 16: { int s=slot_of(de); if(s&&openfiles[s]){fclose(openfiles[s]);openfiles[s]=0;} A=0; } break;
    case 19: fcbname(de,nm); A= remove(nm)==0?0:0xFF; break;
    case 20: case 21: { int s=slot_of(de); FILE*f=openfiles[s]; if(!f){A=9;break;}
        long rec=rd(de+32)+rd(de+12)*128; u16 dma=rw(0xFFF0-0xFFF0)+0; (void)dma;
        extern u16 dmaaddr; fseek(f,rec*128,SEEK_SET); u8 buf[128]; int i;
        if(fn==20){ memset(buf,0x1A,128); int n=fread(buf,1,128,f); if(n<=0){A=1;break;} for(i=0;i<128;i++) wr(dmaaddr+i,buf[i]); }
        else { for(i=0;i<128;i++) buf[i]=rd(dmaaddr+i); fwrite(buf,1,128,f); }
        rec++; wr(de+32,rec&127); wr(de+12,rec>>7); A=0; } break;
    case 26: { extern u16 dmaaddr; dmaaddr=de; } break;
    default: A=0; break;
  }
  setHL(A); B=H;
}
u16 dmaaddr=0x80;

/* ---- dump ---- */
static void shot(const char *fn){
  FILE *f=fopen(fn,"wb"); if(!f) return;
  fwrite(vram,1,2048,f); fwrite(aram,1,2048,f); fwrite(cram,1,2048,f);
  for(int i=0;i<16;i++) fwrite(pcg[i],1,2048,f);
  fwrite(crtc,1,32,f); fputc(p1c,f); fputc(p08,f);
  fclose(f);
}

int main(int argc,char**argv){
  if(argc<2){ fprintf(stderr,"usage: beeemu prog.com < script\n"); return 1; }
  if(getenv("BEE_SPEED")){ int k=atoi(getenv("BEE_SPEED")); FRAME_T*=k; BIT_T*=k; }
  for(int i=0;i<256;i++){ int b=0; for(int k=0;k<8;k++) b^=(i>>k)&1; parity[i]=b?0:FP; }
  FILE *f=fopen(argv[1],"rb"); if(!f){perror(argv[1]);return 1;}
  size_t n=fread(ram+0x100,1,0xD000,f); fclose(f);
  if(argc>2 && !strcmp(argv[2],"banked")){
    banked=1; cpm_block=2; lowblk=2; vidon=1; p50=0x04;
    memcpy(blocks[2],ram,32768);
    for(int i=0;i<0x7000;i++) blocks[0][i]=(u8)((i*7+(i>>8))^0x5A);   /* stand-in for CP/M in 8000-EFFF */
    for(int b=1;b<32;b++) if(b!=2) for(int i=0;i<32768;i++) blocks[b][i]=(u8)(b*37+i);
  }
  conlog=stdout;
  /* page zero: warm boot at 0, BDOS entry at 5 pointing to E006 (TPA top) */
  ram[0]=0xC3; ram[1]=0x03; ram[2]=0xEA; ram[5]=0xC3; ram[6]=0x06; ram[7]=0xE0;
  if(banked){ blocks[2][0]=0xC3; blocks[2][1]=0x03; blocks[2][2]=0xEA; blocks[2][5]=0xC3; blocks[2][6]=0x06; blocks[2][7]=0xC0; }
  SP=0xE000; push(0x0000); PC=0x100;
  crtc[1]=80; crtc[6]=24; crtc[9]=10;
  if(banked) memcpy(cpm_ref,blocks[0],0x7000);
  fprintf(stderr,"loaded %zu bytes\n",n);
  char line[512];
  while(fgets(line,sizeof line,stdin)){
    char cmd[32]; int a=0,b=0; char arg[400]="";
    if(sscanf(line,"%31s",cmd)!=1) continue;
    if(!strcmp(cmd,"frames")){ sscanf(line,"%*s %d",&a);
      for(int fr=0;fr<a && !trap_exit && !halted_exit;fr++){
        frame_start=tstates - ((tstates)%FRAME_T); long long end=frame_start+FRAME_T;
        while(tstates<end && !trap_exit && !halted_exit){ int t=step(); tstates+=t; }
      }
      if(trap_exit){ fprintf(stderr,"program exited to CP/M (PC=%04X) after %lld instr\n",PC,instr_count);
        if(banked){ int bad=0; for(int i=0x4000;i<0x7000;i++) if(blocks[0][i]!=cpm_ref[i]){ if(bad<4) fprintf(stderr,"  diff at %04X: %02X\n",0x8000+i,blocks[0][i]); bad++; }
          fprintf(stderr,"CP/M upper memory C000-EFFF %s (%d bytes differ), port50=%02X lowblk=%d video=%d\n", bad?"DAMAGED":"intact",bad,p50,lowblk,vidon); } }
      if(halted_exit){ fprintf(stderr,"HALT at %04X\nhistory:",PC-1); for(int i=0;i<64;i++) fprintf(stderr," %04X",hist[(histp+i)&63]); fprintf(stderr,"\n"); }
    }
    else if(!strcmp(cmd,"key")){ sscanf(line,"%*s %d %d",&a,&b); if(a>=0&&a<64) keys[a]=b; }
    else if(!strcmp(cmd,"shot")){ sscanf(line,"%*s %399s",arg); shot(arg); }
    else if(!strcmp(cmd,"regs")){ fprintf(stderr,"PC=%04X SP=%04X A=%02X F=%02X BC=%04X DE=%04X HL=%04X IX=%04X IY=%04X T=%lld spk=%d\n",PC,SP,A,F,BC,DE,HL,IX,IY,tstates,spk_toggles); }
    else if(!strcmp(cmd,"peek")){ sscanf(line,"%*s %x %d",&a,&b); fprintf(stderr,"%04X:",a); for(int i=0;i<b;i++) fprintf(stderr," %02X",rd(a+i)); fprintf(stderr,"\n"); }
    else if(!strcmp(cmd,"mem")){ sscanf(line,"%*s %399s",arg); FILE*m=fopen(arg,"wb"); for(int i=0;i<65536;i++) fputc(rd(i),m); fclose(m); }
    else if(!strcmp(cmd,"callt")){ sscanf(line,"%*s %x",&a); u16 ret=PC, sp0=SP; push(ret); PC=a; long long t0=tstates;
      static unsigned prof[65536]; memset(prof,0,sizeof prof);
      while(!(PC==ret && SP==sp0) && !trap_exit && !halted_exit){ u16 p0=PC; int t=step(); prof[p0]+=t; tstates+=t; }
      { FILE*pf=fopen("build/prof.bin","wb"); fwrite(prof,4,65536,pf); fclose(pf); }
      fprintf(stderr,"callt %04X: %lld T (%.2f frames)\n",a,tstates-t0,(double)(tstates-t0)/FRAME_T); }
    else if(!strcmp(cmd,"mouse")){ int dx=0,dy=0,l=0,r=0; sscanf(line,"%*s %d %d %d %d",&dx,&dy,&l,&r);
      u8 b1=0x40|(l?0x20:0)|(r?0x10:0)|(((dy>>6)&3)<<2)|((dx>>6)&3); ser_send(b1); ser_send(dx&0x3F); ser_send(dy&0x3F); }
    else if(!strcmp(cmd,"serinv")){ sscanf(line,"%*s %d",&ser_inv); }
    else if(!strcmp(cmd,"blk")){ int b=0; sscanf(line,"%*s %d %399s",&b,arg); FILE*m=fopen(arg,"wb"); fwrite(blocks[b],1,32768,m); fclose(m); }
    else if(!strcmp(cmd,"bank")){ fprintf(stderr,"port50=%02X lowblk=%d video=%d\n",p50,lowblk,vidon); }
    else if(!strcmp(cmd,"profile")){ sscanf(line,"%*s %d",&a); static unsigned prof2[65536]; memset(prof2,0,sizeof prof2);
      long long end=tstates+(long long)a*FRAME_T; while(tstates<end && !trap_exit && !halted_exit){ u16 p0=PC; int t=step(); prof2[p0]+=t; tstates+=t; }
      FILE*pf=fopen("../build/prof.bin","wb"); if(!pf) pf=fopen("build/prof.bin","wb"); fwrite(prof2,4,65536,pf); fclose(pf); fprintf(stderr,"profiled %d frames, PC=%04X\n",a,PC); }
    else if(!strcmp(cmd,"spklog")){ sscanf(line,"%*s %399s",arg); FILE*w=fopen(arg,"wb"); fwrite(spk_t,sizeof(long long),spk_n,w); fclose(w); }
    else if(!strcmp(cmd,"wavstart")){ wav_from=tstates; }
    else if(!strcmp(cmd,"wav")){ sscanf(line,"%*s %399s",arg); FILE*w=fopen(arg,"wb");
      int rate=22050; long long len=(tstates-wav_from)*rate/3375000; int n=(int)len;
      unsigned hdr[11]; fwrite("RIFF",1,4,w); unsigned v32=36+n*2; fwrite(&v32,4,1,w); fwrite("WAVEfmt ",1,8,w);
      v32=16; fwrite(&v32,4,1,w); unsigned short v16=1; fwrite(&v16,2,1,w); fwrite(&v16,2,1,w);
      v32=rate; fwrite(&v32,4,1,w); v32=rate*2; fwrite(&v32,4,1,w); v16=2; fwrite(&v16,2,1,w); v16=16; fwrite(&v16,2,1,w);
      fwrite("data",1,4,w); v32=n*2; fwrite(&v32,4,1,w);
      int k=0, lvl=0; while(k<spk_n && spk_t[k]<wav_from){ lvl^=1; k++; }
      double hp=0, prev=0;
      for(int i=0;i<n;i++){ long long t0=wav_from+(long long)i*3375000/rate, t1=wav_from+(long long)(i+1)*3375000/rate;
        /* average level over the sample interval */
        double acc=0; long long t=t0; while(k<spk_n && spk_t[k]<t1){ acc+=(spk_t[k]-t)*lvl; t=spk_t[k]; lvl^=1; k++; }
        acc+=(t1-t)*lvl; double x=acc/(t1-t0);
        hp=0.995*(hp+x-prev); prev=x; short smp=(short)(hp*12000); fwrite(&smp,2,1,w); }
      fclose(w); fprintf(stderr,"wav %s: %.1f s\n",arg,(double)n/rate); }
    else if(!strcmp(cmd,"quit")) break;
  }
  fprintf(stderr,"T=%lld frames=%.1f speaker_toggles=%d\n",tstates,(double)tstates/FRAME_T,spk_toggles);
  return 0;
}
