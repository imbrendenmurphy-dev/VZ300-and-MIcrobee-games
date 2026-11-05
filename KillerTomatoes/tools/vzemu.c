// vzemu - headless VZ300 test harness (Z80 core: superzazu/z80)
// Models: 16K stock RAM ($7800-$B7FF) or full 64K (-big), MC6847 mode0/mode1 render,
// $6800 keyboard/latch with field-sync bit 7, 312-line PAL frame, speaker capture, joystick ports.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "z80.h"

static uint8_t mem[65536];
static int big=0, latch=0, frame=0;
static uint8_t keyrow[8]; // active-low bits 0..5
static uint8_t joy=0xff;  // active-low bits 0..4
static int fs_low=0;
static long long tstate=0;
static int badw=0, badr=0;
static FILE *wav; static int spk=0; static double sacc=0; static long wsamples=0;
#define TPL 227
#define LINES 312
static int writes_active[2048];

static int ramok(uint16_t a){ if(a>=0x7000&&a<0x7800) return 1; if(big) return a>=0x7800 && a<0xF800; return a>=0x7800&&a<0xB800; }
static uint8_t rd(void*u,uint16_t a){
  if(a>=0x6800&&a<0x7000){ uint8_t r=0x3f; for(int i=0;i<8;i++) if(!(a&(1<<i))) r&=keyrow[i]; r|=0x40; if(!fs_low) r|=0x80; return r; }
  if(a<0x4000) return mem[a];
  if(!ramok(a)){ badr++; return 0xff; }
  return mem[a];
}
static int curpc; static long long fsfall=0; static long long lateW=0; static int lateF=0, lateFrames=0; static int line; static int wlo=1,whi=0,nw=0; static int tracelatch=0;
static void wr(void*u,uint16_t a,uint8_t v){
  if(a>=0x6800&&a<0x7000){ if(tracelatch && (v&0x18)!=(latch&0x18)) fprintf(stderr,"latch %02X at pc %04X addr %04X frame %d\n",v,curpc,a,frame); latch=v; return; }
  if(!ramok(a)){ if(a>=0x4000) badw++; if(badw<5 && a>=0x4000) fprintf(stderr,"bad write %04X frame %d\n",a,frame); return; }
  if(a>=wlo && a<=whi && nw<30){ nw++; fprintf(stderr,"WRITE %04X=%02X pc %04X frame %d\n",a,v,curpc,frame); }
  if(a>=0x7000 && a<0x7800 && fsfall && line<192){ int py=(a-0x7000)/32; if(line>py*3+2 && mem[a]!=v) { lateW++; lateF=1; } }
  mem[a]=v;
}
static uint8_t pin(z80*z,uint8_t p){ if((p&0xf0)==0x20){ return joy; } return 0xff; }
static void pout(z80*z,uint8_t p,uint8_t v){}

static const uint8_t pal[2][4][3]={{{0,255,0},{255,255,0},{0,0,255},{255,0,0}},{{255,255,255},{0,255,255},{255,0,255},{255,128,0}}};
static uint8_t font[64][8]; static int bp=-1,nbp=0; static uint16_t ring[64]; static int ri=0, crashed=0, spbad=0; static int markpc=-1, fspc=-1; static unsigned long long prof[65536]; static char*proff=0; static long long dmax=0,dsum=0,dn=0,late=0,hist[8];
static void mkfont(){ // crude font: draw boxes for letters (screenshots of mode0 only need legibility via text dump)
  for(int c=0;c<64;c++) for(int y=0;y<8;y++) font[c][y]= (c==32)?0: ((y==0||y==7)?0:0x3c);
}
static void shot(const char*fn){
  FILE*f=fopen(fn,"wb"); int W=256,H=192; fprintf(f,"P6 %d %d 255\n",W,H);
  int css=(latch>>4)&1;
  for(int y=0;y<H;y++) for(int x=0;x<W;x++){
    uint8_t c[3];
    if(latch&8){ int px=x/2, py=y/3; uint8_t b=mem[0x7000+py*32+px/4]; int v=(b>>(6-2*(px&3)))&3; memcpy(c,pal[css][v],3); }
    else { int cx=x/8, cy=y/12; uint8_t ch=mem[0x7000+cy*32+cx];
      if(ch&0x80){ int q=((y%12)/6)*2+((x%8)/4); int bit=(q==0)?3:(q==1)?2:(q==2)?1:0; int col=(ch>>4)&7;
        static const uint8_t sg[8][3]={{0,255,0},{255,255,0},{0,0,255},{255,0,0},{255,255,255},{0,255,255},{255,0,255},{255,128,0}};
        if(ch&(1<<bit)) memcpy(c,sg[col],3); else {c[0]=c[1]=c[2]=0;} }
      else { int on=font[ch&63][(y%12)*8/12]&(0x80>>(x%8)); int inv=ch&0x40; if(inv) on=!on; if(on){c[0]=0;c[1]=255;c[2]=0;} else {c[0]=0;c[1]=64;c[2]=0;} } }
    fwrite(c,1,3,f);
  }
  fclose(f);
}
static void textdump(){ for(int r=0;r<16;r++){ for(int c=0;c<32;c++){ uint8_t ch=mem[0x7000+r*32+c]; char o; if(ch&0x80) o='#'; else { int k=ch&63; o= k<32? '@'+k : k; } putchar(o);} putchar('\n'); } }

