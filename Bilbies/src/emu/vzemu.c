// VZ300 + BennVenn SD/128K emulator harness for testing.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "z80.h"

#define LINES 312
#define LINET 228
static int FRAMET = LINES * LINET;   // VZ_SKEW env adds T-states per frame (timing robustness tests)
#define FSLINES 56
#define ACTIVE_START 64   // first active display line (approx)

static uint8_t rom[0x4000];
static uint8_t ram[0x10000];     // internal: 7000-B7FF used (video 7000-77FF)
static uint8_t bv[0x20000];      // BennVenn 128K: dos banks 0x00000/0x08000, exp banks 0x10000/0x18000
static uint8_t mapper = 0, vz300mode = 1;
static uint8_t latch = 0;
static uint8_t keys[8];          // active low rows (bits 0-5)
static uint8_t joy[4] = {0xff, 0xff, 0xff, 0xff}; // j1 dir, j2 dir, j1 arm, j2 arm (active low bits)
static z80 cpu;
static unsigned long long tstate = 0;  // global
static unsigned long frames = 0;
static int fs_low = 0;
static uint16_t curpc;
static unsigned long prof[65536]; static int profon = 0;
static uint8_t bpmap[65536]; static FILE *bplog = 0; static int bpmem = -1;
static uint8_t cov[65536]; static int covon = 0;
static uint8_t watchw[65536]; static FILE *wlog = 0;
static int halted_badly = 0;
// speaker capture
static int spk = 0; static FILE *wavf = 0; static unsigned long long wav_t = 0; static long wav_n = 0;
static double wav_acc = 0;
static uint8_t rb(void *u, uint16_t a); static void wb(void *u, uint16_t a, uint8_t v);
static char sddir[256] = "."; static FILE *sdf = 0; static unsigned long sdcalls = 0;
static void dos_trap(void) {
  uint16_t pc = cpu.pc; uint16_t buf = rb(0,0xFB80) | rb(0,0xFB81) << 8;
  if (pc == 0x5F00) {
    char name[64]; int n = 0; uint16_t p = (cpu.h << 8) | cpu.l; if (rb(0,p) == '"') p++;
    while (n < 60) { uint8_t c = rb(0,p++); if (c == '"' || c == 0) break; name[n++] = c; } name[n] = 0;
    char fn[400]; snprintf(fn, sizeof fn, "%s/%s.DAT", sddir, name);
    if (sdf) fclose(sdf); sdf = fopen(fn, "rb");
    wb(0,0xFB03, sdf ? 1 : 0); wb(0,0xFB05, 0);
    if (sdcalls++ < 200) fprintf(stderr, "DOS open %s -> %s (frame %lu)\n", fn, sdf ? "ok" : "MISSING", frames);
  } else {
    uint8_t d[512]; memset(d, 0, 512); if (sdf) fread(d, 1, 512, sdf);
    for (int i = 0; i < 512; i++) wb(0, buf + i, d[i]);
  }
  uint16_t r = rb(0,cpu.sp) | rb(0,cpu.sp + 1) << 8; cpu.sp += 2; cpu.pc = r;
}
static int trapmode = 0; static unsigned long traps = 0;
#define RING 20000
static uint16_t rpc[RING], rsp[RING], raf[RING], rhl[RING], rde[RING], rbc[RING]; static int rpos = 0; static int crashpc = -1; static int crlo = 1, crhi = 0; static int crashed = 0;

static uint8_t *bvptr(uint16_t a) {
  if (a >= 0x4000 && a < 0x6800) return &bv[((mapper & 2) ? 0x8000 : 0) + (a - 0x4000)];
  if (a >= 0x9000) { if (vz300mode && a < 0xb800) return 0; return &bv[((mapper & 4) ? 0x18000 : 0x10000) + (a & 0x7fff)]; }
  return 0;
}
static int protect=0; static unsigned long protviol=0;
static uint8_t rb(void *u, uint16_t a) {
  if (covon) cov[a] |= 2;
  if (a < 0x4000) { return rom[a]; }
  if (a < 0x6800) { if (mapper & 1) return *bvptr(a); return 0xff; }
  if (a < 0x7000) {
    uint8_t r = 0x3f; uint8_t lo = a & 0xff;
    for (int i = 0; i < 8; i++) if (!(lo & (1 << i))) r &= keys[i];
    r |= 0x40; if (!fs_low) r |= 0x80;
    return r;
  }
  if (a < 0xb800) return ram[a];
  uint8_t *p = bvptr(a); return p ? *p : 0xff;
}
static uint8_t gprot[65536], gspec[65536]; static int gon=0; static unsigned long gviol=0;
static void wb(void *u, uint16_t a, uint8_t v) {
  if (gon && gprot[a] && gspec[curpc]) { if (gviol++ < 40) fprintf(stderr,"GUARD write %04X=%02X by PC %04X frame %lu\n",a,v,curpc,frames); }
  if (covon) cov[a] |= 4;
  if (watchw[a] && wlog) fprintf(wlog, "%lu PC=%04X W %04X=%02X\n", frames, curpc, a, v);
  if (a < 0x4000) { if (trapmode) { traps++; if (traps < 20) fprintf(stderr, "ROM write %04X at PC %04X\n", a, curpc); } return; }
  if (a < 0x6800) { *bvptr(a) = v; return; }
  if (a < 0x7000) {
    int ns = ((v >> 5) & 1) ^ (v & 1) ? ((v >> 5) & 1) : spk; // speaker level from bit5 (bit0 complement)
    spk = (v >> 5) & 1; (void)ns;
    latch = v; return;
  }
  if (a < 0xb800) { ram[a] = v; return; }
  uint8_t *p = bvptr(a); if (p) *p = v;
}

