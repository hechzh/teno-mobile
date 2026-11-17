((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,D,E,C={
mC(d,e,f,g){var x=0,w=A.v(y.f),v,u,t,s,r,q,p,o,n,m,l,k,j
var $async$mC=A.w(function(h,i){if(h===1)return A.r(i,w)
for(;;)switch(x){case 0:if(J.c(f.h(0,"type"),"recording"))u=(g==null?null:g.h(0,"revision"))!=null
else u=!1
x=u?3:4
break
case 3:x=5
return A.h(e.di("GET","/api/v1/personal/recordings/"+A.n(f.h(0,"id"))+"/transcript?revision="+A.n(g.h(0,"revision"))),$async$mC)
case 5:t=i
if(d.e==null){x=1
break}s=A.bQ(t.h(0,"segments"))
u=A.aa(s).i("aB<1>")
r=A.a_(new A.aB(s,new C.aVr(g),u),u.i("J.E"))
u=A.b([A.ak(A.eo(d).Bt(A.V(t.h(0,"revision"))),null,null,null,null,null,null,null,null,null,null,null)],y.e)
q=r.length===0?s:r
p=q.length
o=0
for(;o<q.length;q.length===p||(0,A.C)(q),++o){n=q[o]
m=D.lc(n.h(0,"start_ms"))
l=n.h(0,"speaker_name")
l=l==null?null:J.bd(l)
if(l==null)l=""
k=n.h(0,"text")
k=k==null?null:J.bd(k)
if(k==null)k=""
u.push(new A.ac(H.ob,G.nQ(m+" "+l+"\n"+k,null),null))}x=6
return A.h(E.ki(d,F.dn(B.aC,null,A.cr(u,null,null,I.cd,null,null,B.E,!1),!1,!0,!0,!1,!0,"Source transcript"),!1,A.ab(d,B.bY,y.h).w.a.b*0.75,y.f),$async$mC)
case 6:x=1
break
case 4:j=A.V(f.h(0,"type"))
A:{if("folder"===j){u=A.V(f.h(0,"title"))
u=E.aXJ(e,A.V(f.h(0,"id")),u,!1)
break A}if("note"===j){u=A.V(f.h(0,"id"))
q=A.eO(g==null?null:g.h(0,"revision"))
u=D.aq7(e,u,q==null?null:B.c.dw(q))
break A}if("file"===j){u=A.V(f.h(0,"id"))
q=A.eO(g==null?null:g.h(0,"page"))
u=D.apw(e,u,q==null?null:B.c.dw(q))
break A}u=A.V(f.h(0,"id"))
q=A.eO(g==null?null:g.h(0,"start_ms"))
u=D.Xf(e,u,q==null?null:B.c.dw(q))
break A}x=7
return A.h(F.bP(d,u,y.b),$async$mC)
case 7:case 1:return A.t(v,w)}})
return A.u($async$mC,w)},
aVr:function aVr(d){this.a=d}},F,G,H,I
J=c[1]
A=c[0]
B=c[2]
D=c[57]
E=c[56]
C=a.updateHolder(c[50],C)
F=c[3]
G=c[52]
H=c[96]
I=c[63]
var z=a.updateTypes([])
C.aVr.prototype={
$1(d){return J.c(d.h(0,"id"),this.a.h(0,"source_id"))},
$S:8};(function inheritance(){var x=a.inherit
x(C.aVr,A.cq)})()
var y={e:A.T("o<e>"),h:A.T("ey"),b:A.T("@"),f:A.T("~")}};
(a=>{a["/i6Ez7ilfmkYhHXZ7qS7CYP2C+8="]=a.current})($__dart_deferred_initializers__);