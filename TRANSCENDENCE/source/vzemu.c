// Minimal VZ300 (PAL) emulator for testing: 64K RAM, latch $6800, FS interrupt, frame + audio capture
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "z80.h"
#define TPL 227
#define LINES 312
#define FRAME (TPL*LINES)
#define FSLEN (56*TPL)
#define CPU 3546894.0
static uint8_t mem[65536];
static uint8_t latch=0;
static unsigned long cyc_now=0;
static int spk=0;
static FILE *wav=0; static double acc=0, accT=0, sampT=CPU/44100.0; static unsigned long lastc=0; static long nsamp=0;
static unsigned long sndaddr=0; static int sndset[65536]; static unsigned long sndi_addr=0; static double sitesum[65536]; static long sitecnt[65536]; static unsigned long lastTick=0; static long hist[4096];
static long fieldTicks; static long tmin=1e9,tmax=0; static double tsum; static long tcnt;
static FILE *tlog=0;
static int romcalls=0; static unsigned long maxgap=0; static uint16_t maxgapRA=0; static int maxgapF=0; static int gapcount=0; static long gapRA[65536]; static unsigned long gapMax[65536]; static unsigned long lastEI=0, lastISR=0; static int previff=0; static uint16_t lastTickRA=0; static int dbgmiss=0; static int fsInt=0, prevfs=0; static long missed=0; static uint16_t misspc[64]; static long hitaddr=-1, hits=0; static unsigned long prof[65536]; static int pf0=-1,pf1=-1; static uint16_t pchist[256]; static int pch=0; static uint16_t lastpc=0;
static void audio_adv(unsigned long c){ // integrate speaker level up to cycle c
  while(lastc<c){ unsigned long step=c-lastc; double need=sampT-accT; if(step>=need){ acc+=spk*need; lastc+=(unsigned long)need; if((unsigned long)need==0) lastc++; double v=acc/sampT; int16_t s=(int16_t)(v*12000); if(wav) fwrite(&s,2,1,wav); nsamp++; acc=0; accT=0;} else { acc+=spk*step; accT+=step; lastc=c; } }
}
static int fs_low(unsigned long c){ return (c%FRAME)<FSLEN; }
static uint8_t rb(void*u,uint16_t a){ if(a>=0x6800&&a<0x7000){ uint8_t v=0x7F; if(!fs_low(cyc_now)) v|=0x80; return v;} return mem[a]; }
static long wlo=-1,whi=-1; static z80*ZP;
static void wb(void*u,uint16_t a,uint8_t v){ if(a<0x4000) return; if(a>=wlo&&a<=whi){ fprintf(stderr,"WRITE %04X=%02X PC=%04X\n",a,v,ZP->pc); } if(a>=0x6800&&a<0x7000){ audio_adv(cyc_now); latch=v; int s= ((v>>5)&1) - (v&1); spk=s; return;} mem[a]=v; }
static uint8_t pin(z80*z,uint8_t p){return 0xFF;}
static void pout(z80*z,uint8_t p,uint8_t v){}
int main(int argc,char**argv){
  if(argc<4){fprintf(stderr,"vzemu file.vz nframes frames.bin [audio.wav] [sndaddr hex] [ticklog]\n");return 1;}
  FILE*f=fopen(argv[1],"rb"); uint8_t hdr[24]; fread(hdr,1,24,f); uint16_t start=hdr[22]|(hdr[23]<<8);
  size_t n=fread(mem+start,1,65536-start,f); fclose(f);
  fprintf(stderr,"loaded %zu bytes at %04X-%04X\n",n,start,(unsigned)(start+n-1));
  srand(1); for(int i=0x4000;i<0x6800;i++) if(i<start||i>=start+(int)n) mem[i]=rand(); for(int i=0x7800;i<start;i++) mem[i]=rand(); for(int i=start+n;i<65536;i++) mem[i]=rand();
  int nf=atoi(argv[2]); FILE*fo=fopen(argv[3],"wb");
  if(argc>4 && strcmp(argv[4],"-")){ wav=fopen(argv[4],"wb"); uint8_t h[44]={0}; fwrite(h,1,44,wav);}
  if(argc>5){ char*q=argv[5]; while(*q){ unsigned long a=strtoul(q,&q,16); sndset[a]=1; sndaddr=a; if(*q==',') q++; else break; } }
  if(getenv("SNDI")) sndi_addr=strtoul(getenv("SNDI"),0,16);
  if(argc>6) tlog=fopen(argv[6],"w");
  z80 z; z80_init(&z); ZP=&z; if(getenv("HIT")) hitaddr=strtol(getenv("HIT"),0,16); if(getenv("PF0")){pf0=atoi(getenv("PF0"));pf1=atoi(getenv("PF1"));} if(getenv("WLO")){ wlo=strtol(getenv("WLO"),0,16); whi=strtol(getenv("WHI"),0,16);}  z.read_byte=rb; z.write_byte=wb; z.port_in=pin; z.port_out=pout; z.pc=start; if(getenv("START")) z.pc=strtoul(getenv("START"),0,16); z.sp=0xF000;
  unsigned long nextframe=FRAME; int frame=0; uint8_t midl=0; int capmid=0;
  while(frame<nf){
    cyc_now=z.cyc;
    if((uint16_t)(z.pc-lastpc)>16 && (uint16_t)(lastpc-z.pc)>16) pchist[pch++&255]=z.pc; lastpc=z.pc;
    if(z.pc<0x4000 && !romcalls){ fprintf(stderr,"ROM call PC=%04X at frame %d SP=%04X\n",z.pc,frame,z.sp); romcalls=1; for(int i=0;i<256;i++) fprintf(stderr,"%04X ",pchist[(pch+i)&255]); fprintf(stderr,"\n"); }
    if(sndset[z.pc]){ unsigned long d=z.cyc-lastTick; lastTick=z.cyc; uint16_t ra=mem[z.sp]|(mem[(uint16_t)(z.sp+1)]<<8); lastTickRA=ra; if(d>maxgap && d<1000000){maxgap=d;maxgapRA=ra;maxgapF=frame;} if(d>8000 && d<1000000){ gapcount++; gapRA[ra]++; if(d>gapMax[ra]) gapMax[ra]=d; } if(d<4096) hist[d]++; if(d<4000){ if(d<tmin)tmin=d; if(d>tmax)tmax=d; tsum+=d; tcnt++; sitesum[ra]+=d; sitecnt[ra]++; } }
    if(sndi_addr && z.pc==sndi_addr){ lastTick=z.cyc; }
    if(z.iff1 && !previff) lastEI=z.cyc; previff=z.iff1;
    { int fl=fs_low(z.cyc); if(fl && z.iff1) fsInt=1; if(!prevfs && fl && !z.iff1 && dbgmiss<12 && z.cyc-lastTick>1000){ fprintf(stderr,"FS start DI: frame %d sinceTick %lu lastRA %04X PC %04X\n",frame,z.cyc-lastTick,lastTickRA,z.pc); dbgmiss++; } if(prevfs && !fl){ if(!fsInt){ if(missed<64) misspc[missed]=z.pc; if(missed<6 && frame>10) fprintf(stderr,"MISS frame %d: since EI %lu, sinceTick %lu lastRA %04X\n",frame,z.cyc-lastEI,z.cyc-lastTick,lastTickRA); missed++; } fsInt=0; } prevfs=fl; }
    if(fs_low(z.cyc)) z.int_pending=1, z.int_data=(uint8_t)rand(); else z.int_pending=0;
    if(z.pc==hitaddr && frame>=pf0 && frame<pf1) hits++;
    { unsigned long c0=z.cyc; uint16_t p0=z.pc; z80_step(&z); if(frame>=pf0&&frame<pf1) prof[p0]+=z.cyc-c0; }
    unsigned long pos=z.cyc%FRAME;
    if(!capmid && pos> FSLEN+ 100*TPL){ midl=latch; capmid=1; }
    if(z.cyc>=nextframe){
      fputc(midl,fo); fwrite(mem+0x7000,1,2048,fo); capmid=0;
      if(tlog){ fprintf(tlog,"%d %ld %ld %.1f %ld\n",frame,tmin,tmax,tcnt?tsum/tcnt:0,tcnt); }
      tmin=1e9;tmax=0;tsum=0;tcnt=0;
      if(getenv("DUMPF") && frame==atoi(getenv("DUMPF"))){ FILE*d=fopen("mem.bin","wb"); fwrite(mem,1,65536,d); fclose(d);} 
      nextframe+=FRAME; frame++;
    }
  }
  cyc_now=z.cyc; audio_adv(z.cyc);
  fclose(fo);
  if(wav){ uint32_t dl=nsamp*2; uint8_t h[44]; memcpy(h,"RIFF",4); uint32_t v=36+dl; memcpy(h+4,&v,4); memcpy(h+8,"WAVEfmt ",8); v=16; memcpy(h+16,&v,4); uint16_t s=1; memcpy(h+20,&s,2); memcpy(h+22,&s,2); v=44100; memcpy(h+24,&v,4); v=88200; memcpy(h+28,&v,4); s=2; memcpy(h+32,&s,2); s=16; memcpy(h+34,&s,2); memcpy(h+36,"data",4); memcpy(h+40,&dl,4); fseek(wav,0,SEEK_SET); fwrite(h,1,44,wav); fclose(wav);}
  if(tlog) fclose(tlog);
  if(pf0>=0){ FILE*pp=fopen("prof.txt","w"); for(int i=0;i<65536;i++) if(prof[i]) fprintf(pp,"%04X %lu\n",i,prof[i]); fclose(pp);} 
  if(sndaddr){ FILE*sf=fopen("sites.txt","w"); for(int i=0;i<65536;i++) if(sitecnt[i]) fprintf(sf,"%04X %.1f %ld\n",i,sitesum[i]/sitecnt[i],sitecnt[i]); fclose(sf); }
  if(sndaddr){ FILE*hf=fopen("tickhist.txt","w"); for(int i=0;i<4096;i++) if(hist[i]) fprintf(hf,"%d %ld\n",i,hist[i]); fclose(hf);}
  if(hitaddr>=0) fprintf(stderr,"hits %ld\n",hits);
  fprintf(stderr,"maxgap %lu at RA %04X frame %d, gaps>8000: %d\n",maxgap,maxgapRA,maxgapF,gapcount);
  { FILE*g=fopen("gaps.txt","w"); for(int i=0;i<65536;i++) if(gapRA[i]) fprintf(g,"%04X %ld %lu\n",i,gapRA[i],gapMax[i]); fclose(g);} 
  fprintf(stderr,"missed %ld:",missed); for(int i=0;i<missed&&i<64;i++) fprintf(stderr," %04X",misspc[i]); fprintf(stderr,"\n");
  fprintf(stderr,"done PC=%04X SP=%04X IFF=%d IM=%d cyc=%lu\n",z.pc,z.sp,z.iff1,z.interrupt_mode,z.cyc);
  return 0;
}