static int g_inj=-1; static uint16_t g_demobuf=0;
static FILE *lsin=0,*lsout=0; static unsigned long lsi=0, lsraw0=0, lstr=0; static FILE *lstrf=0; static unsigned long lsdn=0, lsskip=0; static char lsdfn[200];
static void ls_hook(uint16_t pc, uint8_t (*R)(void*,uint16_t), void (*Wr)(void*,uint16_t,uint8_t)) { (void)pc;(void)R;(void)Wr; }
static uint8_t pin(z80 *z, uint16_t p) {
  uint8_t lo = p & 0xff;
  if (lo >= 0x20 && lo <= 0x2f) {
    uint8_t r = 0xff;
    if (!(lo & 1)) r &= joy[0];
    if (!(lo & 2)) r &= joy[1];
    if (!(lo & 4)) r &= joy[2];
    if (!(lo & 8)) r &= joy[3];
    return r;
  }
  return 0xff;
}
static void pout(z80 *z, uint16_t p, uint8_t v) {
  uint8_t lo = p & 0xff;
  if (lo == 0x37) mapper = v;
  else if (lo == 0x3a) vz300mode = v & 1;
}

static double wav_hi = 0; static unsigned long long wav_last = 0;
static void wav_advance(unsigned long long t) {
  if (!wavf) return;
  // 44100 Hz, box-filtered (speaker level integrated over each sample)
  const double tps = 3546875.0 / 44100.0;
  if (wav_last < wav_t) wav_last = wav_t;
  while (1) {
    double end = wav_t + tps;
    if ((double)t < end) { if (spk) wav_hi += (double)(t - wav_last); wav_last = t; break; }
    if (spk) wav_hi += end - (double)wav_last;
    double f = wav_hi / tps; int16_t s = (int16_t)((f * 2 - 1) * 12000);
    fwrite(&s, 2, 1, wavf); wav_n++;
    wav_hi = 0; wav_t = (unsigned long long)end; wav_last = wav_t;
  }
}


