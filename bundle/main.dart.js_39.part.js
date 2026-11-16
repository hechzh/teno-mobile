((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,D,E,C={
mB(d,e,f,g){var x=0,w=A.w(y.f),v,u,t,s,r,q,p,o,n,m,l,k,j
var $async$mB=A.x(function(h,i){if(h===1)return A.t(i,w)
for(;;)switch(x){case 0:if(J.c(f.h(0,"type"),"recording"))u=(g==null?null:g.h(0,"revision"))!=null
else u=!1
x=u?3:4
break
case 3:x=5
return A.h(e.dn("GET","/api/v1/personal/recordings/"+A.n(f.h(0,"id"))+"/transcript?revision="+A.n(g.h(0,"revision"))),$async$mB)
case 5:t=i
if(d.e==null){x=1
break}s=A.bS(t.h(0,"segments"))
u=A.aa(s).i("aC<1>")
r=A.a0(new A.aC(s,new C.aV2(g),u),u.i("J.E"))
u=A.b([A.at(A.em(d).Bp(A.W(t.h(0,"revision"))),null,null,null,null,null,null,null,null,null,null,null)],y.e)
q=r.length===0?s:r
p=q.length
o=0
for(;o<q.length;q.length===p||(0,A.C)(q),++o){n=q[o]
m=D.lc(n.h(0,"start_ms"))
l=n.h(0,"speaker_name")
l=l==null?null:J.bk(l)
if(l==null)l=""
k=n.h(0,"text")
k=k==null?null:J.bk(k)
if(k==null)k=""
u.push(new A.ad(H.o9,G.uE(m+" "+l+"\n"+k,null),null))}x=6
return A.h(E.ki(d,F.dn(B.az,null,A.cp(u,null,null,I.cc,null,null,B.F,!1),!1,!0,!0,!1,!0,"Source transcript"),!1,A.ac(d,B.bY,y.h).w.a.b*0.75,y.f),$async$mB)
case 6:x=1
break
case 4:j=A.W(f.h(0,"type"))
A:{if("folder"===j){u=A.W(f.h(0,"title"))
u=E.aXi(e,A.W(f.h(0,"id")),u,!1)
break A}if("note"===j){u=A.W(f.h(0,"id"))
q=A.f5(g==null?null:g.h(0,"revision"))
u=D.apX(e,u,q==null?null:B.c.dw(q))
break A}if("file"===j){u=A.W(f.h(0,"id"))
q=A.f5(g==null?null:g.h(0,"page"))
u=D.apn(e,u,q==null?null:B.c.dw(q))
break A}u=A.W(f.h(0,"id"))
q=A.f5(g==null?null:g.h(0,"start_ms"))
u=D.X7(e,u,q==null?null:B.c.dw(q))
break A}x=7
return A.h(F.bH(d,u,y.b),$async$mB)
case 7:case 1:return A.u(v,w)}})
return A.v($async$mB,w)},
aV2:function aV2(d){this.a=d}},G,H,F,I
J=c[1]
A=c[0]
B=c[2]
D=c[60]
E=c[59]
C=a.updateHolder(c[52],C)
G=c[54]
H=c[96]
F=c[3]
I=c[65]
var z=a.updateTypes([])
C.aV2.prototype={
$1(d){return J.c(d.h(0,"id"),this.a.h(0,"source_id"))},
$S:8};(function inheritance(){var x=a.inherit
x(C.aV2,A.co)})()
var y={e:A.T("o<e>"),h:A.T("eE"),b:A.T("@"),f:A.T("~")}};
(a=>{a["4RRDn4eLACiFaK9KAreJX6sx+0U="]=a.current})($__dart_deferred_initializers__);