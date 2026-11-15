((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,F,B={iq:function iq(d,e,f){this.c=d
this.d=e
this.a=f},Lf:function Lf(){var _=this
_.d=$
_.e=null
_.f=""
_.c=_.a=null},aIj:function aIj(d,e){this.a=d
this.b=e},aIk:function aIk(d,e){this.a=d
this.b=e},aIh:function aIh(d,e){this.a=d
this.b=e},aIg:function aIg(d){this.a=d},aIi:function aIi(d,e){this.a=d
this.b=e}},D,G
J=c[1]
A=c[0]
C=c[2]
E=c[58]
F=c[54]
B=a.updateHolder(c[38],B)
D=c[149]
G=c[64]
B.iq.prototype={
Y(){return new B.Lf()}}
B.Lf.prototype={
gqd(){var x=this.d
return x===$?this.d=this.a.d:x},
ak(){this.aC()
this.kT()},
kT(){var x=0,w=A.x(y.f),v,u=2,t=[],s=this,r,q,p,o
var $async$kT=A.y(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return A.h(s.a.c.dn("GET","/api/v1/jobs/"+A.n(s.gqd().h(0,"id"))),$async$kT)
case 7:r=e
if(s.c==null){x=1
break}s.F(new B.aIj(s,r))
if(!C.b.m(A.b(["completed","failed"],y.h),s.gqd().h(0,"status")))s.e=A.cb(C.kg,s.gH7())
u=2
x=6
break
case 4:u=3
o=t.pop()
q=A.am(o)
if(s.c!=null)s.F(new B.aIk(s,q))
x=6
break
case 3:x=2
break
case 6:case 1:return A.v(v,w)
case 2:return A.u(t.at(-1),w)}})
return A.w($async$kT,w)},
E(d){var x=this,w=null,v="status",u=y.e,t=A.b([],u),s=x.f
if(s.length!==0)t.push(new A.dx(s,x.gH7(),w))
if(!C.b.m(A.b(["completed","failed"],y.h),x.gqd().h(0,v)))C.b.O(t,A.b([G.cp,F.dF("Preparing your note",!0),D.anq],u))
if(J.c(x.gqd().h(0,v),"failed"))C.b.O(t,A.b([new A.dx(A.W(A.ct(x.gqd().h(0,"error")).h(0,"message")),w,w),A.cy(C.mG,new B.aIh(x,d),w)],u))
if(J.c(x.gqd().h(0,v),"completed"))C.b.O(t,A.b([F.dF("Ready",!0),A.jD(D.amA,new B.aIi(x,d),w)],u))
return A.dn(C.az,w,A.co(t,w,w,C.fS,w,w,C.F,!1),!1,!0,!1,!1,!0,"Processing")},
k(){var x=this.e
if(x!=null)x.bW()
this.an()}}
var z=a.updateTypes(["af<~>()"])
B.aIj.prototype={
$0(){var x=this.a
x.d=this.b
x.f=""},
$S:0}
B.aIk.prototype={
$0(){return this.a.f=A.fA(this.b)},
$S:0}
B.aIh.prototype={
$0(){return A.bQ(this.b,new B.aIg(this.a))},
$S:0}
B.aIg.prototype={
$0(){var x=0,w=A.x(y.f),v=this,u,t
var $async$$0=A.y(function(d,e){if(d===1)return A.u(e,w)
for(;;)switch(x){case 0:u=v.a
t=u
x=2
return A.h(u.a.c.dn("POST","/api/v1/jobs/"+A.n(u.gqd().h(0,"id"))+"/retry"),$async$$0)
case 2:t.d=e
x=3
return A.h(u.kT(),$async$$0)
case 3:return A.v(null,w)}})
return A.w($async$$0,w)},
$S:2}
B.aIi.prototype={
$0(){var x=0,w=A.x(y.f),v=this,u,t
var $async$$0=A.y(function(d,e){if(d===1)return A.u(e,w)
for(;;)switch(x){case 0:u=v.a
t=A.ct(u.gqd().h(0,"result"))
x=t.h(0,"note_id")!=null?2:4
break
case 2:x=5
return A.h(A.bH(v.b,E.apQ(u.a.c,A.W(t.h(0,"note_id")),null),y.b),$async$$0)
case 5:x=3
break
case 4:x=t.h(0,"recording_id")!=null?6:7
break
case 6:x=8
return A.h(A.bH(v.b,E.X1(u.a.c,A.W(t.h(0,"recording_id")),null),y.b),$async$$0)
case 8:case 7:case 3:return A.v(null,w)}})
return A.w($async$$0,w)},
$S:2};(function installTearOffs(){var x=a._instance_0u
x(B.Lf.prototype,"gH7","kT",0)})();(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.iq,A.M)
x(B.Lf,A.O)
w(A.dN,[B.aIj,B.aIk,B.aIh,B.aIg,B.aIi])})()
A.cz(b.typeUniverse,JSON.parse('{"iq":{"M":[],"e":[]},"Lf":{"O":["iq"]}}'))
var y={h:A.U("o<j>"),e:A.U("o<e>"),b:A.U("@"),f:A.U("~")};(function constants(){D.amA=new A.a8("Open result",null,null,null,null,null)
D.anq=new A.a8("You can leave this page. Processing continues in the background.",null,null,null,null,null)})()};
(a=>{a["SK2/RNKs9CohYNa5g77U2cmj9I8="]=a.current})($__dart_deferred_initializers__);