static int d68inj=-1; static FILE *d68f=0, *d68log=0; static unsigned long d68n=0; static unsigned long d68dump=0; static char d68dfn[256];
static int d68_hook(void) {
  if ((!d68f && d68inj<0) || cpu.pc != 0xD68B) return 0;
  int v=0; if (d68inj>=0) v=d68inj; else if (fscanf(d68f,"%d",&v)!=1) v=0;
  d68n++;
  cpu.l = (v&1)?0xFD:((v&2)?0x03:0); cpu.h = (v&8)?0xFD:((v&4)?0x03:0); cpu.e=(v&16)?1:0; cpu.d=(v&32)?1:0;
  if (d68log) { uint32_t h=2166136261u; for (int a=0x8000;a<0x8096;a++){ h^=rb(0,a); h*=16777619u; } for (int a=0x88C0;a<0x8920;a++){ h^=rb(0,a); h*=16777619u; }
    fprintf(d68log,"%lu %08X sc=",d68n,h); for(int a=0xD0FC;a<0xD104;a++) fprintf(d68log,"%d",rb(0,a)); fprintf(d68log," top=%02X%02X\n",rb(0,0x80E1),rb(0,0x80E0)); }
  if (d68dump && d68n==d68dump) { FILE *g=fopen(d68dfn,"wb"); for (int a=0;a<65536;a++) fputc(rb(0,a),g); fclose(g); }
  uint16_t r = rb(0,cpu.sp) | rb(0,(uint16_t)(cpu.sp+1))<<8; cpu.sp += 2; cpu.pc = r;
  return 1;
}
static unsigned long fstart = 0;
static unsigned long a360 = 0;
// one emulation step; returns 0 at a frame boundary (nothing executed)
static int emu_step(void) {
  if (cpu.cyc - fstart >= FRAMET) { tstate += cpu.cyc - fstart; frames++; fstart = cpu.cyc; return 0; }
  int line = (cpu.cyc - fstart) / LINET;
  fs_low = line < FSLINES;
  if (fs_low) { if (!cpu.int_pending) z80_gen_int(&cpu, 0xff); } else cpu.int_pending = 0;
  unsigned long c0 = cpu.cyc;
  curpc = cpu.pc;
  if (crashpc >= 0) { rpc[rpos]=curpc; rsp[rpos]=cpu.sp; raf[rpos]=(cpu.a<<8); rhl[rpos]=(cpu.h<<8)|cpu.l; rde[rpos]=(cpu.d<<8)|cpu.e; rbc[rpos]=(cpu.b<<8)|cpu.c; rpos=(rpos+1)%RING;
    if ((curpc == crashpc || (curpc >= crlo && curpc <= crhi)) && !crashed) { crashed=1; FILE *g=fopen("crash.txt","w"); for(int i=0;i<RING;i++){int k=(rpos+i)%RING; fprintf(g,"%04X SP=%04X A=%02X BC=%04X DE=%04X HL=%04X\n",rpc[k],rsp[k],raf[k]>>8,rbc[k],rde[k],rhl[k]);} fclose(g); fprintf(stderr,"crash trace written at frame %lu\n",frames);} }
  if (d68_hook()) return 1;
  if (covon) cov[curpc] = 1;
  ls_hook(curpc,rb,wb);
  if (!(mapper & 2) && (curpc == 0x5F00 || curpc == 0x5F03 || curpc == 0x5F09)) { dos_trap(); return 1; }
  if (bpmap[curpc] && bplog) {
    fprintf(bplog, "%lu L%d %04X A=%02X BC=%04X DE=%04X HL=%04X IX=%04X IY=%04X SP=%04X |", frames, line, curpc, cpu.a, (cpu.b << 8) | cpu.c, (cpu.d << 8) | cpu.e, (cpu.h << 8) | cpu.l, cpu.ix, cpu.iy, cpu.sp);
    for (int q = 0; q < 8; q++) fprintf(bplog, " %02X", rb(0, cpu.sp + q)); if (bpmem>=0) { fprintf(bplog, " M="); for (int q=0;q<8;q++) fprintf(bplog,"%02X ", rb(0,bpmem+q)); fprintf(bplog," IX28="); for(int q=28;q<32;q++) fprintf(bplog,"%02X ",rb(0,cpu.ix+q)); } fprintf(bplog, "\n");
  }
  if (curpc == 0xA360) a360++;
  z80_step(&cpu);
  int d = cpu.cyc - c0;
  if (profon) prof[curpc] += d;
  wav_advance(tstate + (cpu.cyc - fstart));
  return 1;
}
static void run_frames(int n) {
  unsigned long target = frames + n;
  while (frames < target) emu_step();
}
// run until A360 has been executed k more times (stops just before the next one)
static void run_iters(int k) {
  unsigned long t = a360 + k;
  while (1) { if (a360 >= t && cpu.pc == 0xA360) break; emu_step(); }
}

