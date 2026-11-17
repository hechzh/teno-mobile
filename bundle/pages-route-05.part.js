((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
beN(d,e){return new B.pH(d,e,null)},
beM(d,e,f,g){return new B.lY(d,e,f,g,null)},
Xc:function Xc(d,e){this.c=d
this.a=e},
aps:function aps(d){this.a=d},
apt:function apt(d){this.a=d},
apq:function apq(d,e,f){this.a=d
this.b=e
this.c=f},
apr:function apr(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
pH:function pH(d,e,f){this.c=d
this.d=e
this.a=f},
Lo:function Lo(){var _=this
_.d=$
_.e=""
_.c=_.a=null},
aHG:function aHG(d){this.a=d},
aHE:function aHE(d,e){this.a=d
this.b=e},
aHF:function aHF(d){this.a=d},
aHB:function aHB(d){this.a=d},
aHA:function aHA(d,e){this.a=d
this.b=e},
aHC:function aHC(d){this.a=d},
aHD:function aHD(d,e){this.a=d
this.b=e},
aHz:function aHz(d,e,f){this.a=d
this.b=e
this.c=f},
aHy:function aHy(d){this.a=d},
lY:function lY(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},
Ln:function Ln(d,e,f,g){var _=this
_.d=d
_.e=e
_.w=_.r=_.f=$
_.y=_.x=""
_.z=f
_.as=_.Q=""
_.at=g
_.ax=null
_.ch=_.ay=!1
_.cx=_.CW=""
_.c=_.a=null},
aHn:function aHn(){},
aHo:function aHo(d,e,f){this.a=d
this.b=e
this.c=f},
aHp:function aHp(d){this.a=d},
aHq:function aHq(d,e){this.a=d
this.b=e},
aHl:function aHl(d,e){this.a=d
this.b=e},
aHe:function aHe(){},
aHd:function aHd(d,e){this.a=d
this.b=e},
aHf:function aHf(d){this.a=d},
aHg:function aHg(d,e,f){this.a=d
this.b=e
this.c=f},
aHb:function aHb(d){this.a=d},
aHc:function aHc(){},
aHh:function aHh(d,e){this.a=d
this.b=e},
aHi:function aHi(){},
aHj:function aHj(d,e,f){this.a=d
this.b=e
this.c=f},
aHk:function aHk(d){this.a=d},
aHw:function aHw(d,e){this.a=d
this.b=e},
aHx:function aHx(d,e){this.a=d
this.b=e},
aHt:function aHt(d){this.a=d},
aHu:function aHu(d){this.a=d},
aHv:function aHv(d,e){this.a=d
this.b=e},
aH7:function aH7(d,e){this.a=d
this.b=e},
aH8:function aH8(d){this.a=d},
aH9:function aH9(d,e){this.a=d
this.b=e},
aHa:function aHa(d){this.a=d},
aH6:function aH6(d,e,f){this.a=d
this.b=e
this.c=f},
aHr:function aHr(d,e){this.a=d
this.b=e},
aHs:function aHs(d,e){this.a=d
this.b=e},
aHm:function aHm(d,e){this.a=d
this.b=e}},H,R,S,K,T,I,U,V,W,X,Y,Z,F,A_,D,L,A0,E,M,N,G,O,A1,A2,A3,A4,P,A5,A6,Q
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[5],B)
H=c[38]
R=c[13]
S=c[66]
K=c[69]
T=c[53]
I=c[23]
U=c[28]
V=c[61]
W=c[73]
X=c[70]
Y=c[64]
Z=c[72]
F=c[59]
A_=c[68]
D=c[60]
L=c[57]
A0=c[50]
E=c[3]
M=c[52]
N=c[67]
G=c[63]
O=c[32]
A1=c[49]
A2=c[36]
A3=c[71]
A4=c[45]
P=c[65]
A5=c[62]
A6=c[74]
Q=c[25]
B.Xc.prototype={
D(d){return new O.lu(new B.aps(this),new B.apt(this),null)}}
B.pH.prototype={
X(){return new B.Lo()}}
B.Lo.prototype={
ghh(){var x,w=this.d
if(w===$){x=A.a_(this.a.d,y.P)
this.d=x
w=x}return w},
m(d,e){return C.b.eg(this.ghh(),new B.aHG(e))},
EK(){var x=0,w=A.v(y.P),v,u=this,t,s,r,q,p,o,n,m
var $async$EK=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:n=y.t
m=A.b([],n)
t=y.j,s=y.P
case 3:x=5
return A.h(u.a.c.di("GET","/api/v1/library/items?limit=100&offset="+m.length),$async$EK)
case 5:r=e
q=r.h(0,"items")
if(t.b(q)){q=J.eq(q,A.re(),s)
p=A.a_(q,q.$ti.i("aI.E"))}else p=A.b([],n)
C.b.N(m,p)
if(p.length!==0){q=m.length
o=A.eO(r.h(0,"total"))
q=q>=(o==null?m.length:o)}else q=!0
if(q){x=4
break}x=3
break
case 4:v=A.a2(["items",m],y.N,y.z)
x=1
break
case 1:return A.t(v,w)}})
return A.u($async$EK,w)},
D(d){var x=this,w=null,v=x.ghh().length===0?w:new B.aHE(x,d)
return E.dn(C.aC,A.iY(A.ak(A.eo(d).amo(x.ghh().length),w,w,w,w,w,w,w,w,w,w,w),v,w),new O.lu(x.gaNv(),new B.aHF(x),w),!1,!0,!1,!1,!0,"Add context")}}
B.lY.prototype={
X(){return new B.Ln(new A.eB(C.cm,$.ad()),A.nN(0,null,null),A.b([],y.t),A.p(y.N,y.z))}}
B.Ln.prototype={
gvr(){var x=this.f
if(x===$){x=this.a.d
x=this.f=x==null?"":x}return x},
ghh(){var x,w=this.r
if(w===$){x=A.a_(this.a.f,y.P)
this.r=x
w=x}return w},
gl0(){var x=this.w
if(x===$)x=this.w=this.a.f.length===0?"all":"current"
return x},
gIz(){var x=A.p(y.N,y.z)
x.n(0,"mode",this.gl0())
if(this.gl0()==="folder")x.n(0,"folder_id",this.x)
return x},
ai(){var x=this
x.aA()
x.d.Z(x.gaTQ())
if(x.gvr().length!==0)x.bi()},
aTR(){if(this.c!=null)this.F(new B.aHn())},
bi(){var x=0,w=A.v(y.H),v,u=2,t=[],s=this,r,q,p,o,n
var $async$bi=A.w(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return A.h(A.h7(A.b([s.a.c.di("GET","/api/v1/chats/"+s.gvr()),s.a.c.di("GET","/api/v1/personal/chats/"+s.gvr()+"/messages")],y.X),y.P),$async$bi)
case 7:r=e
if(s.c==null){x=1
break}q=A.bS(J.c7(r,0).h(0,"data"))
s.F(new B.aHo(s,r,q))
$.a3.RG$.push(new B.aHp(s))
u=2
x=6
break
case 4:u=3
n=t.pop()
p=A.an(n)
if(s.c!=null)s.F(new B.aHq(s,p))
x=6
break
case 3:x=2
break
case 6:case 1:return A.t(v,w)
case 2:return A.r(t.at(-1),w)}})
return A.u($async$bi,w)},
rD(){var x=0,w=A.v(y.H),v=this,u,t
var $async$rD=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:t=v.c
t.toString
x=2
return A.h(E.bP(t,new B.pH(v.a.c,v.ghh(),null),y.D),$async$rD)
case 2:u=e
if(u!=null&&v.c!=null)v.F(new B.aHl(v,u))
return A.t(null,w)}})
return A.u($async$rD,w)},
pI(){var x=0,w=A.v(y.H),v,u=this,t,s,r,q,p
var $async$pI=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:p=u.c
p.toString
x=3
return A.h(E.ri(null,null,new B.aHe(),p,!1,null,!1,y.N),$async$pI)
case 3:t=e
if(t==null||u.c==null){x=1
break}x=t==="selected"?4:5
break
case 4:x=6
return A.h(u.rD(),$async$pI)
case 6:x=1
break
case 5:x=t==="folder"?7:9
break
case 7:p=u.c
p.toString
x=10
return A.h(Q.Bh(p,u.a.c),$async$pI)
case 10:s=e
if(s==null||u.c==null){x=1
break}if(s.length===0){u.F(new B.aHf(u))
x=1
break}x=11
return A.h(u.a.c.di("GET","/api/v1/library/search/options"),$async$pI)
case 11:r=e
if(u.c==null){x=1
break}u.F(new B.aHg(u,s,r))
x=8
break
case 9:x=t==="current"?12:14
break
case 12:x=u.a.f.length!==0?15:17
break
case 15:u.F(new B.aHh(u,t))
x=16
break
case 17:x=18
return A.h(u.rD(),$async$pI)
case 18:p=J.oA(u.ghh(),new B.aHi())
q=A.a_(p,p.$ti.i("J.E"))
if(q.length!==0&&u.c!=null)u.F(new B.aHj(u,t,q))
case 16:x=13
break
case 14:u.F(new B.aHk(u))
case 13:case 8:case 1:return A.t(v,w)}})
return A.u($async$pI,w)},
nI(){var x=0,w=A.v(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i
var $async$nI=A.w(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:k=s.d
j=C.d.ee(k.a.a)
if(J.cg(j)===0||s.ay){x=1
break}if(J.lf(s.ghh()))o=s.gl0()==="current"||s.gl0()==="selected"
else o=!1
x=o?3:4
break
case 3:x=5
return A.h(s.rD(),$async$nI)
case 5:if(J.lf(s.ghh())||s.c==null){x=1
break}case 4:s.F(new B.aHw(s,j))
u=7
r=C.by.t2(A.b([j,s.gIz(),s.ghh(),s.a.c.gwu()],y.G),null)
if(s.cx!==r){s.cx=r
s.CW=A4.rf()}o=s.gvr()
n=s.a
x=o.length===0?10:12
break
case 10:o=n.c
n=J.bat(j,0,C.e.e2(J.cg(j),0,80))
m=s.gl0()==="current"||s.gl0()==="selected"?s.ghh():[]
x=13
return A.h(o.e1("POST","/api/v1/personal/chats",A.a2(["title",n,"contexts",m,"scope",s.gIz()],y.N,y.z)),$async$nI)
case 13:q=e
s.f=A.V(J.c7(q,"id"))
x=11
break
case 12:o=n.c
n=s.gvr()
m=s.gl0()==="current"||s.gl0()==="selected"?s.ghh():[]
x=14
return A.h(o.e1("PATCH","/api/v1/personal/chats/"+n+"/context",A.a2(["contexts",m,"scope",s.gIz()],y.N,y.z)),$async$nI)
case 14:case 11:x=15
return A.h(s.a.c.e1("POST","/api/v1/personal/chats/"+s.gvr()+"/messages",A.a2(["question",j,"client_id",s.CW,"output_language",s.a.c.gwu()],y.N,y.z)),$async$nI)
case 15:s.at=e
s.CW=s.cx=""
k.jA(C.qE)
x=16
return A.h(s.kT(),$async$nI)
case 16:u=2
x=9
break
case 7:u=6
i=t.pop()
p=A.an(i)
if(s.c!=null)s.F(new B.aHx(s,p))
x=9
break
case 6:x=2
break
case 9:case 1:return A.t(v,w)
case 2:return A.r(t.at(-1),w)}})
return A.u($async$nI,w)},
kT(){var x=0,w=A.v(y.H),v,u=2,t=[],s=this,r,q,p,o,n
var $async$kT=A.w(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return A.h(s.a.c.di("GET","/api/v1/jobs/"+A.n(s.at.h(0,"id"))),$async$kT)
case 7:r=e
if(s.c==null){x=1
break}p=r
s.at=p
x=J.c(J.c7(p,"status"),"completed")?8:10
break
case 8:s.F(new B.aHt(s))
x=11
return A.h(s.bi(),$async$kT)
case 11:x=9
break
case 10:if(J.c(s.at.h(0,"status"),"failed"))s.F(new B.aHu(s))
else s.ax=A.cb(F.SK,s.gHk())
case 9:u=2
x=6
break
case 4:u=3
n=t.pop()
q=A.an(n)
if(s.c!=null)s.F(new B.aHv(s,q))
x=6
break
case 3:x=2
break
case 6:case 1:return A.t(v,w)
case 2:return A.r(t.at(-1),w)}})
return A.u($async$kT,w)},
D(d){var x,w,v,u,t,s,r,q,p,o,n,m,l=this,k=null,j=l.a,i=j.e,h=i?"Assistant":"Chat",g=y.p
j=A.b([new A.ph(j.c,k),new E.iT(D.UQ,"Chat history",new B.aH7(l,d),44,k)],g)
x=A.bF(d,"Add context")
w=l.d
x=A.b([A.e7(k,k,k,D.VU,k,k,l.ay?k:l.ga3R(),k,k,k,x,k),A.bY(A.i1(k,C.bm,!1,k,!0,C.O,k,A.iL(),w,k,k,k,k,k,2,D.WS,C.a0,!0,k,!0,k,!1,k,C.bc,k,k,k,k,k,k,k,k,5,1,k,!1,"\u2022",k,k,k,new B.aH8(l),k,!1,k,k,!1,k,!0,k,C.aI,k,k,k,k,k,k,k,k,k,k,k,k,!0,C.ae,k,C.bK,k,k,k,k),1)],g)
w=C.d.ee(w.a.a).length===0
if(w)l.a.toString
if(!w){w=A.bF(d,"Send question")
x.push(A.e7(k,k,k,D.VL,k,k,l.ay?k:l.ganF(),k,k,k,w,k))}x=A.b9(x,C.fQ,C.h,C.l,0,k)
w=A.l(d).ax
v=w.rx
x=A.aS(A.b([new A1.lv(x,14,C.us,k),V.LZ,A.cl("Check important answers against the linked sources.",k,k,A.bo(k,k,v==null?w.k3:v,k,k,k,k,k,k,k,k,10,k,k,k,k,k,!0,k,k,k,k,k,k,k,k),k)],g),C.o,C.h,C.a1,0,C.p)
w=D.a9r.h(0,l.gl0())
w.toString
w=A.bF(d,w)
w=A.ak(w+(l.gl0()==="folder"&&l.y.length!==0?" \xb7 "+l.y:""),k,k,k,k,k,k,k,k,k,k,k)
w=A.b([new A.cP(C.fE,k,k,new A.ac(D.up,I.BI(D.VT,w,l.ay?k:new B.aH9(l,d)),k),k)],g)
if(J.iM(l.ghh()))v=l.gl0()==="current"||l.gl0()==="selected"
else v=!1
if(v){v=A.ak(A.eo(d).Te(J.cg(l.ghh())),k,k,k,k,k,k,k,k,k,k,k)
w.push(new A.cP(C.fE,k,k,new A.ac(D.up,I.BI(D.Wa,v,l.ay?k:l.ga3R()),k),k))}v=l.Q
if(v.length!==0)w.push(new A.ac(D.TQ,new A.dP(v,k,k),k))
if(l.z.length===0&&!l.ay)g=A.ni(new B.aHa(l))
else{v=A.b([],g)
for(u=l.z,t=u.length,s=y.N,r=y.z,q=y.f,p=0;p<u.length;u.length===t||(0,A.C)(u),++p){o=u[p]
n=o.h(0,"data")
n=q.b(n)?A.tF(n,s,r):A.p(s,r)
m=o.h(0,"id")
m=m==null?k:J.bd(m)
C.b.N(v,l.aVm(n,m==null?"":m))}if(l.as.length!==0){g=A.b([],g)
if(J.c(A.bS(l.at.h(0,"result")).h(0,"stage"),"preparing_search_index"))g.push(D.amZ)
u=A.l(d).ax
t=u.RG
u=t==null?u.k2:t
t=A.d2(16)
g.push(new A.cP(C.fD,k,k,A.cs(k,A.ak(l.as,k,k,k,k,k,k,k,k,k,k,k),C.t,k,k,new A.ci(u,k,k,t,k,k,C.a9),k,k,k,k,A5.oe,k,k,k),k))
g.push(D.aaZ)
C.b.N(v,g)}g=A.cr(v,l.e,k,G.cd,k,k,C.E,!1)}w.push(A.bY(g,1))
return E.dn(j,x,A.aS(w,C.o,C.h,C.l,0,C.p),!1,!0,!1,!1,!i,h)},
aVm(d,e){var x,w,v,u,t,s,r,q,p,o,n,m=this,l=null,k="paragraphs",j="citations",i="sources_unavailable",h=m.c
h.toString
h=A.l(h).ax
x=h.RG
h=x==null?h.k2:x
x=A.d2(17)
w=y.p
x=A.b([new A.cP(C.fD,l,l,A.cs(l,A.ak(A.V(d.h(0,"question")),l,l,l,l,l,l,l,l,l,l,l),C.t,l,l,new A.ci(h,l,l,x,l,l,C.a9),l,l,l,D.Te,D.Tw,l,l,l),l)],w)
if(A.bS(d.h(0,"scope")).a!==0){v=A.bS(d.h(0,"scope")).h(0,"mode")
A:{if("current"===v){h="Current record"
break A}if("folder"===v){h="Selected folder"
break A}if("selected"===v){h="Selected files"
break A}h="All my files"
break A}u=m.c
u.toString
u=A.l(u).ax
t=u.rx
x.push(A.cl(h,l,l,A.bo(l,l,t==null?u.k3:t,l,l,l,l,l,l,l,l,11,l,l,l,l,l,!0,l,l,l,l,l,l,l,l),l))}if(A.bQ(d.h(0,k)).length!==0)for(h=A.bQ(d.h(0,k)),u=h.length,t=y.t,s=y.j,r=y.P,q=0;q<h.length;h.length===u||(0,A.C)(h),++q){p=h[q]
o=p.h(0,"text")
o=o==null?l:J.bd(o)
o=M.nQ(o==null?"":o,D.Mv)
n=p.h(0,j)
if(s.b(n)){n=J.eq(n,A.re(),r)
n=A.a_(n,n.$ti.i("aI.E"))}else n=A.b([],t)
C.b.N(x,A.b([o,m.a3S(n),Y.ml],w))}else{if(J.c(d.h(0,i),!0)){h=m.c
h.toString
h=A.bF(h,"Sources unavailable")}else h=A.V(d.h(0,"answer"))
C.b.N(x,A.b([M.nQ(h,D.Mv),m.a3S(A.bQ(d.h(0,j)))],w))}h=m.c
h.toString
h=A.bF(h,"Share answer")
h=A.e7(l,l,l,D.Wi,l,l,J.c(d.h(0,i),!0)?l:new B.aHr(m,d),l,l,l,h,l)
u=m.c
u.toString
u=A.bF(u,"Save as note")
x.push(A.b9(A.b([h,A.e7(l,l,l,D.VA,l,l,J.c(d.h(0,i),!0)?l:new B.aHs(m,e),l,l,l,u,l)],w),C.o,C.h,C.l,0,l))
return x},
a3S(d){var x,w,v,u,t,s,r,q,p,o,n,m=this,l=null,k="saved_at",j="version_updated_at",i="start_ms",h=A.b([],y.p)
for(x=d.length,w=y.s,v=y.w,u=0;u<d.length;d.length===x||(0,A.C)(d),++u){t=d[u]
s=A.b([],w)
r=t.h(0,"title")
r=r==null?l:J.bd(r)
if((r==null?"":r).length!==0){r=t.h(0,"title")
r=r==null?l:J.bd(r)
s.push(r==null?"":r)}r=t.h(0,k)
r=r==null?l:J.bd(r)
if((r==null?"":r).length!==0){q=m.c.a2(v)
p=q==null?l:q.r.f
r=(p==null?C.aw:p).a
o=C.au.h(0,r)
s.push(A.OT(A.f8((o==null?r:o)==="zh"?C.b0:C.aw),"Saved date")+": "+H.Bi(t.h(0,k)))}r=t.h(0,j)
r=r==null?l:J.bd(r)
if((r==null?"":r).length!==0&&!J.c(t.h(0,j),t.h(0,k))){q=m.c.a2(v)
p=q==null?l:q.r.f
r=(p==null?C.aw:p).a
o=C.au.h(0,r)
s.push(A.OT(A.f8((o==null?r:o)==="zh"?C.b0:C.aw),"Version updated")+": "+H.Bi(t.h(0,j)))}if(t.h(0,"page")!=null){q=m.c.a2(v)
r=q==null?l:q.r.f
if(r==null)r=l
else{r=r.a
o=C.au.h(0,r)
r=o==null?r:o}o=A.f8(r==="zh"?C.b0:C.aw)
n=t.h(0,"page")
r=n==null?l:J.bd(n)
s.push(o.ww(r==null?"":r))}else if(t.h(0,i)!=null){q=m.c.a2(v)
r=q==null?l:q.r.f
if(r==null)r=l
else{r=r.a
o=C.au.h(0,r)
r=o==null?r:o}s.push(A.f8(r==="zh"?C.b0:C.aw).IT(L.lc(t.h(0,i))))}h.push(I.BI(l,new A.bJ(C.b.cv(s," \xb7 "),l,P.fr,l,l,l,l,l,l,3,l,l,l,l),new B.aHm(m,t)))}return A.hK(C.bq,h,C.co,0,6)},
k(){var x=this,w=x.ax
if(w!=null)w.bW()
w=x.d
w.fx$=$.ad()
w.fr$=0
x.e.k()
x.am()}}
var z=a.updateTypes(["ae<~>()","ae<a9<j,@>>()","~()"])
B.aps.prototype={
$0(){var x=0,w=A.v(y.P),v,u=this,t
var $async$$0=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:t=A
x=3
return A.h(u.a.c.jj("/api/v1/chats?limit=200"),$async$$0)
case 3:v=t.a2(["items",e],y.N,y.z)
x=1
break
case 1:return A.t(v,w)}})
return A.u($async$$0,w)},
$S:76}
B.apt.prototype={
$3(d,e,f){var x,w,v,u,t,s,r,q,p=null,o=this.a,n=A.b([R.b1m(S.iv,F.anx,new B.apq(o,d,f)),T.dE("Recent chats",!0)],y.p)
if(A.bQ(e.h(0,"items")).length===0)n.push(D.U5)
for(x=A.bQ(e.h(0,"items")),w=x.length,v=y.N,u=y.z,t=y.f,s=0;s<x.length;x.length===w||(0,A.C)(x),++s){r=x[s]
q=r.h(0,"data")
q=(t.b(q)?A.tF(q,v,u):A.p(v,u)).h(0,"title")
q=q==null?p:J.bd(q)
if(q==null)q=""
n.push(A.c9(!1,C.y,p,p,!0,p,p,p,!0,p,D.W8,p,p,p,p,new B.apr(o,d,r,f),!1,p,p,p,p,new A.bJ(H.Bi(r.h(0,"created_at")),p,p,p,p,p,p,p,p,p,p,p,p,p),p,new A.bJ(q,p,p,p,p,p,p,p,p,p,p,p,p,p),p,p,p,p))}return A.cr(n,p,p,G.cd,p,p,C.E,!1)},
$S:77}
B.apq.prototype={
$0(){var x=0,w=A.v(y.H),v=this
var $async$$0=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:x=2
return A.h(E.bP(v.b,new B.lY(v.a.c,null,!1,N.f1,null),y.z),$async$$0)
case 2:v.c.$0()
return A.t(null,w)}})
return A.u($async$$0,w)},
$S:2}
B.apr.prototype={
$0(){var x=0,w=A.v(y.H),v=this
var $async$$0=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:x=2
return A.h(E.bP(v.b,new B.lY(v.a.c,A.V(v.c.h(0,"id")),!1,N.f1,null),y.z),$async$$0)
case 2:v.d.$0()
return A.t(null,w)}})
return A.u($async$$0,w)},
$S:2}
B.aHG.prototype={
$1(d){var x=this.a
return J.c(d.h(0,"type"),x.h(0,"type"))&&J.c(d.h(0,"id"),x.h(0,"id"))},
$S:8}
B.aHE.prototype={
$0(){var x=this.a.ghh()
A.br(this.b,!1).cs(x)
return null},
$S:0}
B.aHF.prototype={
$3(d,e,f){var x,w,v,u,t,s,r=null,q=this.a,p=A.b([D.aoO,C.c4,A.i1(r,C.bm,!1,r,!0,C.O,r,A.iL(),r,r,r,r,r,r,2,D.WT,C.a0,!0,r,!0,r,!1,r,C.bc,r,r,r,r,r,r,r,r,1,r,r,!1,"\u2022",r,new B.aHB(q),r,r,r,!1,r,r,!1,r,!0,r,C.aI,r,r,r,r,r,r,r,r,r,r,r,r,!0,C.ae,r,C.bK,r,r,r,r)],y.p)
for(x=C.b.gag(A.bQ(e.h(0,"items"))),w=new A.l2(x,new B.aHC(q));w.v();){v=x.gR()
u=v.h(0,"title")
u=u==null?r:J.bd(u)
if(u==null)u=""
t=v.h(0,"type")
s=t==null?r:J.bd(t)
if(s==null)s=""
A:{t="File"
if("recording"===s){t="Recording file"
break A}if("note"===s){t="Note"
break A}if("folder"===s){t="Folder"
break A}if("file"===s)break A
if("document"===s){t="Document"
break A}break A}p.push(A2.adJ(C.y,r,new B.aHD(q,v),new A.a1(t,r,r,r,r,r),new A.bJ(u,r,A_.my,r,r,r,r,r,r,r,r,r,r,r),q.m(0,v)))}return A.cr(p,r,r,G.cd,r,r,C.E,!1)},
$S:77}
B.aHB.prototype={
$1(d){var x=this.a
return x.F(new B.aHA(x,d))},
$S:14}
B.aHA.prototype={
$0(){return this.a.e=this.b},
$S:0}
B.aHC.prototype={
$1(d){return C.d.m(A.V(d.h(0,"title")).toLowerCase(),this.a.e.toLowerCase())},
$S:8}
B.aHD.prototype={
$1(d){var x=this.a
return x.F(new B.aHz(x,d,this.b))},
$S:90}
B.aHz.prototype={
$0(){var x,w,v=this
if(v.b===!0){x=v.a
if(x.ghh().length>=30)return
w=v.c
x.ghh().push(A.a2(["type",w.h(0,"type"),"id",w.h(0,"id")],y.N,y.z))}else C.b.h2(v.a.ghh(),new B.aHy(v.c))},
$S:0}
B.aHy.prototype={
$1(d){var x=this.a
return J.c(d.h(0,"type"),x.h(0,"type"))&&J.c(d.h(0,"id"),x.h(0,"id"))},
$S:8}
B.aHn.prototype={
$0(){},
$S:0}
B.aHo.prototype={
$0(){var x,w,v,u,t,s,r,q=this.a
q.z=A.bQ(J.c7(this.b,1).h(0,"items"))
u=this.c
q.r=A.bQ(u.h(0,"contexts"))
x=A.bS(u.h(0,"scope"))
q.w=A.V(J.c7(x,"mode")).length===0?"selected":A.V(J.c7(x,"mode"))
q.x=A.V(J.c7(x,"folder_id"))
if(J.lf(q.ghh())){w=A.b([],y.t)
u=y.g.a(u.h(0,"recording_ids"))
u=J.bR(u==null?[]:u)
t=y.N
s=y.z
while(u.v()){v=u.gR()
r=v
r=r==null?null:J.bd(r)
J.e4(w,A.a2(["type","recording","id",r==null?"":r],t,s))}q.r=w}},
$S:0}
B.aHp.prototype={
$1(d){var x,w=this.a
if(w.c!=null&&w.e.f.length!==0){w=w.e
x=C.b.gdn(w.f).Q
x.toString
w.fE(x)}},
$S:5}
B.aHq.prototype={
$0(){return this.a.Q=A.fF(this.b)},
$S:0}
B.aHl.prototype={
$0(){var x=this.a
x.r=this.b
x.w="selected"},
$S:0}
B.aHe.prototype={
$1(d){var x,w,v,u=null,t=A.b([],y.p)
for(x=[D.acd,D.ad0,D.ad1,D.acA],w=0;w<4;++w){v=x[w]
t.push(A.c9(!1,u,u,u,!0,u,u,u,!0,u,u,u,u,u,u,new B.aHd(d,v),!1,u,u,u,u,u,u,new A.a1(v.b,u,u,u,u,u),u,u,u,u))}return A.dG(!0,A.aS(t,C.o,C.h,C.a1,0,C.p),!0,!1,C.y,!0,!0)},
$S:53}
B.aHd.prototype={
$0(){A.br(this.a,!1).cs(this.b.a)
return null},
$S:0}
B.aHf.prototype={
$0(){var x=this.a
x.w="all"
x.x=""},
$S:0}
B.aHg.prototype={
$0(){var x,w,v,u=this.a
u.w="folder"
x=this.b
u.x=x
w=A.bQ(this.c.h(0,"folders"))
v=A.aa(w)
v=A.lN(new A.dX(new A.aB(w,new B.aHb(x),v.i("aB<1>")),new B.aHc(),v.i("dX<1,j>")))
u.y=v==null?"":v},
$S:0}
B.aHb.prototype={
$1(d){return J.c(d.h(0,"id"),this.a)},
$S:8}
B.aHc.prototype={
$1(d){return A.V(d.h(0,"title"))},
$S:62}
B.aHh.prototype={
$0(){var x,w=this.a
w.w=this.b
x=A.a_(w.a.f,y.P)
w.r=x},
$S:0}
B.aHi.prototype={
$1(d){return!J.c(d.h(0,"type"),"folder")},
$S:8}
B.aHj.prototype={
$0(){var x=this.a
x.w=this.b
x.r=A.b([C.b.gae(this.c)],y.t)},
$S:0}
B.aHk.prototype={
$0(){return this.a.w="all"},
$S:0}
B.aHw.prototype={
$0(){var x=this.a
x.ay=!0
x.Q=""
x.as=this.b},
$S:0}
B.aHx.prototype={
$0(){var x=this.a
x.Q=A.fF(this.b)
x.ay=!1
x.as=""},
$S:0}
B.aHt.prototype={
$0(){var x=this.a
x.ay=!1
x.as=""},
$S:0}
B.aHu.prototype={
$0(){var x=this.a
x.ay=!1
x.as=""
x.Q=A.V(A.bS(x.at.h(0,"error")).h(0,"message"))},
$S:0}
B.aHv.prototype={
$0(){var x=this.a
x.Q=A.fF(this.b)
x.ay=!1
x.as=""},
$S:0}
B.aH7.prototype={
$0(){return E.bP(this.b,E.dn(C.aC,null,new B.Xc(this.a.a.c,null),!1,!0,!1,!1,!0,"Chat history"),y.z)},
$S:0}
B.aH8.prototype={
$1(d){return this.a.nI()},
$S:14}
B.aH9.prototype={
$0(){return A.bT(this.b,this.a.gaOF())},
$S:0}
B.aHa.prototype={
$2(d,e){var x,w,v,u,t,s,r,q=null,p=A.b([D.Wl,K.er,D.ao0,K.er],y.p)
for(x=["Recap the key decisions","What are the next steps?","Find the important details"],w=this.a,v=0;v<3;++v){u=x[v]
t=A.l(d).ax
s=t.to
if(s==null){s=t.t
t=s==null?t.k3:s}else t=s
s=A.l(d).ax
r=s.p2
s=r==null?s.k2:r
r=new A.aR(12,12)
p.push(new A.ac(X.eR,U.aoO(new A.a1(u,q,q,q,q,q),new B.aH6(w,d,u),A.aoQ(q,q,s,q,q,q,q,q,q,q,q,q,C.uj,q,new A.cT(new A.ch(r,r,r,r),C.u),new A.aF(t,1,C.x,-1),q,q,q,q)),q))}return A.iB(new A.d3(new A.a8(0,1/0,e.d,1/0),new A.cP(C.a6,q,q,new A.ac(D.TT,A.aS(p,C.b5,C.h,C.a1,0,C.p),q),q),q),q,q,q,q,!1,C.E)},
$S:222}
B.aH6.prototype={
$0(){this.a.d.sjm(A.bF(this.b,this.c))},
$S:0}
B.aHr.prototype={
$0(){return this.a.a.c.a.nJ(A.V(this.b.h(0,"answer")))},
$S:0}
B.aHs.prototype={
$0(){var x=0,w=A.v(y.H),v,u=this,t,s,r,q,p,o
var $async$$0=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:p=u.a
o=p.c
o.toString
x=3
return A.h(Q.Bh(o,p.a.c),$async$$0)
case 3:t=e
if(t==null||p.c==null){x=1
break}o=p.a.c
s=t.length===0?null:t
r=y.z
x=4
return A.h(o.e1("POST","/api/v1/personal/messages/"+u.b+"/save",A.a2(["folder_id",s],y.N,r)),$async$$0)
case 4:q=e
o=p.c
if(o==null){x=1
break}x=5
return A.h(E.bP(o,L.aq7(p.a.c,A.V(q.h(0,"id")),null),r),$async$$0)
case 5:case 1:return A.t(v,w)}})
return A.u($async$$0,w)},
$S:2}
B.aHm.prototype={
$0(){var x,w,v,u="type",t=this.a,s=t.c
s.toString
t=t.a.c
x=this.b
w=x.h(0,u)
if(w==null)w="recording"
if(J.c(x.h(0,u),"note"))v=x.h(0,"note_id")
else v=J.c(x.h(0,u),"file")?x.h(0,"file_id"):x.h(0,"recording_id")
return A0.mC(s,t,A.a2(["type",w,"id",v],y.N,y.z),x)},
$S:0};(function installTearOffs(){var x=a._instance_0u
x(B.Lo.prototype,"gaNv","EK",1)
var w
x(w=B.Ln.prototype,"gaTQ","aTR",2)
x(w,"ga3R","rD",0)
x(w,"gaOF","pI",0)
x(w,"ganF","nI",0)
x(w,"gHk","kT",0)})();(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.Xc,A.Y)
w(A.dQ,[B.aps,B.apq,B.apr,B.aHE,B.aHA,B.aHz,B.aHn,B.aHo,B.aHq,B.aHl,B.aHd,B.aHf,B.aHg,B.aHh,B.aHj,B.aHk,B.aHw,B.aHx,B.aHt,B.aHu,B.aHv,B.aH7,B.aH9,B.aH6,B.aHr,B.aHs,B.aHm])
w(A.cq,[B.apt,B.aHG,B.aHF,B.aHB,B.aHC,B.aHD,B.aHy,B.aHp,B.aHe,B.aHb,B.aHc,B.aHi,B.aH8])
w(A.M,[B.pH,B.lY])
w(A.O,[B.Lo,B.Ln])
x(B.aHa,A.et)})()
A.cx(b.typeUniverse,JSON.parse('{"Xc":{"Y":[],"e":[]},"pH":{"M":[],"e":[]},"Lo":{"O":["pH"]},"lY":{"M":[],"e":[]},"Ln":{"O":["lY"]}}'))
var y=(function rtii(){var x=A.T
return{X:x("o<ae<a9<j,@>>>"),t:x("o<a9<j,@>>"),G:x("o<Q>"),s:x("o<j>"),p:x("o<e>"),D:x("W<a9<j,@>>"),j:x("W<@>"),P:x("a9<j,@>"),f:x("a9<@,@>"),N:x("j"),w:x("jr"),z:x("@"),g:x("W<@>?"),H:x("~")}})();(function constants(){D.Te=new A.Z(0,16,0,20)
D.Tw=new A.Z(13,13,13,13)
D.TQ=new A.Z(21,0,21,0)
D.up=new A.Z(21,6,21,6)
D.TT=new A.Z(24,16,24,20)
D.U5=new E.hy("Ask Teno","Start a conversation about your files.",null,G.cf,null)
D.UQ=new A.b0(58132,"MaterialIcons",!1)
D.V6=new A.b0(61152,"MaterialIcons",!1)
D.VA=new A.b2(D.V6,18,null,null,null)
D.VL=new A.b2(F.UF,22,null,null,null)
D.V3=new A.b0(59004,"MaterialIcons",!1)
D.VT=new A.b2(D.V3,16,null,null,null)
D.VU=new A.b2(A3.ir,22,null,null,null)
D.W8=new A.b2(F.UJ,21,null,null,null)
D.Wa=new A.b2(F.UG,16,null,null,null)
D.Wi=new A.b2(Z.kC,18,null,null,null)
D.Wl=new A.b2(W.iu,40,null,null,null)
D.anI=new A.a1("Ask me anything about your recordings",null,null,null,null,null)
D.WS=new A.hb(null,null,null,null,null,null,null,null,null,null,null,D.anI,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,C.ki,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!1,null,null,null,null,C.ju,null,null,C.ju,C.ju,!0,null,null,null,null)
D.anz=new A.a1("Find a file",null,null,null,null,null)
D.WT=new A.hb(null,null,null,null,null,null,null,null,null,null,null,D.anz,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,F.Wd,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.a9Z={all:0,current:1,folder:2,selected:3}
D.a9r=new A.ag(D.a9Z,["All my files","Current record","Selected folder","Selected files"],A.T("ag<j,j>"))
D.aaZ=new A.ac(A6.ug,G.cJ,null)
D.acd=new A.X("current","Current record")
D.acA=new A.X("selected","Selected files")
D.ad0=new A.X("folder","Selected folder")
D.ad1=new A.X("all","All my files")
D.Mv=new A.q(!0,null,null,null,null,null,14,null,null,null,null,null,1.75,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.amZ=new A.a1("Preparing personal search. Existing files are not regenerated.",null,null,null,null,null)
D.ao0=new A.a1("How can I help you today?",P.Ms,null,null,null,null)
D.aoO=new A.a1("Select recordings, notes, documents or folders.",null,null,null,null,null)})()};
(a=>{a["aR9O5pMxDd9uXVcXDoEIMVKXew8="]=a.current})($__dart_deferred_initializers__);
