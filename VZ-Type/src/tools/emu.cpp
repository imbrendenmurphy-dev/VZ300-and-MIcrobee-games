// Generic Spectrum / VZ300 emulator harness driven by a command script
#include "z80.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <map>
using z80::fast_u8; using z80::fast_u16; using z80::least_u8;
static bool VZ=false; static unsigned char srbank[2][0x2800]; static int srcur=0; static bool S128=false; static unsigned char banks[8][16384]; static int curbank=0; static unsigned last7ffd=0; static unsigned char *disk=0; static long disklen=0; static int pagelock=0;
class emu : public z80::z80_cpu<emu> {
public:
  typedef z80::z80_cpu<emu> base;
  least_u8 mem[65536];
  unsigned long long t=0; unsigned frame_t=0;
  unsigned frameT() const { return VZ?71136:69888; }
  unsigned char cov[65536]; // executed
  unsigned short wlog_pc[65536]; unsigned char wlog_set[65536];
  bool wlog_on=false; unsigned wlo=0,whi=0;
  std::map<unsigned,unsigned> wcount; // writer pc -> count for range
  unsigned char keys[8]; // spectrum half rows active-high pressed bits / vz rows
  unsigned char joy=0xff, joyarm=0xff; // vz joystick lines (active low)
  unsigned char latch=0; bool romtrap=false; unsigned trap_pc=0;
  std::vector<std::pair<unsigned long long,int>> snd; int lastspk=-1;
  std::map<unsigned,unsigned> portouts;
  bool stop=false; unsigned bp=0x10000; bool bphit=false;
  emu(){ memset(mem,0,sizeof mem); memset(cov,0,sizeof cov); memset(keys,0,8); memset(wlog_set,0,sizeof wlog_set);}
  fast_u8 on_read(fast_u16 a){
    if(VZ && a>=0x6800 && a<0x7000){
      unsigned char r=0x7f; // bit6 cassette in=1? keep 1
      unsigned lo=a&0xff;
      for(int i=0;i<8;i++) if(!(lo&(1<<i))) r&=~keys[i];
      unsigned line=frame_t/228; if(line>=56) r|=0x80;
      return r;
    }
    return mem[a];
  }
  void on_write(fast_u16 a, fast_u8 n){
    if(wlog_on && a>=wlo && a<=whi){ wcount[get_pc()]++; }
    if(VZ){
      if(a<0x4000) return;
      if(a>=0x6800 && a<0x7000){ latch=n; int s=((n&1)^((n>>5)&1))?((n&1)?2:0):1; /* push-pull: equal legs = silent mid level */ if(s!=lastspk){snd.push_back({t,s});lastspk=s;} return; }
    } else if(a<0x4000) return;
    mem[a]=n;
  }
  fast_u8 on_input(fast_u16 port){
    if(VZ){ unsigned p=port&0xff; if(p>=0x20&&p<=0x2f){ unsigned char r=0xff; if(!(p&1)) r&=joy; if(!(p&2)) r&=joyarm; return r;} return 0xff; }
    if((port&1)==0){ unsigned char r=0xbf; unsigned hi=port>>8; for(int i=0;i<8;i++) if(!(hi&(1<<i))) r&=~keys[i]; return r; }
    if((port&0xff)==0x1f) return 0; // kempston none
    return 0xff;
  }
  void on_output(fast_u16 port, fast_u8 n){
    if(VZ){ portouts[port&0xff]++; if((port&0xff)==0x37){ int nb=(n>>1)&1; if(nb!=srcur){ memcpy(srbank[srcur],mem+0x4000,0x2800); memcpy(mem+0x4000,srbank[nb],0x2800); srcur=nb; } } return; }
    if(S128 && (port&0x8002)==0 && !pagelock){ int nb=n&7; if(nb!=curbank){ memcpy(banks[curbank],mem+0xC000,16384); memcpy(mem+0xC000,banks[nb],16384); curbank=nb;} last7ffd=n; if(n&0x20) pagelock=1; return; }
    if((port&1)==0){ int s=(n>>4)&1; if(s!=lastspk){snd.push_back({t,s});lastspk=s;} }
  }
  unsigned prof[65536]; bool profon=false; unsigned long long nexts=0;
  void on_tick(unsigned n){ t+=n; frame_t+=n; if(profon && t>=nexts){ prof[get_pc()]++; nexts=t+97; } }
  fast_u8 on_m1_fetch_cycle(){ unsigned pc=get_pc(); cov[pc]=1; if(!VZ && pc<0x4000 && !(pc>=0x38&&pc<0x3a) && !romtrap){romtrap=true;trap_pc=pc;} if(pc==bp){bphit=true;} return base::on_m1_fetch_cycle(); }
  fast_u8 on_get_int_vector(){ return 0xff; }
  void trdos(){ { unsigned C=get_c(), B=get_b(), D=get_d(), Ee=get_e(), HL=get_hl();
        if(C==5){ for(unsigned i=0;i<B;i++){ long off=((long)D*16+Ee)*256; for(int k=0;k<256;k++) on_write((HL+k)&0xffff, off+k<disklen?disk[off+k]:0); HL+=256; Ee++; if(Ee==16){Ee=0;D++;} }
          mem[0x5cf4]=Ee; mem[0x5cf5]=D; printf("trdos read %u secs -> end %04x page %d\n",B,HL&0xffff,curbank); }
        else printf("trdos fn %u\n",C);
        unsigned sp=get_sp(); unsigned ra=mem[sp]|(mem[(sp+1)&0xffff]<<8); set_sp((sp+2)&0xffff); set_pc(ra); } }
  bool run_frame(){
    // interrupt at frame start
    if(get_iff1()) { on_handle_active_int(); }
    while(frame_t<frameT()){ if(!VZ && disk && get_pc()==0x3d13){ trdos(); continue; } on_step(); if(romtrap||bphit) {return false;} }
    frame_t-=frameT(); return true;
  }
};
static emu E;
int main(int argc,char**argv){
  // usage: emu script
  FILE*f=fopen(argv[1],"r"); char line[1024];
  while(fgets(line,sizeof line,f)){
    char cmd[64]; if(sscanf(line,"%63s",cmd)!=1||cmd[0]=='#') continue;
    std::string c=cmd; char a1[512]="",a2[512]="",a3[512]="";
    sscanf(line,"%*s %511s %511s %511s",a1,a2,a3);
    if(c=="vz") VZ=true;
    else if(c=="loadmem"){ FILE*g=fopen(a1,"rb"); unsigned off=strtoul(a2,0,16); fread(E.mem+off,1,65536-off,g); fclose(g);}
    else if(c=="loadbin"){ FILE*g=fopen(a1,"rb"); unsigned off=strtoul(a2,0,16); size_t n=fread(E.mem+off,1,65536-off,g); fclose(g); printf("loaded %zu at %x\n",n,off);}
    else if(c=="reg"){ unsigned v=strtoul(a2,0,16); std::string r=a1;
      if(r=="pc")E.set_pc(v); else if(r=="sp")E.set_sp(v); else if(r=="i")E.set_i(v); else if(r=="im")E.set_int_mode(v);
      else if(r=="iff"){E.set_iff1(v);E.set_iff2(v);} else if(r=="hl")E.set_hl(v); else if(r=="de")E.set_de(v); else if(r=="bc")E.set_bc(v);
      else if(r=="af")E.set_af(v); else if(r=="ix")E.set_ix(v); else if(r=="iy")E.set_iy(v); }
    else if(c=="poke"){ E.mem[strtoul(a1,0,16)]=strtoul(a2,0,16);}
    else if(c=="key"){ int row=atoi(a1); int bit=atoi(a2); int dn=atoi(a3); if(dn)E.keys[row]|=1<<bit; else E.keys[row]&=~(1<<bit);}
    else if(c=="keysclear"){ memset(E.keys,0,8);}
    else if(c=="joy"){ E.joy=strtoul(a1,0,16); E.joyarm=strtoul(a2,0,16);}
    else if(c=="bp"){ E.bp=strtoul(a1,0,16); E.bphit=false;}
    else if(c=="frames"){ int n=atoi(a1); for(int i=0;i<n;i++){ if(!E.run_frame()){ printf("stopped: romtrap=%d trap=%04x bp=%d pc=%04x frame %d\n",E.romtrap,E.trap_pc,E.bphit,(unsigned)E.get_pc(),i); break;} } }
    else if(c=="steps"){ int n=atoi(a1); for(int i=0;i<n;i++){E.on_step();} }
    else if(c=="dump"){ FILE*g=fopen(a1,"wb"); fwrite(E.mem,1,65536,g); fclose(g);}
    else if(c=="vzshot"){ FILE*g=fopen(a1,"wb"); fwrite(E.mem+0x7000,1,2048,g); fputc(E.latch,g); fclose(g);}
    else if(c=="cov"){ FILE*g=fopen(a1,"wb"); fwrite(E.cov,1,65536,g); fclose(g);}
    else if(c=="covclear"){ memset(E.cov,0,65536);}
    else if(c=="wlog"){ E.wlog_on=true; E.wlo=strtoul(a1,0,16); E.whi=strtoul(a2,0,16); E.wcount.clear();}
    else if(c=="wlogdump"){ for(auto&p:E.wcount) printf("writer %04x x%u\n",p.first,p.second); E.wlog_on=false;}
    else if(c=="snd"){ FILE*g=fopen(a1,"w"); for(auto&p:E.snd) fprintf(g,"%llu %d\n",p.first,p.second); fclose(g); E.snd.clear();}
    else if(c=="sndclear"){ E.snd.clear();}
    else if(c=="regs"){ printf("PC=%04x SP=%04x AF=%04x BC=%04x DE=%04x HL=%04x IX=%04x IY=%04x I=%02x IM=%u IFF=%d t=%llu\n",(unsigned)E.get_pc(),(unsigned)E.get_sp(),(unsigned)E.get_af(),(unsigned)E.get_bc(),(unsigned)E.get_de(),(unsigned)E.get_hl(),(unsigned)E.get_ix(),(unsigned)E.get_iy(),(unsigned)E.get_i(),E.get_int_mode(),(int)E.get_iff1(),E.t);}
    else if(c=="ports"){ for(auto&p:E.portouts) printf("port %02x x%u\n",p.first,p.second);}
    else if(c=="loadvz"){ FILE*g=fopen(a1,"rb"); unsigned char h[24]; fread(h,1,24,g); unsigned st=h[22]|h[23]<<8; size_t n=fread(E.mem+st,1,65536-st,g); fclose(g); E.set_pc(st); printf("vz loaded %zu bytes at %04x\n",n,st);}
    else if(c=="pokep"){ unsigned a=strtoul(a1,0,16); unsigned p=E.mem[a]|E.mem[a+1]<<8; if(p) E.mem[(p+strtoul(a2,0,16))&0xffff]=strtoul(a3,0,16);}
    else if(c=="profon"){ memset(E.prof,0,sizeof E.prof); E.profon=true; }
    else if(c=="profdump"){ FILE*g=fopen(a1,"wb"); fwrite(E.prof,sizeof(unsigned),65536,g); fclose(g); E.profon=false; }
    else if(c=="peek"){ unsigned a=strtoul(a1,0,16); int n=atoi(a2); if(!n)n=1; printf("%04x:",a); for(int i=0;i<n;i++) printf(" %02x",E.mem[(a+i)&0xffff]); printf("\n");}
    else if(c=="spec128"){ S128=true; }
    else if(c=="disk"){ FILE*g=fopen(a1,"rb"); fseek(g,0,SEEK_END); disklen=ftell(g); fseek(g,0,SEEK_SET); disk=(unsigned char*)malloc(disklen); fread(disk,1,disklen,g); fclose(g);}
    else if(c=="dump128"){ memcpy(banks[curbank],E.mem+0xC000,16384); memcpy(banks[5],E.mem+0x4000,16384); memcpy(banks[2],E.mem+0x8000,16384); FILE*g=fopen(a1,"wb"); fwrite(banks,1,sizeof banks,g); fclose(g); printf("dump128 cur bank %d 7ffd=%02x\n",curbank,last7ffd);}
    else if(c=="load128"){ FILE*g=fopen(a1,"rb"); fread(banks,1,sizeof banks,g); fclose(g); curbank=strtoul(a2,0,16)&7; last7ffd=strtoul(a2,0,16); memcpy(E.mem+0x4000,banks[5],16384); memcpy(E.mem+0x8000,banks[2],16384); memcpy(E.mem+0xC000,banks[curbank],16384);}
    else if(c=="echo"){ printf("%s",line+5);}
    fflush(stdout);
  }
}