// ---- snapshots + demo search ----------------------------------------------
typedef struct { z80 cpu; uint8_t ram[0x10000]; uint8_t bv[0x20000]; uint8_t mapper, vz300mode, latch; unsigned long long tstate; unsigned long frames, fstart, a360; int fs_low, spk; } snap_t;
static void snap_save(snap_t *s) { s->cpu=cpu; memcpy(s->ram,ram,sizeof ram); memcpy(s->bv,bv,sizeof bv); s->mapper=mapper; s->vz300mode=vz300mode; s->latch=latch; s->tstate=tstate; s->frames=frames; s->fstart=fstart; s->a360=a360; s->fs_low=fs_low; s->spk=spk; }
static void snap_load(snap_t *s) { cpu=s->cpu; memcpy(ram,s->ram,sizeof ram); memcpy(bv,s->bv,sizeof bv); mapper=s->mapper; vz300mode=s->vz300mode; latch=s->latch; tstate=s->tstate; frames=s->frames; fstart=s->fstart; a360=s->a360; fs_low=s->fs_low; spk=s->spk; }
#define VBITS (1<<16)
typedef struct { snap_t *s; uint8_t vis[VBITS/8]; int nvis; int score; int npairs; uint8_t pairs[600]; int alive; double val; int kx, ky; } beam_t;
static uint32_t view_hash(void) {   // the game's char window (36 x 20 at $9E86)
  uint32_t h = 2166136261u;
  for (int i = 0; i < 36*20; i++) { h ^= rb(0, 0x9E86 + i); h *= 16777619u; }
  if (!g_demobuf) { h ^= (rb(0,0x5CB2)>>3) * 131 + (rb(0,0x5CB6)>>3); h *= 16777619u; }
  return h;
}
static int bcd_score(void) { int v=0; for (int a=0x6146;a<=0x6149;a++){ uint8_t b=rb(0,a); v=v*100+((b>>4)&15)*10+(b&15);} return v; }
static uint16_t g_lives = 0x6145; static int g_tx = -1, g_ty = -1;
static int cmpbeam(const void *a, const void *b) { double x=((beam_t*)a)->val, y=((beam_t*)b)->val; return x<y ? 1 : x>y ? -1 : 0; }
static void dsearch(const char *out, int iters, int K, int W, unsigned seed) {
  static const uint8_t cand[] = {0x02,0x01,0x0A,0x09,0x12,0x11,0x1A,0x19,0x08,0x10,0x00};
  int NC = sizeof cand;
  srand(seed);
  beam_t *beam = calloc(W, sizeof(beam_t)); beam_t *nb = calloc(W*NC, sizeof(beam_t));
  for (int i = 0; i < W*NC; i++) nb[i].s = malloc(sizeof(snap_t));
  for (int i = 0; i < W; i++) beam[i].s = malloc(sizeof(snap_t));
  snap_save(beam[0].s); beam[0].alive=1; beam[0].npairs=0; int nbeam = 1;
  int lives0 = rb(0, g_lives);
  for (int seg = 0; seg * K < iters; seg++) {
    int k = K; if ((seg+1)*K > iters) k = iters - seg*K;
    int nn = 0;
    for (int b = 0; b < nbeam; b++) for (int c = 0; c < NC; c++) {
      beam_t *n = &nb[nn];
      snap_load(beam[b].s);
      memcpy(n->vis, beam[b].vis, sizeof n->vis); n->nvis = beam[b].nvis; n->npairs = beam[b].npairs; memcpy(n->pairs, beam[b].pairs, sizeof n->pairs);
      uint16_t p = g_demobuf + 2 + 2*n->npairs;           // after the leading (1,0)
      if (g_demobuf) { wb(0, p, k); wb(0, p+1, cand[c]); wb(0, p+2, k); wb(0, p+3, cand[c]); wb(0, p+4, 0); }
      else g_inj = cand[c];                                 // direct injection (screenshot runs)
      n->pairs[2*n->npairs] = k; n->pairs[2*n->npairs+1] = cand[c]; n->npairs++;
      int alive = 1;
      for (int i = 0; i < k; i++) {
        run_iters(1);
        uint32_t h = view_hash() & (VBITS-1);
        if (!(n->vis[h>>3] & (1<<(h&7)))) { n->vis[h>>3] |= 1<<(h&7); n->nvis++; }
        if (rb(0, g_lives) < lives0) { alive = 0; break; }
      }
      n->alive = alive; n->score = bcd_score(); n->kx = rb(0,0x5CB2); n->ky = rb(0,0x5CB6);
      if (g_tx >= 0) { int kx = rb(0,0x5CB2)|rb(0,0x5CB3)<<8, ky = rb(0,0x5CB4)|rb(0,0x5CB5)<<8; n->kx = kx; n->ky = ky;
        n->val = alive ? -(abs(kx-g_tx) + abs(ky-g_ty)) * 1.0 + n->nvis * 1.5 + (rand()%100)/1000.0 : -1e9; }
      else n->val = alive ? n->nvis * 30.0 + n->score / 50.0 + (rand() % 100) / 1000.0 : -1e9;
      if (alive) snap_save(n->s);
      nn++;
    }
    qsort(nb, nn, sizeof(beam_t), cmpbeam);
    int w = 0;
    for (int i = 0; i < nn && w < W; i++) if (nb[i].alive) {
      int dup = 0;   // keep diversity: one entry per (position, score, views)
      for (int j = 0; j < w; j++) if (beam[j].kx==nb[i].kx && beam[j].ky==nb[i].ky && beam[j].score==nb[i].score && beam[j].nvis==nb[i].nvis) dup = 1;
      if (dup) continue;
      snap_t *tmp = beam[w].s; beam[w] = nb[i]; beam[w].s = tmp; memcpy(beam[w].s, nb[i].s, sizeof(snap_t)); w++;
    }
    if (!w) { fprintf(stderr, "dsearch: all candidates died at segment %d\n", seg); break; }
    nbeam = w;
    if (seg % 10 == 0) fprintf(stderr, "seg %d best val %.1f views %d score %d\n", seg, beam[0].val, beam[0].nvis, beam[0].score);
  }
  // merge equal consecutive runs, write stream: 1,0, pairs..., 0
  FILE *g = fopen(out, "wb"); fputc(1, g); fputc(0, g);
  int n = beam[0].npairs; uint8_t *pp = beam[0].pairs; int i = 0;
  while (i < n) { int cnt = pp[2*i], v = pp[2*i+1]; while (i+1 < n && pp[2*i+3] == v && cnt + pp[2*i+2] <= 255) { i++; cnt += pp[2*i]; } fputc(cnt, g); fputc(v, g); i++; }
  fputc(0, g); fclose(g);
  fprintf(stderr, "dsearch done: views %d score %d pairs %d\n", beam[0].nvis, beam[0].score, n);
  snap_load(beam[0].s);
}


