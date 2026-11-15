((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,D,E,C={
mA(d,e,f,g){var x=0,w=A.x(y.f),v,u,t,s,r,q,p,o,n,m,l,k,j
var $async$mA=A.y(function(h,i){if(h===1)return A.u(i,w)
for(;;)switch(x){case 0:if(J.c(f.h(0,"type"),"recording"))u=(g==null?null:g.h(0,"revision"))!=null
else u=!1
x=u?3:4
break
case 3:x=5
return A.h(e.dn("GET","/api/v1/personal/recordings/"+A.n(f.h(0,"id"))+"/transcript?revision="+A.n(g.h(0,"revision"))),$async$mA)
case 5:t=i
if(d.e==null){x=1
break}s=A.bY(t.h(0,"segments"))
u=A.aa(s).i("aC<1>")
r=A.a0(new A.aC(s,new C.aUR(g),u),u.i("J.E"))
u=A.b([A.ar(A.jf(d).Bl(A.W(t.h(0,"revision"))),null,null,null,null,null,null,null,null,null,null,null)],y.e)
q=r.length===0?s:r
p=q.length
o=0
for(;o<q.length;q.length===p||(0,A.D)(q),++o){n=q[o]
m=D.la(n.h(0,"start_ms"))
l=n.h(0,"speaker_name")
l=l==null?null:J.bA(l)
if(l==null)l=""
k=n.h(0,"text")
k=k==null?null:J.bA(k)
if(k==null)k=""
u.push(new A.ad(G.o9,F.uA(m+" "+l+"\n"+k,null),null))}x=6
return A.h(E.kb(d,A.dn(B.az,null,A.co(u,null,null,H.ca,null,null,B.F,!1),!1,!0,!0,!1,!0,"Source transcript"),!1,A.ac(d,B.bV,y.h).w.a.b*0.75,y.f),$async$mA)
case 6:x=1
break
case 4:j=A.W(f.h(0,"type"))
A:{if("folder"===j){u=A.W(f.h(0,"title"))
u=E.aX5(e,A.W(f.h(0,"id")),u,!1)
break A}if("note"===j){u=A.W(f.h(0,"id"))
q=A.fo(g==null?null:g.h(0,"revision"))
u=D.apQ(e,u,q==null?null:B.c.dF(q))
break A}if("file"===j){u=A.W(f.h(0,"id"))
q=A.fo(g==null?null:g.h(0,"page"))
u=D.apg(e,u,q==null?null:B.c.dF(q))
break A}u=A.W(f.h(0,"id"))
q=A.fo(g==null?null:g.h(0,"start_ms"))
u=D.X1(e,u,q==null?null:B.c.dF(q))
break A}x=7
return A.h(A.bH(d,u,y.b),$async$mA)
case 7:case 1:return A.v(v,w)}})
return A.w($async$mA,w)},
aUR:function aUR(d){this.a=d}},F,G,H
J=c[1]
A=c[0]
B=c[2]
D=c[58]
E=c[57]
C=a.updateHolder(c[51],C)
F=c[53]
G=c[94]
H=c[64]
var z=a.updateTypes([])
C.aUR.prototype={
$1(d){return J.c(d.h(0,"id"),this.a.h(0,"source_id"))},
$S:8};(function inheritance(){var x=a.inherit
x(C.aUR,A.cg)})()
var y={e:A.U("o<e>"),h:A.U("er"),b:A.U("@"),f:A.U("~")}};
(a=>{a["PC/uc8EJ3QPx2D9aar+QT4q5PGc="]=a.current})($__dart_deferred_initializers__);