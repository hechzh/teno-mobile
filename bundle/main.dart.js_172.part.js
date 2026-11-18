((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,F,H,I,G,B={aAC:function aAC(d,e){this.a=d
this.b=e},Q9:function Q9(d,e){this.Q=d
this.a=e},aAB:function aAB(d,e,f,g,h,i,j,k){var _=this
_.w=d
_.x=$
_.a=e
_.b=f
_.c=g
_.d=h
_.e=i
_.f=j
_.r=k},
b8G(d){var x
A:{if("prepared"===d){x="Ready to register"
break A}if("awaiting_recipient"===d){x="Waiting for the recipient"
break A}if("awaiting_owner"===d){x="Confirm the recipient"
break A}if("ready"===d){x="Ready for device verification"
break A}if("hardware_pending"===d){x="Device verification pending"
break A}if("completed"===d){x="Recorder operation completed"
break A}if("cancelled"===d){x="Cancelled"
break A}x=d
break A}return x},
bfM(d){return new B.pN(d,null)},
pN:function pN(d,e){this.c=d
this.a=e},
aov:function aov(d){this.a=d},
aou:function aou(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
Gk:function Gk(d,e,f,g){var _=this
_.c=d
_.d=e
_.e=f
_.a=g},
a7l:function a7l(){var _=this
_.e=_.d=null
_.f=!1
_.c=_.a=null},
aP0:function aP0(d){this.a=d},
aOZ:function aOZ(d){this.a=d},
aP_:function aP_(d){this.a=d},
aOY:function aOY(d){this.a=d}},D,K,E,L
J=c[1]
A=c[0]
C=c[2]
F=c[59]
H=c[125]
I=c[156]
G=c[50]
B=a.updateHolder(c[14],B)
D=c[159]
K=c[66]
E=c[3]
L=c[53]
B.aAC.prototype={
M(){return"_CardVariant."+this.b}}
B.Q9.prototype={
D(d){var x,w,v,u,t,s,r,q,p,o=null
d.Y(y.e)
x=A.k(d).x1
A.k(d)
switch(0){case 0:w=new B.aAB(d,C.t,o,o,o,1,C.oj,o)
break}v=w
w=x.f
if(w==null){w=v.f
w.toString}u=x.b
if(u==null)u=v.gcL()
t=x.c
if(t==null)t=v.gbY()
s=x.d
if(s==null)s=v.gc6()
r=x.e
if(r==null){r=v.e
r.toString}q=x.r
if(q==null)q=v.gcn()
p=x.a
if(p==null){p=v.a
p.toString}return A.b5(o,o,o,new A.ab(w,A.ef(!1,C.L,!0,o,A.b5(o,o,o,this.Q,!1,o,o,o,!1,o,!1,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,C.x,o),p,u,r,o,t,q,s,o,C.ek),o),!0,o,o,o,!1,o,!1,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,C.x,o)}}
B.aAB.prototype={
gV3(){var x,w=this,v=w.x
if(v===$){x=A.k(w.w)
w.x!==$&&A.as()
v=w.x=x.ax}return v},
gcL(){var x=this.gV3(),w=x.p3
return w==null?x.k2:w},
gbY(){var x=this.gV3().x1
return x==null?C.q:x},
gc6(){return C.B},
gcn(){return D.adI}}
B.pN.prototype={
b7(){var x=0,w=A.v(y.y),v,u=this,t,s
var $async$b7=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:t=u.c
x=3
return A.h(A.fT(A.b([t.cT("GET","/api/v1/recorders"),t.cT("GET","/api/v1/recorders/operations/pending")],y.g),y.y),$async$b7)
case 3:s=e
t=J.bJ(s)
v=A.a1(["items",t.h(s,0).h(0,"items"),"operations",t.h(s,1).h(0,"items")],y.w,y.b)
x=1
break
case 1:return A.t(v,w)}})
return A.u($async$b7,w)},
D(d){return E.cQ(C.al,null,new G.hS(this.ghE(),new B.aov(this),null),!1,!0,!1,!1,!0,"My recorders")}}
B.Gk.prototype={
V(){return new B.a7l()}}
B.a7l.prototype={
ah(){this.az()
this.d=A.a_a(D.SW,new B.aP0(this))},
k(){var x=this.d
if(x!=null)x.bU()
this.am()},
D(d){return E.cQ(C.al,null,new G.hS(new B.aOZ(this),new B.aP_(this),null),!1,!0,!1,!1,!0,"Recorder operation")}}
var z=a.updateTypes(["a8<a3<i,@>>()"])
B.aov.prototype={
$3(d,e,f){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=null,i="operations",h=y.u,g=A.b([D.aod],h)
g.push(D.abb)
for(x=A.bz(e.h(0,"items")),w=x.length,v=y.h,u=0;u<x.length;x.length===w||(0,A.y)(x),++u){t=x[u]
s=t.h(0,"name")
s=s==null?j:J.b0(s)
if(s==null)s=""
r=A.k(d)
q=d.Y(v)
p=q==null?j:q.r.f
o=(p==null?C.ab:p).a
n=C.ak.h(0,o)
m=A.mI(A.ec((n==null?o:n)==="zh"?C.aF:C.ab),"Recorder identity")
l=t.h(0,"hardware_id")
o=l==null?j:J.b0(l)
if(o==null)o=""
q=d.Y(v)
p=q==null?j:q.r.f
n=(p==null?C.ab:p).a
l=C.ak.h(0,n)
s=A.b([new A.bw(s,j,r.ok.w,j,j,j,j,j,j,j,j,j,j,j),new A.bw(m+": "+o,j,j,j,j,j,j,j,j,j,j,j,j,j),new A.bw(A.mI(A.ec((l==null?n:l)==="zh"?C.aF:C.ab),"Authorization generation")+": "+A.n(t.h(0,"epoch")),j,j,j,j,j,j,j,j,j,j,j,j,j)],h)
if(J.c(t.h(0,"recoverable"),!0))s.push(D.anw)
g.push(new B.Q9(new A.ab(C.e7,A.aR(s,C.X,C.h,C.l,0,C.p),j),j))}if(A.bz(e.h(0,i)).length!==0)g.push(F.dr("Recorder operations",!0))
for(h=A.bz(e.h(0,i)),x=h.length,w=this.a,v=y.w,s=y.b,r=y.B,u=0;u<h.length;h.length===x||(0,A.y)(h),++u){k=h[u]
o=k.h(0,"recorder")
o=(r.b(o)?A.pB(o,v,s):A.p(v,s)).h(0,"name")
o=o==null?j:J.b0(o)
if(o==null)o=""
n=k.h(0,"state")
n=n==null?j:J.b0(n)
g.push(A.c5(!1,C.u,j,j,!0,j,j,j,!0,j,j,j,j,j,j,new B.aou(w,d,k,f),!1,j,j,j,j,new A.V(B.b8G(n==null?"":n),j,j,j,j,j),j,new A.bw(o,j,j,j,j,j,j,j,j,j,j,j,j,j),j,j,H.pb,j))}if(A.bz(e.h(0,"items")).length===0&&A.bz(e.h(0,i)).length===0)g.push(D.abd)
g.push(A.cl(D.N9,f,j))
return A.c9(g,j,j,C.ao,j,j,C.A,!1)},
$S:38}
B.aou.prototype={
$0(){var x=0,w=A.v(y.v),v=this
var $async$$0=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:x=2
return A.h(E.by(v.b,new B.Gk(v.a.c,A.U(v.c.h(0,"id")),"",null),y.b),$async$$0)
case 2:v.d.$0()
return A.t(null,w)}})
return A.u($async$$0,w)},
$S:2}
B.aP0.prototype={
$1(d){var x=this.a,w=x.c,v=!1
if(w!=null)if(!x.f){w=A.nu(w,null,y.q)
w=w==null?null:w.gjl()
w=w===!0}else w=v
else w=v
if(w){x=x.e
if(x!=null)x.$0()}},
$S:71}
B.aOZ.prototype={
$0(){var x=0,w=A.v(y.y),v,u=this,t,s,r
var $async$$0=A.w(function(d,e){if(d===1)return A.r(e,w)
for(;;)switch(x){case 0:t=u.a
s=t.a
x=3
return A.h(s.c.cT("GET","/api/v1/recorders/operations/"+s.d),$async$$0)
case 3:r=e
t.a.toString
v=r
x=1
break
case 1:return A.t(v,w)}})
return A.u($async$$0,w)},
$S:44}
B.aP_.prototype={
$3(d,e,f){var x,w,v,u,t="transfer_code",s=null,r="recipient",q=this.a
q.e=f
x=A.U(e.h(0,"state"))
J.c(e.h(0,"initiated_by_me"),!0)
A.bO(e.h(0,"native"))
w=A.U(e.h(0,t)).length!==0?A.U(e.h(0,t)):q.a.e
v=y.u
u=A.b([A.ai(A.U(A.bO(e.h(0,"recorder")).h(0,"name")),s,s,s,s,s,A.k(d).ok.f,s,s,s,s,s),F.dr(B.b8G(x),!0)],v)
if(A.U(e.h(0,r)).length!==0)u.push(A.ai(A.bi(d,"Recipient")+": "+A.n(e.h(0,r)),s,s,s,s,s,s,s,s,s,s,s))
u.push(D.aoi)
if(x==="awaiting_recipient"&&w.length!==0)C.b.N(u,A.b([C.bK,K.k_(w,s),A.cl(D.anr,new B.aOY(w),s),D.anp],v))
v=x==="completed"
if(!v&&x!=="cancelled")u.push(A.ai(A.bi(d,"Prepared at")+": "+L.ln(e.h(0,"updated_at")),s,s,s,s,s,s,s,s,s,s,s))
q.a.toString
u.push(D.aoR)
q.a.toString
if(v)u.push(D.ao8)
u.push(A.cl(D.N9,f,s))
return A.c9(u,s,s,C.ao,s,s,C.A,!1)},
$S:38}
B.aOY.prototype={
$0(){return A.lz(new A.jE(this.a))},
$S:0};(function installTearOffs(){var x=a._instance_0u
x(B.pN.prototype,"ghE","b7",0)})();(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.aAC,A.f7)
w(A.X,[B.Q9,B.pN])
x(B.aAB,A.wt)
w(A.ca,[B.aov,B.aP0,B.aP_])
w(A.dk,[B.aou,B.aOZ,B.aOY])
x(B.Gk,A.K)
x(B.a7l,A.N)})()
A.cc(b.typeUniverse,JSON.parse('{"Q9":{"X":[],"d":[]},"Gk":{"K":[],"d":[]},"pN":{"X":[],"d":[]},"a7l":{"N":["Gk"]},"bce":{"aU":[],"aQ":[],"d":[]}}'))
var y=(function rtii(){var x=A.R
return{e:x("bce"),g:x("o<a8<a3<i,@>>>"),u:x("o<d>"),y:x("a3<i,@>"),B:x("a3<@,@>"),w:x("i"),h:x("i8"),b:x("@"),q:x("P?"),v:x("~")}})();(function constants(){D.SW=new A.bg(5e6)
D.apg=new A.V("Use the mobile app with your recorder nearby to register, restore or transfer it.",null,null,null,null,null)
D.abb=new A.ab(I.um,D.apg,null)
D.anx=new A.V("No recorders registered to this account yet.",null,null,null,null,null)
D.abd=new A.ab(C.e7,D.anx,null)
D.adI=new A.cT(C.rH,C.v)
D.anp=new A.V("The recipient enters this code in My recorders. It does not grant access to your cloud library.",null,null,null,null,null)
D.anr=new A.V("Copy transfer code",null,null,null,null,null)
D.anw=new A.V("Authorization backed up for this account",null,null,null,null,null)
D.ao8=new A.V("Cloud recordings and notes remain with their original account.",null,null,null,null,null)
D.aod=new A.V("One account can own several recorders. Each recorder belongs to one account at a time.",null,null,null,null,null)
D.aoi=new A.V("The app verifies the same recorder, checks all card files, changes authorization, and confirms that the old code is rejected. Keep the recorder nearby and do not start a recording.",null,null,null,null,null)
D.aoR=new A.V("Continue this operation in the mobile app.",null,null,null,null,null)
D.N9=new A.V("Refresh",null,null,null,null,null)
D.atZ=new B.aAC(0,"elevated")})()};
(a=>{a["a4nLFf4MwIFitM06R/DJm0yBu1c="]=a.current})($__dart_deferred_initializers__);