// ---- demo search over inputs injected at D68B (Xevious) ----
static int xscore(void){ int v=0; for(int a=0xD0FC;a<0xD104;a++) v=v*10+rb(0,a); return v; }
typedef struct { snap_t *s; int alive, score, np; unsigned long d68; uint8_t pairs[1200]; double val; int x,y; } xb_t;
static int xcmp(const void*a,const void*b){ double x=((xb_t*)a)->val,y=((xb_t*)b)->val; return x<y?1:x>y?-1:0; }
static void xsearch(const char *out, int iters, int K, int W, unsigned seed) {
  static const uint8_t cand[]={16,17,18,24,20,25,26,21,22,48,49,50,56,52,0,1,2};
  int NC=sizeof cand; srand(seed);
  xb_t *beam=calloc(W,sizeof(xb_t)), *nb=calloc(W*NC,sizeof(xb_t));
  for(int i=0;i<W;i++) beam[i].s=malloc(sizeof(snap_t));
  for(int i=0;i<W*NC;i++) nb[i].s=malloc(sizeof(snap_t));
  // run to the first input call
  d68inj=0; unsigned long n0=d68n; while(d68n==n0) emu_step();
  snap_save(beam[0].s); beam[0].alive=1; beam[0].np=0; beam[0].d68=d68n; int nbm=1;
  for(int seg=0;seg*K<iters;seg++){
    int nn=0;
    for(int b=0;b<nbm;b++) for(int c=0;c<NC;c++){
      xb_t *n=&nb[nn]; snap_load(beam[b].s); d68n=beam[b].d68;
      memcpy(n->pairs,beam[b].pairs,sizeof n->pairs); n->np=beam[b].np;
      d68inj=cand[c]; unsigned long t=d68n+K; int alive=1;
      while(d68n<t){ emu_step(); if(rb(0,0x88C5)) { alive=0; break; } }
      n->pairs[2*n->np]=K; n->pairs[2*n->np+1]=cand[c]; n->np++;
      n->alive=alive; n->score=xscore(); n->x=rb(0,0x8001); n->y=rb(0,0x8002); n->d68=d68n;
      n->val= alive ? n->score + (rand()%100)/10.0 - abs(n->x-0x5A)*0.3 : -1e9;
      if(alive) snap_save(n->s);
      nn++;
    }
    qsort(nb,nn,sizeof(xb_t),xcmp);
    int w=0;
    for(int i=0;i<nn&&w<W;i++) if(nb[i].alive){ int dup=0; for(int j=0;j<w;j++) if(beam[j].x==nb[i].x&&beam[j].y==nb[i].y&&beam[j].score==nb[i].score) dup=1; if(dup) continue;
      snap_t *tmp=beam[w].s; beam[w]=nb[i]; beam[w].s=tmp; memcpy(beam[w].s,nb[i].s,sizeof(snap_t)); w++; }
    if(!w){ fprintf(stderr,"all died at seg %d\n",seg); break; }
    nbm=w;
    if(seg%10==0) fprintf(stderr,"seg %d score %d\n",seg,beam[0].score);
  }
  FILE *g=fopen(out,"w"); fprintf(g,"DEMOSTREAM:\n");
  int n=beam[0].np; uint8_t *pp=beam[0].pairs; int i=0;
  while(i<n){ int cnt=pp[2*i], v=pp[2*i+1]; while(i+1<n && pp[2*i+3]==v && cnt+pp[2*i+2]<=255){ i++; cnt+=pp[2*i]; } fprintf(g,"        db %d,%d\n",cnt,v); i++; }
  fprintf(g,"        db 0\n"); fclose(g);
  fprintf(stderr,"xsearch done: score %d pairs %d\n",beam[0].score,n);
  d68inj=-1;
}

static const int pal[16][3] = {
  {0x30,0xd2,0x00},{0xc1,0xe5,0x00},{0x4c,0x3a,0xb4},{0x9a,0x32,0x36},
  {0xbf,0xc8,0xad},{0x41,0xaf,0x71},{0xc8,0x4e,0xf0},{0xd4,0x7f,0x00},
  {0x26,0x30,0x16},{0x00,0x7c,0x00},{0x30,0xd2,0x00},{0x6b,0x27,0x00},{0xff,0xb7,0x00},{0,0,0},{0,0,0},{0,0,0}};
#include "font6847.h"
static int fontbit(int ch,int x,int y){ return (font6847[ch&63][y]>>(4-x))&1; }

