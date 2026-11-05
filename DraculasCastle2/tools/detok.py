import sys
T="END FOR RESET SET CLS CMD RANDOM NEXT DATA INPUT DIM READ LET GOTO RUN IF RESTORE GOSUB RETURN REM STOP ELSE TRON TROFF DEFSTR DEFINT DEFSNG DEFDBL LINE EDIT ERROR RESUME OUT ON OPEN FIELD GET PUT CLOSE LOAD MERGE NAME KILL LSET RSET SAVE SYSTEM LPRINT DEF POKE PRINT CONT LIST LLIST DELETE AUTO CLEAR CLOAD CSAVE NEW TAB( TO FN USING VARPTR USR ERL ERR STRING$ INSTR POINT TIME$ MEM INKEY$ THEN NOT STEP + - * / ^ AND OR > = < SGN INT ABS FRE INP POS SQR RND LOG EXP COS SIN TAN ATN PEEK CVI CVS CVD EOF LOC LOF MKI$ MKS$ MKD$ CINT CSNG CDBL FIX LEN STR$ VAL ASC CHR$ LEFT$ RIGHT$ MID$".split()
d=open(sys.argv[1],'rb').read()[24:]
base=0x7AE9;p=0;lines=[]
while p+4<=len(d):
    link=d[p]|d[p+1]<<8
    if link==0: break
    ln=d[p+2]|d[p+3]<<8; p+=4; out=[];raw=[]
    inq=False
    while d[p]!=0:
        c=d[p];p+=1;raw.append(c)
        if c==34: inq=not inq; out.append('"')
        elif inq or c<0x80:
            out.append(chr(c) if 32<=c<127 else '{%02X}'%c)
        else:
            i=c-0x80; out.append(T[i] if i<len(T) else '{%02X}'%c)
    p+=1
    lines.append((ln,''.join(out),raw))
for ln,s,r in lines: print(ln,s)
import pickle;pickle.dump(lines,open('/home/claude/dc2/orig/lines.pkl','wb'))
