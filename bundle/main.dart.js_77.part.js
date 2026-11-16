((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,F,G,E,H,B={iu:function iu(d,e,f){this.c=d
this.d=e
this.a=f},Lm:function Lm(){var _=this
_.d=$
_.e=null
_.f=""
_.c=_.a=null},aIv:function aIv(d,e){this.a=d
this.b=e},aIw:function aIw(d,e){this.a=d
this.b=e},aIt:function aIt(d,e){this.a=d
this.b=e},aIs:function aIs(d){this.a=d},aIu:function aIu(d,e){this.a=d
this.b=e}},D
J=c[1]
A=c[0]
C=c[2]
F=c[56]
G=c[60]
E=c[3]
H=c[65]
B=a.updateHolder(c[37],B)
D=c[151]
B.iu.prototype={
X(){return new B.Lm()}}
B.Lm.prototype={
gqd(){var x=this.d
return x===$?this.d=this.a.d:x},
ai(){this.aA()
this.kT()},
kT(){var x=0,w=A.w(y.f),v,u=2,t=[],s=this,r,q,p,o
var $async$kT=A.x(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return A.h(s.a.c.dn("GET","/api/v1/jobs/"+A.n(s.gqd().h(0,"id"))),$async$kT)
case 7:r=e
if(s.c==null){x=1
break}s.F(new B.aIv(s,r))
if(!C.b.m(A.b(["completed","failed"],y.h),s.gqd().h(0,"status")))s.e=A.cc(C.kg,s.gHf())
u=2
x=6
break
case 4:u=3
o=t.pop()
q=A.am(o)
if(s.c!=null)s.F(new B.aIw(s,q))
x=6
break
case 3:x=2
break
case 6:case 1:return A.u(v,w)
case 2:return A.t(t.at(-1),w)}})
return A.v($async$kT,w)},
E(d){var x=this,w=null,v="status",u=y.e,t=A.b([],u),s=x.f
if(s.length!==0)t.push(new A.dx(s,x.gHf(),w))
if(!C.b.m(A.b(["completed","failed"],y.h),x.gqd().h(0,v)))C.b.O(t,A.b([H.cr,F.dF("Preparing your note",!0),D.anv],u))
if(J.c(x.gqd().h(0,v),"failed"))C.b.O(t,A.b([new A.dx(A.W(A.cu(x.gqd().h(0,"error")).h(0,"message")),w,w),A.cA(C.mG,new B.aIt(x,d),w)],u))
if(J.c(x.gqd().h(0,v),"completed"))C.b.O(t,A.b([F.dF("Ready",!0),A.jG(D.amF,new B.aIu(x,d),w)],u))
return E.dn(C.az,w,A.cp(t,w,w,C.fT,w,w,C.F,!1),!1,!0,!1,!1,!0,"Processing")},
k(){var x=this.e
if(x!=null)x.bW()
this.am()}}
var z=a.updateTypes(["af<~>()"])
B.aIv.prototype={
$0(){var x=this.a
x.d=this.b
x.f=""},
$S:0}
B.aIw.prototype={
$0(){return this.a.f=A.fD(this.b)},
$S:0}
B.aIt.prototype={
$0(){return A.bP(this.b,new B.aIs(this.a))},
$S:0}
B.aIs.prototype={
$0(){var x=0,w=A.w(y.f),v=this,u,t
var $async$$0=A.x(function(d,e){if(d===1)return A.t(e,w)
for(;;)switch(x){case 0:u=v.a
t=u
x=2
return A.h(u.a.c.dn("POST","/api/v1/jobs/"+A.n(u.gqd().h(0,"id"))+"/retry"),$async$$0)
case 2:t.d=e
x=3
return A.h(u.kT(),$async$$0)
case 3:return A.u(null,w)}})
return A.v($async$$0,w)},
$S:2}
B.aIu.prototype={
$0(){var x=0,w=A.w(y.f),v=this,u,t
var $async$$0=A.x(function(d,e){if(d===1)return A.t(e,w)
for(;;)switch(x){case 0:u=v.a
t=A.cu(u.gqd().h(0,"result"))
x=t.h(0,"note_id")!=null?2:4
break
case 2:x=5
return A.h(E.bH(v.b,G.apX(u.a.c,A.W(t.h(0,"note_id")),null),y.b),$async$$0)
case 5:x=3
break
case 4:x=t.h(0,"recording_id")!=null?6:7
break
case 6:x=8
return A.h(E.bH(v.b,G.X7(u.a.c,A.W(t.h(0,"recording_id")),null),y.b),$async$$0)
case 8:case 7:case 3:return A.u(null,w)}})
return A.v($async$$0,w)},
$S:2};(function installTearOffs(){var x=a._instance_0u
x(B.Lm.prototype,"gHf","kT",0)})();(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.iu,A.M)
x(B.Lm,A.O)
w(A.dN,[B.aIv,B.aIw,B.aIt,B.aIs,B.aIu])})()
A.cs(b.typeUniverse,JSON.parse('{"iu":{"M":[],"e":[]},"Lm":{"O":["iu"]}}'))
var y={h:A.T("o<j>"),e:A.T("o<e>"),b:A.T("@"),f:A.T("~")};(function constants(){D.amF=new A.a5("Open result",null,null,null,null,null)
D.anv=new A.a5("You can leave this page. Processing continues in the background.",null,null,null,null,null)})()};
(a=>{a["1qz/dgT9tLB3NSiE2GgfQDfbITw="]=a.current})($__dart_deferred_initializers__);