static void save_screen(const char *fn) {
  static uint8_t img[192][256][3];
  int mode = (latch >> 3) & 1, css = (latch >> 4) & 1;
  for (int y = 0; y < 192; y++) for (int x = 0; x < 256; x++) {
    int c;
    if (mode) {
      int vy = y / 3, vx = x / 2;
      uint8_t b = ram[0x7000 + vy * 32 + vx / 4];
      int pix = (b >> (6 - 2 * (vx & 3))) & 3;
      c = pix + (css ? 4 : 0);
      img[y][x][0] = pal[c][0]; img[y][x][1] = pal[c][1]; img[y][x][2] = pal[c][2];
    } else {
      int cy = y / 12, cx = x / 8; uint8_t b = ram[0x7000 + cy * 32 + cx];
      int ry = y % 12, rx = x % 8; int on; int fg, bg;
      if (b & 0x80) { // SG4
        int q = (ry < 6 ? 0 : 2) + (rx < 4 ? 0 : 1); on = (b >> (3 - q)) & 1; fg = (b >> 4) & 7; bg = 13;
        if (on) { img[y][x][0] = pal[fg][0]; img[y][x][1] = pal[fg][1]; img[y][x][2] = pal[fg][2]; }
        else { img[y][x][0] = 0x10; img[y][x][1] = 0x10; img[y][x][2] = 0x10; }
        continue;
      }
      int inv = (b >> 6) & 1; int ch = b & 63;
      on = 0; if (ry >= 3 && ry < 10 && rx >= 1 && rx < 6) on = fontbit(ch, rx - 1, ry - 3);
      on ^= inv;
      fg = css ? 12 : 10; bg = css ? 11 : 9;
      c = on ? fg : bg;
      img[y][x][0] = pal[c][0]; img[y][x][1] = pal[c][1]; img[y][x][2] = pal[c][2];
    }
  }
  FILE *f = fopen(fn, "wb"); fprintf(f, "P6\n256 192\n255\n"); fwrite(img, 1, sizeof img, f); fclose(f);
}

static void load_vz(const char *fn, int run) {
  FILE *f = fopen(fn, "rb"); if (!f) { perror(fn); exit(1); }
  static uint8_t d[70000]; int n = fread(d, 1, sizeof d, f); fclose(f);
  int start = d[22] | d[23] << 8;
  for (int i = 24; i < n; i++) wb(0, start + i - 24, d[i]);
  fprintf(stderr, "loaded %s type %02X start %04X len %d end %04X\n", fn, d[21], start, n - 24, start + n - 24);
  if (run) cpu.pc = start;
}

static void setkey(const char *k, int down) {
  static const char *rows[8][6] = {
    {"T","W","","E","Q","R"},{"G","S","CTRL","D","A","F"},{"B","X","SHIFT","C","Z","V"},{"5","2","","3","1","4"},
    {"N",".","",",","SPACE","M"},{"6","9","-","8","0","7"},{"Y","O","RETURN","I","P","U"},{"H","L",":","K",";","J"}};
  for (int r = 0; r < 8; r++) for (int b = 0; b < 6; b++) if (rows[r][b][0] && !strcmp(rows[r][b], k)) { if (down) keys[r] &= ~(1 << b); else keys[r] |= 1 << b; return; }
  fprintf(stderr, "unknown key %s\n", k);
}