struct ev{int f; int row,bit,down; int joy; int jv;} evs[4096]; int nev=0;
static int keymap(const char*n,int*row,int*bit){
  static const char* rows[8][6]={{"T","W",0,"E","Q","R"},{"G","S","CTRL","D","A","F"},{"B","X","SHIFT","C","Z","V"},
   {"5","2",0,"3","1","4"},{"N","PERIOD",0,"COMMA","SPACE","M"},{"6","9","MINUS","8","0","7"},{"Y","O","RETURN","I","P","U"},{"H","L","COLON","K","SEMI","J"}};
  for(int r=0;r<8;r++) for(int b=0;b<6;b++) if(rows[r][b]&&!strcmp(rows[r][b],n)){*row=r;*bit=b;return 1;}
  return 0;
}
int main(int argc,char**argv){
  if(argc<2){fprintf(stderr,"usage: vzemu file.vz [-f frames] [-i input] [-s f1,f2..] [-o prefix] [-big] [-idle lo-hi] [-w wav] [-d dumpfile] [-t textframe]\n");return 1;}
  int frames=300;  char*inp=0,*shots=0,*pre="shot",*wavf=0,*dumpf=0; int idlelo=-1,idlehi=-1; int textf=-1;
  for(int i=2;i<argc;i++){
    if(!strcmp(argv[i],"-f")) frames=atoi(argv[++i]);
    else if(!strcmp(argv[i],"-i")) inp=argv[++i];
    else if(!strcmp(argv[i],"-s")) shots=argv[++i];
    else if(!strcmp(argv[i],"-o")) pre=argv[++i];
    else if(!strcmp(argv[i],"-big")) big=1;
    else if(!strcmp(argv[i],"-wav")) wavf=argv[++i];
    else if(!strcmp(argv[i],"-d")) dumpf=argv[++i];
    else if(!strcmp(argv[i],"-t")) textf=atoi(argv[++i]);
    else if(!strcmp(argv[i],"-bp")) bp=strtol(argv[++i],0,16);
    else if(!strcmp(argv[i],"-w")) { sscanf(argv[++i],"%x-%x",&wlo,&whi); }
    else if(!strcmp(argv[i],"-mark")) sscanf(argv[++i],"%x",&markpc);
    else if(!strcmp(argv[i],"-fs")) sscanf(argv[++i],"%x",&fspc);
    else if(!strcmp(argv[i],"-prof")) proff=argv[++i];
    else if(!strcmp(argv[i],"-tl")) tracelatch=1;
    else if(!strcmp(argv[i],"-idle")) sscanf(argv[++i],"%x-%x",&idlelo,&idlehi);
  }
  memset(keyrow,0x3f,8); mkfont();
  // fake ROM: 2EF4 -> LD A,($3000): RET (key for original game title wait)
  mem[0x2EF4]=0x3A; mem[0x2EF5]=0x00; mem[0x2EF6]=0x30; mem[0x2EF7]=0xC9;
  mem[0x38]=0xFB; mem[0x39]=0xED; mem[0x3A]=0x4D; // EI;RETI for IM1
  FILE*f=fopen(argv[1],"rb"); uint8_t buf[65536]; int n=fread(buf,1,65536,f); fclose(f);
  int start=buf[22]|buf[23]<<8; int len=n-24;
  for(int i=0;i<len;i++){ uint16_t a=start+i; if(!ramok(a)){fprintf(stderr,"LOAD outside RAM at %04X\n",a); return 2;} mem[a]=buf[24+i]; }
  fprintf(stderr,"loaded %04X-%04X (%d bytes) type %02X\n",start,start+len-1,len,buf[21]);
  if(inp){ FILE*fi=fopen(inp,"r"); char k[32],d[16]; int fr; while(fscanf(fi,"%d %31s %15s",&fr,k,d)==3){ struct ev*e=&evs[nev++]; e->f=fr; e->joy=0;
      if(!strcmp(k,"JOY")){ e->joy=1; e->jv=strtol(d,0,16); }
      else if(!strcmp(k,"ASCII")){ e->joy=2; e->jv=atoi(d); }
      else { if(!keymap(k,&e->row,&e->bit)){fprintf(stderr,"bad key %s\n",k);return 3;} e->down=!strcmp(d,"down"); } } fclose(fi); }
  int shotf[256],ns=0; if(shots){ char*s=strdup(shots); for(char*t=strtok(s,",");t;t=strtok(0,",")) shotf[ns++]=atoi(t); }
  if(wavf){ wav=fopen(wavf,"wb"); uint8_t h[44]={0}; fwrite(h,1,44,wav); }
  z80 z; z80_init(&z); z.read_byte=rd; z.write_byte=wr; z.port_in=pin; z.port_out=pout; z.pc=start; z.sp=0x7A00;
  if(buf[21]==0xF0) { z.pc=start; }
  long long ft0=0; int maxbusy=0; long long busysum=0;
  for(frame=0;frame<frames;frame++){
    for(int e=0;e<nev;e++) if(evs[e].f==frame){ if(evs[e].joy==1) joy=evs[e].jv; else if(evs[e].joy==2) mem[0x3000]=evs[e].jv; else { if(evs[e].down) keyrow[evs[e].row]&=~(1<<evs[e].bit); else keyrow[evs[e].row]|=(1<<evs[e].bit);} }
    long long idle=0; if(lateF) lateFrames++; lateF=0;
    for(line=0;line<LINES;line++){
      fs_low=(line>=192&&line<248); if(line==192) fsfall=tstate;
      long long tend=(long long)(frame*LINES+line+1)*TPL;
      while(tstate<tend){
        if(fs_low && z.iff1) z80_gen_int(&z,0xff);
        unsigned long c0=z.cyc; uint16_t pc=z.pc; ring[ri++&63]=pc; if(pc<0x7000 && !crashed){crashed=1; fprintf(stderr,"CRASH frame %d pc %04X sp %04X trail:",frame,pc,z.sp); for(int k=0;k<64;k++) fprintf(stderr," %04X",ring[(ri+k)&63]); fprintf(stderr,"\n");} if(z.sp<0xF800 && z.sp>0x9000 && !spbad){spbad=1; fprintf(stderr,"SPLOW frame %d pc %04X sp %04X trail:",frame,pc,z.sp); for(int k=0;k<64;k++) fprintf(stderr," %04X",ring[(ri+k)&63]); fprintf(stderr,"\n");} if(pc==markpc && fsfall){ long long d=tstate-fsfall; if(d>dmax)dmax=d; dsum+=d; dn++; int b=d/5000; if(b>7)b=7; hist[b]++; fsfall=0;} if(pc==fspc) late++; curpc=pc; if(pc==bp && nbp<40){ nbp++; fprintf(stderr,"BP %04X f%d A=%02X BC=%02X%02X DE=%02X%02X HL=%02X%02X IX=%04X SP=%04X\n",pc,frame,z.a,z.b,z.c,z.d,z.e,z.h,z.l,z.ix,z.sp);} z80_step(&z); int dt=z.cyc-c0; tstate+=dt;
        if(pc>=idlelo&&pc<=idlehi) idle+=dt; if(proff) prof[pc]+=dt;
        if(wav){ int s=((latch&1)?1:0)-((latch&32)?1:0); sacc+=dt; while(sacc>=80.4){ sacc-=80.4; int16_t v=s*8000; fwrite(&v,2,1,wav); wsamples++; } }
      }
      if(line==191){ for(int s=0;s<ns;s++) if(shotf[s]==frame){ char fn[256]; sprintf(fn,"%s_%05d.ppm",pre,frame); shot(fn);} if(frame==textf) textdump(); }
    }
    if(idlelo>=0 && frame>5){ int busy=100-(int)(idle*100/(LINES*TPL)); busysum+=busy; if(busy>maxbusy) maxbusy=busy; }
  }
  if(dn) { fprintf(stderr,"draw T: max %lld avg %lld n %lld sync-calls %lld beam-late writes %lld frames %d hist(5K):",dmax,dsum/dn,dn,late,lateW,lateFrames); for(int k=0;k<8;k++) fprintf(stderr," %lld",hist[k]); fprintf(stderr,"\n"); }
  if(idlelo>=0) fprintf(stderr,"busy%%: max %d avg %lld\n",maxbusy,busysum/(frames>6?frames-6:1));
  fprintf(stderr,"end pc=%04X sp=%04X badw=%d badr=%d latch=%02X\n",z.pc,z.sp,badw,badr,latch);
  if(wav){ uint32_t ds=wsamples*2; fseek(wav,0,0); uint8_t h[44]="RIFF"; uint32_t v; v=36+ds; memcpy(h+4,&v,4); memcpy(h+8,"WAVEfmt ",8); v=16; memcpy(h+16,&v,4); uint16_t s=1; memcpy(h+20,&s,2); memcpy(h+22,&s,2); v=44100; memcpy(h+24,&v,4); v=88200; memcpy(h+28,&v,4); s=2; memcpy(h+32,&s,2); s=16; memcpy(h+34,&s,2); memcpy(h+36,"data",4); memcpy(h+40,&ds,4); fwrite(h,1,44,wav); fclose(wav); }
  if(proff){ FILE*p=fopen(proff,"wb"); fwrite(prof,8,65536,p); fclose(p);} 
  if(dumpf){ FILE*d=fopen(dumpf,"wb"); fwrite(mem,1,65536,d); fclose(d); }
  return 0;
}
