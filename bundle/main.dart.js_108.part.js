((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,G,K,B={
aYm(d,e,f,g,h,i){return new B.TJ(d,i,f,e,h,g,null)},
Bs(d,e,f,g){return B.bnn(d,e,f,g)},
bnn(d,e,f,g){var x=0,w=A.v(y.A),v,u
var $async$Bs=A.w(function(h,i){if(h===1)return A.r(i,w)
for(;;)switch(x){case 0:u={}
u.a=g
u.b=null
v=M.rv(null,null,new B.aVO(u,e,f),d,!0,null,!1,y.y)
x=1
break
case 1:return A.t(v,w)}})
return A.u($async$Bs,w)},
TJ:function TJ(d,e,f,g,h,i,j){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.a=j},
aja:function aja(d,e){this.a=d
this.b=e},
aj9:function aj9(d,e){this.a=d
this.b=e},
aVO:function aVO(d,e,f){this.a=d
this.b=e
this.c=f},
aVN:function aVN(d,e,f){this.a=d
this.b=e
this.c=f},
aVK:function aVK(d,e){this.a=d
this.b=e},
aVH:function aVH(d,e){this.a=d
this.b=e},
aVJ:function aVJ(d,e){this.a=d
this.b=e},
aVI:function aVI(d,e){this.a=d
this.b=e},
aVL:function aVL(d,e,f){this.a=d
this.b=e
this.c=f},
aVM:function aVM(d){this.a=d},
iA:function iA(d,e,f){this.c=d
this.d=e
this.a=f},
LD:function LD(){var _=this
_.d=$
_.e=null
_.f=""
_.c=_.a=null},
aK0:function aK0(d,e){this.a=d
this.b=e},
aK1:function aK1(d,e){this.a=d
this.b=e},
aJZ:function aJZ(d,e){this.a=d
this.b=e},
aJY:function aJY(d){this.a=d},
aK_:function aK_(d,e){this.a=d
this.b=e}},D,H,E,L,M,N,F,I
J=c[1]
A=c[0]
C=c[2]
G=c[59]
K=c[45]
B=a.updateHolder(c[36],B)
D=c[131]
H=c[74]
E=c[44]
L=c[123]
M=c[65]
N=c[72]
F=c[3]
I=c[56]
B.TJ.prototype={
D(d){var x,w,v,u=this,t=null,s="interface",r=u.c,q=u.f,p=u.e,o=p==null,n=o?s:p,m=r.gwx()
if(o)p=s
o=A.pm(t,t,t,t,t,t,t,t,!0,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,A.bi(d,"Output language"),!0,!0,!1,t,t,t,t,t,t,t,t,t,t,t,t,t,t)
x=A.bi(d,"Follow interface")
w=y.w
x=A.b([E.aY9(A.ai(x+" \xb7 "+A.bi(d,r.gwx()==="zh-CN"?"Chinese":"English"),t,t,t,t,t,t,t,t,t,t,t),s,w),E.aY9(A.ai(A.bi(d,"Chinese"),t,t,t,t,t,t,t,t,t,t,t),"zh-CN",w),E.aY9(A.ai(A.bi(d,"English"),t,t,t,t,t,t,t,t,t,t,t),"en-US",w)],y.D)
v=q?new B.aja(u,d):t
return A.aR(A.b([new K.FI(r,u.d,q,"This template",u.r,t),E.aY8(o,p,!0,x,new A.cC("output-language-"+n+"-"+m,y.q),v,w),D.qD,D.aoE],y.u),C.X,C.h,C.l,0,C.p)}}
B.iA.prototype={
V(){return new B.LD()}}
B.LD.prototype={
gqi(){var x=this.d
return x===$?this.d=this.a.d:x},
ah(){this.az()
this.kW()},
kW(){var x=0,w=A.v(y.v),v,u=2,t=[],s=this,r,q,p,o
var $async$kW=A.w(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return A.h(s.a.c.cT("GET","/api/v1/jobs/"+A.n(s.gqi().h(0,"id"))),$async$kW)
case 7:r=e
if(s.c==null){x=1
break}s.E(new B.aK0(s,r))
if(!C.b.m(A.b(["completed","failed"],y.x),s.gqi().h(0,"status")))s.e=A.cf(C.kj,s.gHp())
u=2
x=6
break
case 4:u=3
o=t.pop()
q=A.ak(o)
if(s.c!=null)s.E(new B.aK1(s,q))
x=6
break
case 3:x=2
break
case 6:case 1:return A.t(v,w)
case 2:return A.r(t.at(-1),w)}})
return A.u($async$kW,w)},
D(d){var x=this,w=null,v="status",u=y.u,t=A.b([],u),s=x.f
if(s.length!==0)t.push(new A.dI(s,x.gHp(),w))
if(!C.b.m(A.b(["completed","failed"],y.x),x.gqi().h(0,v)))C.b.N(t,A.b([N.cK,G.dr("Preparing your note",!0),D.aoy],u))
if(J.c(x.gqi().h(0,v),"failed"))C.b.N(t,A.b([new A.dI(A.U(A.bO(x.gqi().h(0,"error")).h(0,"message")),w,w),A.cl(C.r2,new B.aJZ(x,d),w)],u))
if(J.c(x.gqi().h(0,v),"completed"))C.b.N(t,A.b([G.dr("Ready",!0),A.fR(D.anl,new B.aK_(x,d),w)],u))
return F.cQ(C.al,w,A.c9(t,w,w,C.fZ,w,w,C.A,!1),!1,!0,!1,!1,!0,"Processing")},
k(){var x=this.e
if(x!=null)x.bU()
this.am()}}
var z=a.updateTypes(["a8<~>()"])
B.aja.prototype={
$1(d){A.bP(this.b,new B.aj9(this.a,d))},
$S:77}
B.aj9.prototype={
$0(){var x=this.b
if(x==="interface")x=null
return this.a.w.$1(x)},
$S:2}
B.aVO.prototype={
$1(d){return new A.o2(new B.aVN(this.a,this.b,this.c),null)},
$S:612}
B.aVN.prototype={
$2(d,e){var x=null,w=A.ae(d,C.fE,y.B).w,v=this.b,u=this.a,t=u.a
v=A.b([D.aoz,B.aYm(v,!0,u.b,new B.aVJ(u,e),new B.aVK(u,e),t),L.fs,A.fR(D.ano,new B.aVL(u,d,v),x)],y.u)
if(this.c)v.push(A.cl(D.N8,new B.aVM(d),x))
return A.dJ(!0,A.i0(A.aR(v,C.b5,C.h,C.a0,0,C.p),x,x,new A.a_(24,20,24,24+w.f.d),x,!1,C.A),!0,!1,C.u,!0,!0)},
$S:613}
B.aVK.prototype={
$1(d){return this.ap1(d)},
ap1(d){var x=0,w=A.v(y.v),v,u=this
var $async$$1=A.w(function(e,f){if(e===1)return A.r(f,w)
for(;;)switch(x){case 0:v=u.b.$1(new B.aVH(u.a,d))
x=1
break
case 1:return A.t(v,w)}})
return A.u($async$$1,w)},
$S:65}
B.aVH.prototype={
$0(){return this.a.a=this.b},
$S:0}
B.aVJ.prototype={
$1(d){return this.ap2(d)},
ap2(d){var x=0,w=A.v(y.v),v,u=this
var $async$$1=A.w(function(e,f){if(e===1)return A.r(f,w)
for(;;)switch(x){case 0:v=u.b.$1(new B.aVI(u.a,d))
x=1
break
case 1:return A.t(v,w)}})
return A.u($async$$1,w)},
$S:118}
B.aVI.prototype={
$0(){return this.a.b=this.b},
$S:0}
B.aVL.prototype={
$0(){var x=A.p(y.w,y.b),w=this.a
x.n(0,"template_id",w.a)
x.N(0,this.c.x9(w.b))
A.bm(this.b,!1).cr(x)
return null},
$S:0}
B.aVM.prototype={
$0(){var x=y.w
x=A.a1(["template_id","__transcript__"],x,x)
A.bm(this.a,!1).cr(x)
return null},
$S:0}
B.aK0.prototype={
$0(){var x=this.a
x.d=this.b
x.f=""},
$S:0}
B.aK1.prototype={
$0(){return this.a.f=A.eP(this.b)},
$S:0}
B.aJZ.prototype={
$0(){return A.bP(this.b,new B.aJY(this.a))},
$S:0}
B.aJY.prototype={
$0(){var x=0,w=A.v(y.v),v=this,u,t
var $async$$0=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:u=v.a
t=u
x=2
return A.h(u.a.c.cT("POST","/api/v1/jobs/"+A.n(u.gqi().h(0,"id"))+"/retry"),$async$$0)
case 2:t.d=e
x=3
return A.h(u.kW(),$async$$0)
case 3:return A.t(null,w)}})
return A.u($async$$0,w)},
$S:2}
B.aK_.prototype={
$0(){var x=0,w=A.v(y.v),v=this,u,t
var $async$$0=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:u=v.a
t=A.bO(u.gqi().h(0,"result"))
x=t.h(0,"note_id")!=null?2:4
break
case 2:x=5
return A.h(F.by(v.b,I.aqv(u.a.c,A.U(t.h(0,"note_id")),null),y.b),$async$$0)
case 5:x=3
break
case 4:x=t.h(0,"recording_id")!=null?6:7
break
case 6:x=8
return A.h(F.by(v.b,I.Xs(u.a.c,A.U(t.h(0,"recording_id")),null),y.b),$async$$0)
case 8:case 7:case 3:return A.t(null,w)}})
return A.u($async$$0,w)},
$S:2};(function installTearOffs(){var x=a._instance_0u
x(B.LD.prototype,"gHp","kW",0)})();(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.TJ,A.X)
w(A.ca,[B.aja,B.aVO,B.aVK,B.aVJ])
w(A.dk,[B.aj9,B.aVH,B.aVI,B.aVL,B.aVM,B.aK0,B.aK1,B.aJZ,B.aJY,B.aK_])
x(B.aVN,A.ee)
x(B.iA,A.K)
x(B.LD,A.N)})()
A.cc(b.typeUniverse,JSON.parse('{"TJ":{"X":[],"d":[]},"iA":{"K":[],"d":[]},"LD":{"N":["iA"]}}'))
var y=(function rtii(){var x=A.R
return{D:x("o<io<i>>"),x:x("o<i>"),u:x("o<d>"),y:x("a3<i,@>"),B:x("eC"),w:x("i"),q:x("cC<i>"),b:x("@"),A:x("a3<i,@>?"),v:x("~")}})();(function constants(){D.qD=new A.aW(null,6,null,null)
D.anl=new A.V("Open result",null,null,null,null,null)
D.ano=new A.V("Generate note",null,null,null,null,null)
D.aoy=new A.V("You can leave this page. Processing continues in the background.",null,null,null,null,null)
D.aoz=new A.V("Generation options",H.Mx,null,null,null,null)
D.aoE=new A.V("Applies to this file only. Saved notes are unchanged.",H.fv,null,null,null,null)
D.N8=new A.V("Transcript",null,null,null,null,null)})()};
(a=>{a["tRA3wNXuNYz6+MUw7t6YHMXf5mM="]=a.current})($__dart_deferred_initializers__);