int main(int argc, char **argv) {
  if (getenv("VZ_SKEW")) FRAMET += atoi(getenv("VZ_SKEW"));
  if (argc < 2) { fprintf(stderr, "vzemu script\n"); return 1; }
  memset(keys, 0x3f, 8); memset(rom, 0xff, sizeof rom);
  rom[0x38] = 0xFB; rom[0x39] = 0xED; rom[0x3A] = 0x4D;   // EI / RETI (VZ ROM handler stand-in)
  z80_init(&cpu); cpu.read_byte = rb; cpu.write_byte = wb; cpu.port_in = pin; cpu.port_out = pout;
  cpu.sp = 0xb7f0; cpu.interrupt_mode = 1;
  FILE *s = fopen(argv[1], "r"); char line[256];
  while (fgets(line, sizeof line, s)) {
    char cmd[64], a1[128] = "", a2[128] = ""; if (sscanf(line, "%63s %127s %127s", cmd, a1, a2) < 1 || cmd[0] == ';') continue;
    if (!strcmp(cmd, "vz")) load_vz(a1, 1);
    else if (!strcmp(cmd, "frames")) run_frames(atoi(a1));
    else if (!strcmp(cmd, "iters")) run_iters(atoi(a1));
    else if (!strcmp(cmd, "demobuf")) g_demobuf = strtol(a1, 0, 16);
    else if (!strcmp(cmd, "inject")) g_inj = atoi(a1);
    else if (!strcmp(cmd, "dtarget")) { g_tx = strtol(a1,0,16); g_ty = strtol(a2,0,16); }
    else if (!strcmp(cmd, "dsearch")) { int it=430,K=8,W=6; unsigned sd=1; sscanf(a2, "%d,%d,%d,%u", &it, &K, &W, &sd); dsearch(a1, it, K, W, sd); }
    else if (!strcmp(cmd, "down")) setkey(a1, 1);
    else if (!strcmp(cmd, "up")) setkey(a1, 0);
    else if (!strcmp(cmd, "tap")) { setkey(a1, 1); run_frames(4); setkey(a1, 0); run_frames(4); }
    else if (!strcmp(cmd, "joy")) { joy[atoi(a1)] = strtol(a2, 0, 16); }
    else if (!strcmp(cmd, "screen")) save_screen(a1);
    else if (!strcmp(cmd, "regs")) { fprintf(stderr, "frame %lu mapper %02X latch %02X ", frames, mapper, latch); fflush(stderr); z80_debug_output(&cpu); fflush(stdout); }
    else if (!strcmp(cmd, "prof")) { profon = atoi(a1); if (profon) memset(prof, 0, sizeof prof); }
    else if (!strcmp(cmd, "profsave")) { FILE *g = fopen(a1, "w"); for (int i = 0; i < 65536; i++) if (prof[i]) fprintf(g, "%04X %lu\n", i, prof[i]); fclose(g); }
    else if (!strcmp(cmd, "bp")) bpmap[strtol(a1, 0, 16)] = 1;
    else if (!strcmp(cmd, "bpmem")) bpmem = strtol(a1, 0, 16);
    else if (!strcmp(cmd, "bplog")) { if (bplog) fclose(bplog); bplog = fopen(a1, "w"); }
    else if (!strcmp(cmd, "watch")) { watchw[strtol(a1, 0, 16)] = 1; if (!wlog) wlog = fopen("watch.txt", "w"); }
    else if (!strcmp(cmd, "wav")) { wavf = fopen(a1, "wb"); char hdr[44] = {0}; fwrite(hdr, 1, 44, wavf); wav_t = tstate; wav_n = 0; }
    else if (!strcmp(cmd, "wavend")) { if (wavf) { long n = wav_n; fseek(wavf, 0, SEEK_SET);
        uint32_t sr = 44100, br = 88200, ds = n * 2, rs = 36 + ds; uint16_t fmt = 1, ch = 1, ba = 2, bps = 16; uint32_t fl = 16;
        fwrite("RIFF", 1, 4, wavf); fwrite(&rs, 4, 1, wavf); fwrite("WAVEfmt ", 1, 8, wavf); fwrite(&fl, 4, 1, wavf); fwrite(&fmt, 2, 1, wavf); fwrite(&ch, 2, 1, wavf);
        fwrite(&sr, 4, 1, wavf); fwrite(&br, 4, 1, wavf); fwrite(&ba, 2, 1, wavf); fwrite(&bps, 2, 1, wavf); fwrite("data", 1, 4, wavf); fwrite(&ds, 4, 1, wavf); fclose(wavf); wavf = 0; } }
    else if (!strcmp(cmd, "dump")) { // dump 64K view
      FILE *g = fopen(a1, "wb"); for (int i = 0; i < 65536; i++) fputc(rb(0, i), g); fclose(g); }
    else if (!strcmp(cmd, "xsearch")) { int it=1200,K=8,W=6; unsigned sd=1; sscanf(a2,"%d,%d,%d,%u",&it,&K,&W,&sd); xsearch(a1,it,K,W,sd); }
    else if (!strcmp(cmd, "d68")) { d68f=fopen(a1,"r"); if(a2[0]) d68log=fopen(a2,"w"); d68n=0; }
    else if (!strcmp(cmd, "d68dump")) { d68dump=atol(a1); strcpy(d68dfn,a2); }
    else if (!strcmp(cmd, "untild68")) { unsigned long t=atol(a1); long mx=a2[0]?atol(a2):100000; while (d68n < t && mx-- > 0) run_frames(1); if(d68log) fflush(d68log); }
    else if (!strcmp(cmd, "cov")) covon = atoi(a1);
    else if (!strcmp(cmd, "covsave")) { FILE *g = fopen(a1, "wb"); fwrite(cov, 1, 65536, g); fclose(g); }
    else if (!strcmp(cmd, "rand")) { int n=atoi(a1); const char *ks[5]={"SPACE","Q","A","O","P"}; srand(atoi(a2)+frames);
        for(int i=0;i<n;i+=8){ for(int k=0;k<5;k++) setkey(ks[k], (rand()%3)==0 || (k==0 && rand()%2)); run_frames(8);} for(int k=0;k<5;k++) setkey(ks[k],0); }
    else if (!strcmp(cmd, "bvload")) { FILE *g=fopen(a1,"rb"); if(!g){perror(a1);exit(1);} int off=strtol(a2,0,16); int n=fread(bv+off,1,0x20000-off,g); fclose(g); fprintf(stderr,"bvload %s at bv+%05X len %d\n",a1,off,n); }
    else if (!strcmp(cmd, "bvsave")) { FILE *g=fopen(a1,"wb"); fwrite(bv,1,0x20000,g); fclose(g); }
    else if (!strcmp(cmd, "loadbin")) { FILE *g=fopen(a1,"rb"); if(!g){perror(a1);exit(1);} static uint8_t d[70000]; int n=fread(d,1,sizeof d,g); fclose(g); int ad=strtol(a2,0,16); for(int i=0;i<n;i++) wb(0,(ad+i)&0xffff,d[i]); }
    else if (!strcmp(cmd, "setpc")) { cpu.pc=strtol(a1,0,16); }
    else if (!strcmp(cmd, "mapper")) { mapper=strtol(a1,0,16); }
    else if (!strcmp(cmd, "fill")) { int a=strtol(a1,0,16), b=strtol(a2,0,16); for (int i=a;i<=b;i++) wb(0,i,(i*7+3)&255); }
    else if (!strcmp(cmd, "sd")) { strncpy(sddir, a1, 255); }
    else if (!strcmp(cmd, "dosmode")) { mapper = atoi(a1); }
    else if (!strcmp(cmd, "bpclear")) memset(bpmap,0,sizeof bpmap);
    else if (!strcmp(cmd, "lockstep")) { lsin=fopen(a1,"r"); lsout=fopen(a2,"w"); lsi=0; }
    else if (!strcmp(cmd, "lsraw")) { lsraw0=atol(a1); }
    else if (!strcmp(cmd, "lsskip")) { lsskip=atol(a1); }
    else if (!strcmp(cmd, "lsdump")) { lsdn=atol(a1); strcpy(lsdfn,a2); }
    else if (!strcmp(cmd, "lstrace")) { lstr=atol(a1); lstrf=fopen(a2,"w"); }
    else if (!strcmp(cmd, "seta")) { cpu.a = strtol(a1,0,16); }
    else if (!strcmp(cmd, "peek")) { int a=strtol(a1,0,16), n=a2[0]?atoi(a2):1; fprintf(stderr,"peek %04X:",a); for(int i=0;i<n;i++) fprintf(stderr," %02X",rb(0,a+i)); fprintf(stderr,"\n"); }
    else if (!strcmp(cmd, "poke")) { wb(0, strtol(a1,0,16), strtol(a2,0,16)); }
    else if (!strcmp(cmd, "trap")) trapmode = 1;
    else if (!strcmp(cmd, "protect")) protect = 1;
    else if (!strcmp(cmd, "crash")) crashpc = strtol(a1,0,16);
    else if (!strcmp(cmd, "crashrange")) { crlo = strtol(a1,0,16); crhi = strtol(a2,0,16); if (crashpc < 0) crashpc = 0x10000; }
    else if (!strcmp(cmd, "untilpc")) { unsigned pc = strtol(a1, 0, 16); int mx = atoi(a2) * FRAMET; unsigned long st = cpu.cyc;
        if (cpu.pc == pc) z80_step(&cpu);
        while (cpu.pc != pc && (long)(cpu.cyc - st) < mx) { curpc = cpu.pc; z80_step(&cpu); } fprintf(stderr, "untilpc %04X reached=%d cyc %lu\n", pc, cpu.pc == pc, (unsigned long)cpu.cyc); }
    else if (!strcmp(cmd, "rununtil") || !strcmp(cmd, "randuntil")) { unsigned pc = strtol(a1, 0, 16); char a3[32]="1"; sscanf(line, "%*s %*s %*s %31s", a3);
        unsigned long tgt = frames + atoi(a2); int rnd = !strcmp(cmd, "randuntil"); const char *ks[5]={"SPACE","Q","A","O","P"}; srand(atoi(a3)); unsigned long nf = frames; int hit = 0;
        while (frames < tgt) { if (rnd && frames >= nf) { for(int k=0;k<5;k++) setkey(ks[k], (rand()%3)==0 || (k==0 && rand()%2)); nf = frames + 8; }
          emu_step(); if (cpu.pc == pc) { hit = 1; break; } }
        if (rnd) for(int k=0;k<5;k++) setkey(ks[k],0);
        fprintf(stderr, "%s %04X hit=%d frame %lu\n", cmd, pc, hit, frames); }
    else if (!strcmp(cmd, "gprot")) { int a=strtol(a1,0,16), b=strtol(a2,0,16); for(int i=a;i<=b;i++) gprot[i]=1; gon=1; }
    else if (!strcmp(cmd, "gspec")) { int a=strtol(a1,0,16), b=strtol(a2,0,16); for(int i=a;i<=b;i++) gspec[i]=1; }
    else fprintf(stderr, "?? %s\n", cmd);
  }
  return 0;
}
