((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,C={aEB:function aEB(d){this.a=d},wz:function wz(d,e,f,g,h,i,j,k,l,m,n,o,p){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.x=h
_.y=i
_.z=j
_.Q=k
_.as=l
_.at=m
_.ax=n
_.ch=o
_.a=p},a2p:function a2p(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
_.d=d
_.e=null
_.jc$=e
_.fW$=f
_.iM$=g
_.iN$=h
_.jQ$=i
_.lv$=j
_.jR$=k
_.lw$=l
_.t8$=m
_.vX$=n
_.kv$=o
_.jS$=p
_.jT$=q
_.e9$=r
_.bU$=s
_.c=_.a=null},aAo:function aAo(d){this.a=d},aAn:function aAn(d){this.a=d},aAp:function aAp(d){this.a=d},aAq:function aAq(d){this.a=d},a1U:function a1U(d){var _=this
_.ax=_.at=_.as=_.Q=_.z=_.y=_.x=_.w=_.r=_.f=_.e=_.d=_.c=_.b=_.a=_.go=_.fy=_.fx=_.fr=_.dy=_.dx=null
_.fr$=0
_.fx$=d
_.go$=_.fy$=0},NI:function NI(){},NJ:function NJ(){},azQ:function azQ(d,e){this.a=d
this.b=e},wc:function wc(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.y=k
_.as=l
_.at=m
_.ax=n
_.ch=o
_.CW=p
_.cx=q
_.cy=r
_.db=s
_.dx=t
_.a=u},a1V:function a1V(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
_.d=d
_.e=null
_.jc$=e
_.fW$=f
_.iM$=g
_.iN$=h
_.jQ$=i
_.lv$=j
_.jR$=k
_.lw$=l
_.t8$=m
_.vX$=n
_.kv$=o
_.jS$=p
_.jT$=q
_.e9$=r
_.bU$=s
_.c=_.a=null},azO:function azO(d){this.a=d},azP:function azP(d,e){this.a=d
this.b=e},a1T:function a1T(d){var _=this
_.ax=_.at=_.as=_.Q=_.z=_.y=_.x=_.w=_.r=_.f=_.e=_.d=_.c=_.b=_.a=_.go=_.fy=_.fx=_.fr=_.dy=_.dx=null
_.fr$=0
_.fx$=d
_.go$=_.fy$=0},azJ:function azJ(d,e,f,g,h,i,j,k,l,m,n){var _=this
_.y=d
_.z=e
_.a=f
_.b=g
_.c=h
_.d=i
_.e=j
_.f=k
_.r=l
_.w=m
_.x=n},azN:function azN(d){this.a=d},azL:function azL(d){this.a=d},azK:function azK(d){this.a=d},azM:function azM(d){this.a=d},ND:function ND(){},NE:function NE(){},
ads(d,e,f,g,h,i){return new C.Cj(i,f,h,g,e,d,null)},
azR:function azR(d,e){this.a=d
this.b=e},
Cj:function Cj(d,e,f,g,h,i,j){var _=this
_.c=d
_.d=e
_.db=f
_.dx=g
_.go=h
_.id=i
_.a=j},
b4v(d){var x=d.oJ(!1)
return new C.a97(d,new A.cv(x,B.c3,B.aC),$.ab())},
yu(d,e){return new C.GY(d,e,null)},
bfo(d,e){return A.aVm(e)},
a97:function a97(d,e,f){var _=this
_.ax=d
_.a=e
_.fr$=0
_.fx$=f
_.go$=_.fy$=0},
a7U:function a7U(d,e){var _=this
_.x=d
_.a=e
_.c=_.b=!0
_.d=!1
_.f=_.e=0
_.r=null
_.w=!1},
GY:function GY(d,e,f){this.c=d
this.f=e
this.a=f},
Mj:function Mj(d){var _=this
_.d=$
_.e=null
_.f=!1
_.w=_.r=$
_.x=d
_.c=_.a=null},
aOC:function aOC(d,e){this.a=d
this.b=e},
aOB:function aOB(d,e){this.a=d
this.b=e},
aOD:function aOD(d){this.a=d},
b_v(d){var x
d.ab(y.K)
x=A.l(d)
return x.xr},
vR(){var x,w=$.b7z(),v=J.pe(16,y.N)
for(x=0;x<16;++x)v[x]=B.d.dI(B.e.oK(w.aTl(256),16),2,"0")
return B.b.Al(v)}},D
J=c[1]
A=c[0]
B=c[2]
C=a.updateHolder(c[38],C)
D=c[145]
C.aEB.prototype={
arV(){var x=self.crypto
if(x!=null)if(x.getRandomValues!=null)return
throw A.m(A.c8("No source of cryptographically secure random numbers available."))},
aTl(d){var x,w,v,u,t,s,r,q
if(d<=0||d>4294967296)throw A.m(A.beK("max must be in range 0 < max \u2264 2^32, was "+d))
if(d>255)if(d>65535)x=d>16777215?4:3
else x=2
else x=1
w=this.a
w.$flags&2&&A.aP(w,11)
w.setUint32(0,0,!1)
v=4-x
u=A.cU(Math.pow(256,x))
for(t=d-1,s=(d&t)===0;;){crypto.getRandomValues(J.kc(B.b7.gdL(w),v,x))
r=w.getUint32(0,!1)
if(s)return(r&t)>>>0
q=r%d
if(r-q+d<u)return q}}}
C.wz.prototype={
Y(){return new C.a2p(new C.a1U($.ab()),$,$,$,$,$,$,$,$,B.aZ,$,null,!1,!1,null,null)}}
C.a2p.prototype={
ak(){this.aqF()
this.e=this.a.c},
b1(d){var x
this.bx(d)
x=d.c
if(x!==this.a.c)this.e=x},
k(){this.d.k()
this.aqE()},
ghQ(){return this.a.d},
gu0(){this.a.toString
return!1},
gn(){return this.a.c},
gVM(){return new A.aE(new C.aAo(this),y.k)},
gauY(){return new A.aE(new C.aAn(this),y.k)},
gav3(){return new A.aE(new C.aAp(this),y.P)},
atK(d,e){if(!e.m(0,B.r))return d
return null},
E(d){var x,w,v,u,t,s,r,q,p,o,n,m=this,l=null,k=m.gex()
k.G(0,B.r)
x=m.gex()
x.J(0,B.r)
w=m.gex()
m.a.toString
v=m.gVM().a.$1(k)
m.a.toString
u=m.gVM().a.$1(x)
t=m.atK(m.a.at,w)
if(t==null)t=m.gav3().a.$1(w)
m.a.toString
s=A.aj0(v.be(0.8))
r=new A.p0(s.a,s.b,0.835,0.69).HB()
s=m.a
s.toString
q=A.aY()
p=l
A:{if(B.X===q||B.ar===q||B.bd===q){o=B.qo
break A}if(B.aT===q||B.be===q||B.bf===q){o=D.LN
break A}o=p}p=o
o=m.d
n=m.fW$
n===$&&A.a()
o.scQ(n)
n=m.iN$
n===$&&A.a()
o.sB_(n)
o.szV(r)
o.szB(m.kv$)
o.skF(w.m(0,B.C))
o.sGo(w.m(0,B.D))
o.syS(v)
o.sAa(u)
o.so7(m.gauY().a.$1(w))
o.sn(m.a.c)
o.sQM(m.e)
o.sot(m.a.d!=null)
m.a.toString
o.scw(B.m_)
o.sel(t)
o.shv(A.ls(d).ghv())
return A.b8(l,l,s.c,m.a36(!1,s.Q,new A.aE(new C.aAq(m),y.F),o,p),!1,l,l,l,!1,l,!1,l,l,l,l,l,l,l,l,l,l,s.ch,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,l,B.y,l)}}
C.a1U.prototype={
so7(d){if(J.c(this.dx,d))return
this.dx=d
this.a6()},
sn(d){if(this.dy===d)return
this.dy=d
this.a6()},
sQM(d){if(this.fr==d)return
this.fr=d
this.a6()},
scw(d){if(J.c(this.fx,d))return
this.fx=d
this.a6()},
sel(d){if(J.c(this.fy,d))return
this.fy=d
this.a6()},
shv(d){if(this.go==d)return
this.go=d
this.a6()},
CB(d,e,f,g,h){var x,w,v,u,t=this
if(t.go===B.aI){x=t.ax
x.toString
w=!(x&&h)
x=w}else x=!1
if(x){x=A.bk(f.r)
w=t.ax
w.toString
x=A.ad(B.c.aH(255*(w?0.14:0.08)),x.q()>>>16&255,x.q()>>>8&255,x.q()&255)
v=A.bk(f.r)
w=t.ax
w.toString
x=A.b([x,A.ad(B.c.aH(255*(w?0.29:0.14)),v.q()>>>16&255,v.q()>>>8&255,v.q()&255)],y.O)
$.a4()
u=A.aO()
u.sIv(new A.EF(B.hU,B.jv,B.fq,x,null,null).a3Z(e))
t.fx.lG(d,e,u)}else t.fx.lG(d,e,f)
t.fx.hK(g).b4(d,e)},
b4(d,e){var x,w,v,u,t,s,r,q,p,o,n,m=this,l=$.a4(),k=A.aO()
k.r=m.dx.gn()
k.b=B.bc
k.c=2
k.d=B.mk
x=y.H.a(e.f5(0,2).ae(0,D.LN.f5(0,2)))
w=x.a
v=x.b
u=new A.C(w,v,w+14,v+14)
t=A.aO()
s=m.dy
if(s!==!1){s=m.ax
s.toString}else s=!1
if(s){s=m.e
s.toString}else{s=m.f
s.toString}t.r=s.gn()
s=m.dy
switch(s){case!1:l=m.fy
l.toString
m.CB(d,u,t,l,s!==!1)
break
case!0:r=m.fy
r.toString
m.CB(d,u,t,r,s!==!1)
q=new A.bU(l.r,B.U,null,null,A.b([],y.v))
q.aD(new A.eE(w+3.08,v+7.5600000000000005))
l=w+5.6000000000000005
s=v+10.5
q.aD(new A.cu(l,s))
q.aD(new A.eE(l,s))
q.aD(new A.cu(w+10.92,v+3.5))
d.iF(q,k)
break
case null:case void 0:l=m.fy
l.toString
m.CB(d,u,t,l,s!==!1)
d.lp(x.X(0,D.aa5),x.X(0,D.aaj),k)
break}if(m.Q!=null){p=A.aO()
p.r=(m.go===B.aF?A.ad(38,B.q.q()>>>16&255,B.q.q()>>>8&255,B.q.q()&255):A.ad(38,B.n.q()>>>16&255,B.n.q()>>>8&255,B.n.q()&255)).gn()
m.fx.lG(d,u,p)}l=m.as
l.toString
if(l){o=u.dO(1)
n=A.aO()
n.r=m.y.gn()
n.b=B.bc
n.c=3.5
l=m.fy
l.toString
w=m.dy
m.CB(d,o,n,l,w!==!1)}}}
C.NI.prototype={
cI(){this.dg()
this.d8()
this.f9()},
k(){var x=this,w=x.bU$
if(w!=null)w.L(x.gf0())
x.bU$=null
x.an()}}
C.NJ.prototype={
ak(){var x,w=this,v=null
w.aC()
x=A.by(v,B.L,v,1,!w.a.c?0:1,w)
w.jc$=x
w.fW$=A.bJ(B.cB,x,B.df)
x=A.by(v,w.t8$,v,1,v,w)
w.iM$=x
w.iN$=A.bJ(B.Y,x,v)
x=A.by(v,B.dJ,v,1,w.jT$||w.jS$?1:0,w)
w.lv$=x
w.jQ$=A.bJ(B.Y,x,v)
x=A.by(v,B.dJ,v,1,w.jT$||w.jS$?1:0,w)
w.lw$=x
w.jR$=A.bJ(B.Y,x,v)},
k(){var x=this,w=x.jc$
w===$&&A.a()
w.k()
w=x.fW$
w===$&&A.a()
w.k()
w=x.iM$
w===$&&A.a()
w.k()
w=x.iN$
w===$&&A.a()
w.k()
w=x.lv$
w===$&&A.a()
w.k()
w=x.jQ$
w===$&&A.a()
w.k()
w=x.lw$
w===$&&A.a()
w.k()
w=x.jR$
w===$&&A.a()
w.k()
x.aqD()}}
C.azQ.prototype={
M(){return"_CheckboxType."+this.b}}
C.wc.prototype={
Y(){return new C.a1V(new C.a1T($.ab()),$,$,$,$,$,$,$,$,B.aZ,$,null,!1,!1,null,null)}}
C.a1V.prototype={
ak(){this.aqz()
this.e=this.a.c},
b1(d){var x,w=this
w.bx(d)
x=d.c
if(x!==w.a.c){w.e=x
w.yZ()}},
k(){this.d.k()
this.aqy()},
ghQ(){return this.a.d},
gu0(){this.a.toString
return!1},
gn(){return this.a.c},
gV5(){return new A.aE(new C.azO(this),y.b)},
uv(d,e){if(d instanceof A.jn)return A.bF(d,e,y.z)
if(!e.m(0,B.r))return d
return null},
E(a7){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5=this,a6=null
switch(a5.a.dx.a){case 0:break
case 1:switch(A.l(a7).w.a){case 0:case 1:case 3:case 5:break
case 2:case 4:x=a5.a
return new C.wz(x.c,x.d,x.e,x.f,x.w,!1,a6,a6,!1,x.cx,x.CW,x.db,a6)}break}w=C.b_v(a7)
A.l(a7)
v=new C.azJ(A.l(a7),A.l(a7).ax,a6,a6,a6,a6,a6,a6,a6,a6,a6)
u=a5.a.y
a5.a.toString
t=v.geF()
switch(u.a){case 0:x=B.jc
break
case 1:x=B.qn
break
default:x=a6}s=x.X(0,new A.f(t.a,t.b).ap(0,4))
r=a5.gex()
r.G(0,B.r)
q=a5.gex()
q.J(0,B.r)
a5.a.toString
p=a5.gV5().a.$1(r)
if(p==null){x=w.b
p=x==null?a6:x.P(r)}x=p==null
if(x){o=v.gfY().a.$1(r)
o.toString
n=o}else n=p
a5.a.toString
m=a5.gV5().a.$1(q)
if(m==null){o=w.b
m=o==null?a6:o.P(q)}o=m==null
if(o){l=v.gfY().a.$1(q)
l.toString
k=l}else k=m
l=a5.uv(a5.a.cx,r)
j=l==null?a5.uv(w.x,r):l
if(j==null){l=a5.uv(v.gel(),r)
l.toString
j=l}l=a5.uv(a5.a.cx,q)
i=l==null?a5.uv(w.x,q):l
if(i==null){l=a5.uv(v.gel(),q)
l.toString
i=l}h=a5.gex()
h.G(0,B.C)
a5.a.toString
l=w.d
g=l==null?a6:l.P(h)
f=g
if(f==null){g=v.gcU().a.$1(h)
g.toString
f=g}e=a5.gex()
e.G(0,B.D)
a5.a.toString
g=l==null?a6:l.P(e)
d=g
if(d==null){g=v.gcU().a.$1(e)
g.toString
d=g}r.G(0,B.K)
a5.a.toString
g=l==null?a6:l.P(r)
if(g==null){x=x?a6:p.ek(31)
a0=x}else a0=g
if(a0==null){x=v.gcU().a.$1(r)
x.toString
a0=x}q.G(0,B.K)
a5.a.toString
x=l==null?a6:l.P(q)
if(x==null){x=o?a6:m.ek(31)
a1=x}else a1=x
if(a1==null){x=v.gcU().a.$1(q)
x.toString
a1=x}if(a5.kv$!=null){d=a5.gex().m(0,B.r)?a0:a1
f=a5.gex().m(0,B.r)?a0:a1}a5.a.toString
a2=a5.gex()
x=a5.a.w
o=w.c
x=o==null?a6:o.P(a2)
a3=x
if(a3==null){x=v.go7().P(a2)
x.toString
a3=x}a5.a.toString
a4=w.e
if(a4==null)a4=v.gir()
x=a5.a
o=x.db
x=x.c
l=a5.d
g=a5.fW$
g===$&&A.a()
l.scQ(g)
g=a5.iN$
g===$&&A.a()
l.sB_(g)
g=a5.jR$
g===$&&A.a()
l.sQU(g)
g=a5.jQ$
g===$&&A.a()
l.sQV(g)
l.sPN(a1)
l.sQT(a0)
l.sPL(d)
l.szV(f)
l.sir(a4)
l.szB(a5.kv$)
l.skF(a5.gex().m(0,B.C))
l.sGo(a5.gex().m(0,B.D))
l.syS(n)
l.sAa(k)
l.so7(a3)
l.sn(a5.a.c)
l.sQM(a5.e)
a5.a.toString
g=w.w
l.scw(g==null?v.gcw():g)
l.sNg(j)
l.sPO(i)
return A.b8(a6,a6,x,a5.a36(!1,a6,new A.aE(new C.azP(a5,w),y.F),l,s),!1,a6,a6,a6,!1,a6,!1,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,o,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,a6,B.y,a6)}}
C.a1T.prototype={
so7(d){if(J.c(this.dx,d))return
this.dx=d
this.a6()},
sn(d){if(this.dy===d)return
this.dy=d
this.a6()},
sQM(d){if(this.fr==d)return
this.fr=d
this.a6()},
scw(d){if(J.c(this.fx,d))return
this.fx=d
this.a6()},
sNg(d){if(J.c(this.fy,d))return
this.fy=d
this.a6()},
sPO(d){if(J.c(this.go,d))return
this.go=d
this.a6()},
Z8(d,e){var x=1-Math.abs(e-0.5)*2,w=18-x*2,v=d.a+x,u=d.b+x
return new A.C(v,u,v+w,u+w)},
Vm(d){var x,w=this.e
if(d>=0.25)w.toString
else{x=this.f
x.toString
w.toString
w=A.M(x,w,d*4)
w.toString}return w},
Jy(d,e,f,g){var x=this.fx.ghA(),w=this.fx
if(x)w.lG(d,e,f)
else d.iF(w.qG(e),f)
this.fx.hK(g).b4(d,e)},
K8(d,e,f,g){var x,w=new A.bU($.a4().r,B.U,null,null,A.b([],y.v)),v=e.a,u=e.b,t=v+2.6999999999999997,s=u+8.1
if(f<0.5){x=A.jI(D.aa2,D.GM,f*2)
x.toString
w.aD(new A.eE(t,s))
w.aD(new A.cu(v+x.a,u+x.b))}else{x=A.jI(D.GM,D.aac,(f-0.5)*2)
x.toString
w.aD(new A.eE(t,s))
w.aD(new A.cu(v+7.2,u+12.6))
w.aD(new A.cu(v+x.a,u+x.b))}d.iF(w,g)},
K9(d,e,f,g){var x,w=A.jI(D.aa3,D.GL,1-f)
w.toString
x=A.jI(D.GL,D.aa6,f)
x.toString
d.lp(e.X(0,w),e.X(0,x),g)},
b4(d,e){var x,w,v,u,t,s,r,q,p,o,n=this
n.QE(d,e.j6(B.f))
$.a4()
x=A.aO()
x.r=n.dx.gn()
x.b=B.bc
x.c=2
w=y.H.a(e.f5(0,2).ae(0,B.LO.f5(0,2)))
v=n.a.a.gb9()
A:{if(B.bW===v||B.ak===v){u=n.a.gn()
break A}if(B.bg===v||B.S===v){u=1-n.a.gn()
break A}u=null}if(n.fr===!1||n.dy===!1){t=n.dy===!1?1-u:u
s=n.Z8(w,t)
r=A.aO()
r.r=n.Vm(t).gn()
u=n.fy
if(t<=0.5){q=n.go
q.toString
u.toString
n.Jy(d,s,r,A.bi(q,u,t))}else{u.toString
n.Jy(d,s,r,u)
p=(t-0.5)*2
if(n.fr==null||n.dy==null)n.K9(d,w,p,x)
else n.K8(d,w,p,x)}}else{s=n.Z8(w,1)
r=A.aO()
r.r=n.Vm(1).gn()
q=n.fy
q.toString
n.Jy(d,s,r,q)
if(u<=0.5){p=1-u*2
u=n.fr
if(u===!0)n.K8(d,w,p,x)
else n.K9(d,w,p,x)}else{o=(u-0.5)*2
u=n.dy
if(u===!0)n.K8(d,w,o,x)
else n.K9(d,w,o,x)}}}}
C.azJ.prototype={
gel(){return A.aY2(new C.azN(this))},
gfY(){return new A.aE(new C.azL(this),y.k)},
go7(){return new A.aE(new C.azK(this),y.k)},
gcU(){return new A.aE(new C.azM(this),y.k)},
gir(){return 20},
gkK(){return this.y.f},
geF(){return B.hC},
gcw(){return B.pR}}
C.ND.prototype={
cI(){this.dg()
this.d8()
this.f9()},
k(){var x=this,w=x.bU$
if(w!=null)w.L(x.gf0())
x.bU$=null
x.an()}}
C.NE.prototype={
ak(){var x,w=this,v=null
w.aC()
x=A.by(v,B.L,v,1,!w.a.c?0:1,w)
w.jc$=x
w.fW$=A.bJ(B.cB,x,B.df)
x=A.by(v,w.t8$,v,1,v,w)
w.iM$=x
w.iN$=A.bJ(B.Y,x,v)
x=A.by(v,B.dJ,v,1,w.jT$||w.jS$?1:0,w)
w.lv$=x
w.jQ$=A.bJ(B.Y,x,v)
x=A.by(v,B.dJ,v,1,w.jT$||w.jS$?1:0,w)
w.lw$=x
w.jR$=A.bJ(B.Y,x,v)},
k(){var x=this,w=x.jc$
w===$&&A.a()
w.k()
w=x.fW$
w===$&&A.a()
w.k()
w=x.iM$
w===$&&A.a()
w.k()
w=x.iN$
w===$&&A.a()
w.k()
w=x.lv$
w===$&&A.a()
w.k()
w=x.jQ$
w===$&&A.a()
w.k()
w=x.lw$
w===$&&A.a()
w.k()
w=x.jR$
w===$&&A.a()
w.k()
x.aqx()}}
C.azR.prototype={
M(){return"_CheckboxType."+this.b}}
C.Cj.prototype={
aBZ(){var x=this
switch(x.c){case!1:x.d.$1(!0)
break
case!0:x.d.$1(!1)
break
case null:case void 0:x.d.$1(!1)
break}},
E(d){var x,w,v,u,t,s,r,q,p,o,n,m=this,l=null
switch(0){case 0:x=new A.t_(!0,new C.wc(m.c,m.d,l,l,l,l,!1,B.iR,l,l,l,!1,l,l,!1,l,D.aqA,l),l)
break}w=A.Ud(d)
v=m.go
u=v==null?w.db:v
if(u==null)u=B.kJ
A:{if(B.vy===u){v=new A.Y(x,l)
break A}if(B.h5===u||B.kJ===u){v=new A.Y(l,x)
break A}v=l}t=v.a
s=l
r=v.b
s=r
q=A.l(d)
p=C.b_v(d)
v=p.b
v=v==null?l:v.P(A.az(y.C))
o=v
if(o==null)o=q.ax.y
v=m.d!=null
n=v?m.gaBY():l
return new A.pu(A.cn(!1,m.id,l,l,v,l,l,l,!1,l,t,l,l,l,l,n,!1,o,l,l,l,l,m.dx,l,m.db,l,s,l),l)}}
C.a97.prototype={
a35(d,e,f){var x=null
return A.dX(A.b([this.ax],y.n),x,x,x,x,x,x,x,x,e,x)}}
C.a7U.prototype={
GT(d){if(!this.a.gio())return
this.ap2(d)
this.x.a.toString}}
C.GY.prototype={
Y(){return new C.Mj(new A.aV(null,y.g))}}
C.Mj.prototype={
grf(){var x,w=null
this.a.toString
x=this.e
if(x==null){x=A.hL(!0,w,!0,!0,w,w,!0)
this.e=x}return x},
gPb(){var x=this.w
x===$&&A.a()
return x},
gio(){this.a.toString
return!0},
ak(){var x,w=this,v=null
w.aC()
w.r=new C.a7U(w,w)
x=A.dX(v,v,v,v,v,v,v,v,v,v,w.a.c)
x=C.b4v(x)
w.d=x
x.Z(w.gZ1())
w.grf().Z(w.ga_F())},
b1(d){var x,w,v=this,u=null
v.bx(d)
x=v.a.c
if(x!==d.c){x=v.d
x===$&&A.a()
w=v.gZ1()
x.L(w)
x=v.d
x.fx$=$.ab()
x.fr$=0
x=A.dX(u,u,u,u,u,u,u,u,u,u,v.a.c)
x=C.b4v(x)
v.d=x
x.Z(w)}v.a.toString
if(v.grf().gck()){x=v.d
x===$&&A.a()
x=x.a.b
x=x.a===x.b}else x=!1
if(x)v.f=!1
else v.f=!0},
k(){var x,w=this
w.grf().L(w.ga_F())
x=w.e
if(x!=null)x.k()
x=w.d
x===$&&A.a()
x.fx$=$.ab()
x.fr$=0
w.an()},
aDT(){var x,w,v=this
if(v.grf().gck()){x=v.d
x===$&&A.a()
x=x.a.b
w=x.a!==x.b}else w=!0
if(w===v.f)return
v.F(new C.aOC(v,w))},
aHp(){if(!this.grf().gck()&&$.c_.k3$===B.dA){var x=this.d
x===$&&A.a()
x.jy(new A.cv(x.a.a,B.c3,B.aC))}},
aHr(d,e){var x,w=this,v=w.aHu(e)
if(v!==w.f)w.F(new C.aOB(w,v))
w.a.toString
x=w.c
x.toString
switch(A.l(x).w.a){case 2:case 4:if(e===B.c_){x=w.x.gT()
if(x!=null)x.lh(d.go5())}return
case 0:case 1:case 3:case 5:break}},
aHt(){var x=this.d
x===$&&A.a()
x=x.a.b
if(x.a===x.b)this.x.gT().Rl()},
aHu(d){var x,w=this.r
w===$&&A.a()
if(!w.b)return!1
w=this.d
w===$&&A.a()
w=w.a
x=w.b
if(x.a===x.b)return!1
if(d===B.b0)return!1
if(d===B.c_)return!0
if(w.a.length!==0)return!0
return!1},
E(d){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h=this,g=null,f=A.l(d),e=d.ab(y.Z)
if(e==null)e=B.eN
x=h.grf()
h.a.toString
w=!0
v=!0
u=g
t=g
switch(f.w.a){case 2:s=A.ls(d)
h.w=!0
r=$.aZI()
h.a.toString
q=e.w
if(q==null)q=s.gfv()
p=e.x
if(p==null)p=s.gfv().be(0.4)
u=new A.f(-2/A.ac(d,B.d9,y.w).w.b,0)
t=B.ei
break
case 4:s=A.ls(d)
h.w=!1
r=$.aZH()
h.a.toString
q=e.w
if(q==null)q=s.gfv()
p=e.x
if(p==null)p=s.gfv().be(0.4)
u=new A.f(-2/A.ac(d,B.d9,y.w).w.b,0)
t=B.ei
break
case 0:case 1:h.w=!1
r=$.aZR()
q=e.w
if(q==null)q=f.ax.b
p=e.x
if(p==null)p=f.ax.b.be(0.4)
w=!1
v=!1
break
case 3:case 5:h.w=!1
r=$.aVf()
q=e.w
if(q==null)q=f.ax.b
p=e.x
if(p==null)p=f.ax.b.be(0.4)
w=!1
v=!1
break
default:p=g
q=p
v=q
w=v
r=w}o=d.ab(y.D)
if(o==null)o=B.tT
n=h.a.f
m=n==null
if(m||n.a){if(m){m=h.d
m===$&&A.a()
m=m.ax.a}else m=n
n=o.w.c1(m)}h.a.toString
A:{break A}m=h.f
l=h.d
l===$&&A.a()
k=o.x
if(k==null)k=B.ae
j=r
i=$.aZd()
m=A.b0i(g,g,g,g,!1,B.fN,B.O,g,C.bmV(),l,q,g,u,v,t,2,B.a0,!0,g,!0,!0,!1,x,!1,B.b9,g,g,h.x,B.aF,g,i,o.Q,g,g,!1,"\u2022",g,g,g,h.gaHq(),h.gaHs(),g,g,g,w,!0,!0,g,!0,g,g,B.aG,g,g,p,j,g,g,!1,m,g,g,g,D.afF,n,!0,k,B.bE,g,o.at,g,g,o.as,g,g)
h.a.toString
l=h.r
l===$&&A.a()
return A.b8(g,g,g,l.a3_(B.cF,new A.hR(m,g)),!1,g,g,g,!1,g,!1,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,new C.aOD(h),g,g,g,g,g,g,g,g,g,g,g,g,B.y,g)},
gal(){return this.x}}
var z=a.updateTypes(["~()","~(uO)","~(hd,is?)","e(u,iO)"])
C.aAo.prototype={
$1(d){var x,w
if(d.m(0,B.w))return A.ad(B.c.aH(127.5),B.n.q()>>>16&255,B.n.q()>>>8&255,B.n.q()&255)
if(d.m(0,B.r)){x=this.a
w=x.a.f
x=x.c
x.toString
x=B.tM.dc(x)
return x}return B.n},
$S:4}
C.aAn.prototype={
$1(d){var x,w
if(d.m(0,B.w)&&d.m(0,B.r)){x=this.a
w=x.a.x
x=x.c
x.toString
x=B.tL.dc(x)
return x}if(d.m(0,B.r)){x=this.a
w=x.a.x
x=x.c
x.toString
x=B.tP.dc(x)
return x}return B.n},
$S:4}
C.aAp.prototype={
$1(d){var x
if((d.m(0,B.r)||d.m(0,B.C))&&!d.m(0,B.w))return D.rw
if(d.m(0,B.w)){x=this.a.c
x.toString
x=D.RG.dc(x)
return new A.aG(x,1,B.x,-1)}x=this.a.c
x.toString
x=D.RI.dc(x)
return new A.aG(x,1,B.x,-1)},
$S:68}
C.aAq.prototype={
$1(d){var x=A.bF(this.a.a.e,d,y.h)
if(x==null){x=d.m(0,B.w)
x=!x?B.hv:B.cw}return x},
$S:41}
C.azO.prototype={
$1(d){if(d.m(0,B.w))return null
if(d.m(0,B.r))return this.a.a.f
return null},
$S:17}
C.azP.prototype={
$1(d){var x=A.bF(this.a.a.e,d,y.h)
if(x==null)x=null
return x==null?A.aXy(d):x},
$S:41}
C.azN.prototype={
$1(d){var x,w,v=this
if(d.m(0,B.w)){if(d.m(0,B.r))return D.O7
x=v.a.z.k3
return new A.aG(A.ad(97,x.q()>>>16&255,x.q()>>>8&255,x.q()&255),2,B.x,-1)}if(d.m(0,B.r))return D.rw
if(d.m(0,B.cN))return new A.aG(v.a.z.fy,2,B.x,-1)
if(d.m(0,B.K))return new A.aG(v.a.z.k3,2,B.x,-1)
if(d.m(0,B.D))return new A.aG(v.a.z.k3,2,B.x,-1)
if(d.m(0,B.C))return new A.aG(v.a.z.k3,2,B.x,-1)
x=v.a.z
w=x.rx
return new A.aG(w==null?x.k3:w,2,B.x,-1)},
$S:68}
C.azL.prototype={
$1(d){var x
if(d.m(0,B.w)){if(d.m(0,B.r)){x=this.a.z.k3
return A.ad(97,x.q()>>>16&255,x.q()>>>8&255,x.q()&255)}return B.z}if(d.m(0,B.r)){if(d.m(0,B.cN))return this.a.z.fy
return this.a.z.b}return B.z},
$S:4}
C.azK.prototype={
$1(d){if(d.m(0,B.w)){if(d.m(0,B.r))return this.a.z.k2
return B.z}if(d.m(0,B.r)){if(d.m(0,B.cN))return this.a.z.go
return this.a.z.c}return B.z},
$S:4}
C.azM.prototype={
$1(d){var x,w=this
if(d.m(0,B.cN)){if(d.m(0,B.K)){x=w.a.z.fy
return A.ad(B.c.aH(25.5),x.q()>>>16&255,x.q()>>>8&255,x.q()&255)}if(d.m(0,B.D)){x=w.a.z.fy
return A.ad(20,x.q()>>>16&255,x.q()>>>8&255,x.q()&255)}if(d.m(0,B.C)){x=w.a.z.fy
return A.ad(B.c.aH(25.5),x.q()>>>16&255,x.q()>>>8&255,x.q()&255)}}if(d.m(0,B.r)){if(d.m(0,B.K)){x=w.a.z.k3
return A.ad(B.c.aH(25.5),x.q()>>>16&255,x.q()>>>8&255,x.q()&255)}if(d.m(0,B.D))return w.a.z.b.be(0.08)
if(d.m(0,B.C))return w.a.z.b.be(0.1)
return B.z}if(d.m(0,B.K))return w.a.z.b.be(0.1)
if(d.m(0,B.D)){x=w.a.z.k3
return A.ad(20,x.q()>>>16&255,x.q()>>>8&255,x.q()&255)}if(d.m(0,B.C)){x=w.a.z.k3
return A.ad(B.c.aH(25.5),x.q()>>>16&255,x.q()>>>8&255,x.q()&255)}return B.z},
$S:4}
C.aOC.prototype={
$0(){this.a.f=this.b},
$S:0}
C.aOB.prototype={
$0(){this.a.f=this.b},
$S:0}
C.aOD.prototype={
$0(){this.a.grf().fd()},
$S:0};(function aliases(){var x=C.NI.prototype
x.aqD=x.k
x=C.NJ.prototype
x.aqF=x.ak
x.aqE=x.k
x=C.ND.prototype
x.aqx=x.k
x=C.NE.prototype
x.aqz=x.ak
x.aqy=x.k})();(function installTearOffs(){var x=a._instance_0u,w=a._static_2,v=a._instance_1u,u=a._instance_2u
x(C.Cj.prototype,"gaBY","aBZ",0)
w(C,"bmV","bfo",3)
v(C.a7U.prototype,"gaiI","GT",1)
var t
x(t=C.Mj.prototype,"gZ1","aDT",0)
x(t,"ga_F","aHp",0)
u(t,"gaHq","aHr",2)
x(t,"gaHs","aHt",0)})();(function inheritance(){var x=a.mixinHard,w=a.inherit,v=a.inheritMany
w(C.aEB,A.Q)
v(A.N,[C.wz,C.wc,C.GY])
v(A.O,[C.NI,C.ND,C.Mj])
w(C.NJ,C.NI)
w(C.a2p,C.NJ)
v(A.cg,[C.aAo,C.aAn,C.aAp,C.aAq,C.azO,C.azP,C.azN,C.azL,C.azK,C.azM])
v(A.qr,[C.a1U,C.a1T])
v(A.fW,[C.azQ,C.azR])
w(C.NE,C.ND)
w(C.a1V,C.NE)
w(C.azJ,A.wd)
w(C.Cj,A.X)
w(C.a97,A.et)
w(C.a7U,A.yY)
v(A.e4,[C.aOC,C.aOB,C.aOD])
x(C.NI,A.dI)
x(C.NJ,A.he)
x(C.ND,A.dI)
x(C.NE,A.he)})()
A.cI(b.typeUniverse,JSON.parse('{"wz":{"N":[],"e":[]},"a2p":{"he":["wz"],"O":["wz"]},"a1U":{"ai":[]},"wc":{"N":[],"e":[]},"a1V":{"he":["wc"],"O":["wc"]},"a1T":{"ai":[]},"Cj":{"X":[],"e":[]},"GY":{"N":[],"e":[]},"a97":{"et":[],"cj":["cv"],"ai":[]},"Mj":{"O":["GY"]},"ba6":{"aU":[],"aQ":[],"e":[]}}'))
var y=(function rtii(){var x=A.V
return{K:x("ba6"),Z:x("mV"),D:x("rP"),O:x("o<L>"),v:x("o<dg>"),n:x("o<ec>"),g:x("aV<iO>"),w:x("eD"),H:x("f"),N:x("j"),C:x("c4"),P:x("aE<aG>"),k:x("aE<L>"),F:x("aE<dd>"),b:x("aE<L?>"),z:x("aG?"),h:x("dd?")}})();(function constants(){D.rw=new A.aG(B.z,0,B.x,-1)
D.O7=new A.aG(B.z,2,B.x,-1)
D.dF=new A.L(0.050980392156862744,0,0,0,B.j)
D.RG=new A.cA(D.dF,null,null,D.dF,D.dF,D.dF,D.dF,D.dF,D.dF,D.dF,D.dF)
D.jY=new A.L(0.19607843137254902,0.5019607843137255,0.5019607843137255,0.5019607843137255,B.j)
D.RI=new A.cA(B.de,null,null,B.de,D.jY,B.de,D.jY,B.de,D.jY,B.de,D.jY)
D.aa2=new A.f(2.6999999999999997,8.1)
D.aa3=new A.f(3.6,9)
D.aa5=new A.f(3.5,7)
D.GL=new A.f(9,9)
D.aa6=new A.f(14.4,9)
D.GM=new A.f(7.2,12.6)
D.aac=new A.f(15.299999999999999,4.5)
D.aaj=new A.f(10.5,7)
D.LN=new A.r(14,14)
D.afF=new A.uL(null,null,null,null,null,null,null,null,null,null,null)
D.aqA=new C.azQ(0,"material")
D.asz=new C.azR(0,"material")})();(function lazyInitializers(){var x=a.lazyFinal
x($,"bp4","b7z",()=>{var w=new C.aEB(A.bdu(8))
w.arV()
return w})})()};
(a=>{a["eCZk57MKjKNn2dQhlzGp6K1XOVU="]=a.current})($__dart_deferred_initializers__);