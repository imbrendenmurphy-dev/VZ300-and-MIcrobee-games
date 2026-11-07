"""Generate ordinary-stack Z80 drawing programs for native actor alignments."""

def generate(root, sprites, height):
    lookups=bytearray(4096)
    for row in range(14):
        for col in range(80):
            cell=row*80+col;address=0xA000+col*224+row*16
            lookups[cell]=address&255;lookups[0x800+cell]=address>>8
    (root/'actor-lookups.bin').write_bytes(lookups)
    lines=[]
    for frame in range(8):
        prefix=f'actor_f{frame}'
        lines+=['ORG 0','INCBIN "../build/native/actor-lookups.bin"']
        for phase in range(8):
            lines.append('DW '+','.join(f'{prefix}_p{phase}_y{dy}' for dy in range(16)))
        for phase in range(8):
            for dy in range(16):
                lines.append(f'{prefix}_p{phase}_y{dy}:')
                for col in range(3):
                    rows=[sprites[((frame*8+phase)*3+col)*32+r*2:
                                  ((frame*8+phase)*3+col)*32+r*2+2] for r in range(height)]
                    active=[r for r,v in enumerate(rows) if v!=b'\xff\x00']
                    if not active:continue
                    skip=f'{prefix}_p{phase}_y{dy}_c{col}_skip'
                    lines+=['LD A,(n_col)',f'ADD A,{col}' if col else 'OR A',
                            'CP 80',f'JP NC,{skip}']
                    for vertical in sorted({(r+dy)//16 for r in active}):
                        lines.append('LD HL,(n_topcell)')
                        offset=col+vertical*80
                        if offset:lines+= [f'LD BC,{offset}','ADD HL,BC']
                        lines.append('LD DE,(n_topcpu)')
                        offset=col*224+vertical*16
                        if offset:lines+=['EX DE,HL',f'LD BC,{offset}','ADD HL,BC','EX DE,HL']
                        lines+=['CALL n_touch_cell',f'JP C,{skip}']
                    lines.append('LD DE,(n_topcpu)')
                    offset=col*224+dy+min(active)
                    if offset:lines+=['LD HL,'+str(offset),'ADD HL,DE','EX DE,HL']
                    lines += [f'CALL {prefix}_shader{phase}_{col}',skip+':']
                lines.append('RET')
        for phase in range(8):
            for col in range(3):
                rows=[sprites[((frame*8+phase)*3+col)*32+r*2:
                              ((frame*8+phase)*3+col)*32+r*2+2] for r in range(height)]
                active=[r for r,v in enumerate(rows) if v!=b'\xff\x00']
                lines.append(f'{prefix}_shader{phase}_{col}:')
                if active:
                    for r in range(min(active),max(active)+1):
                        mask,ink=rows[r]
                        if mask==0:lines+= [f'LD A,{ink}','LD (DE),A']
                        elif mask!=255 or ink:lines+=['LD A,(DE)',f'AND {mask}',f'OR {ink}','LD (DE),A']
                        lines.append('INC DE')
                lines.append('RET')
        lines+=['ASSERT $ < $8000',f'SAVEBIN "../build/native/ACTOR{frame}.BNK",0,$8000']
    (root/'actor-programs.asm').write_text('\n'.join(line if line.endswith(':') else '        '+line for line in lines)+'\n')
