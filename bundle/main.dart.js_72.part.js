((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,G,H,I,E,D,F,C={
mJ(d,e,f,g){var x=0,w=A.v(y.f),v,u,t,s,r,q,p,o,n,m,l,k,j
var $async$mJ=A.w(function(h,i){if(h===1)return A.r(i,w)
for(;;)switch(x){case 0:if(J.c(f.h(0,"type"),"recording"))u=(g==null?null:g.h(0,"revision"))!=null
else u=!1
x=u?3:4
break
case 3:x=5
return A.h(e.cT("GET","/api/v1/personal/recordings/"+A.n(f.h(0,"id"))+"/transcript?revision="+A.n(g.h(0,"revision"))),$async$mJ)
case 5:t=i
if(d.e==null){x=1
break}s=A.bz(t.h(0,"segments"))
u=A.ac(s).i("az<1>")
r=A.a0(new A.az(s,new C.aWF(g),u),u.i("J.E"))
u=A.b([A.ai(A.es(d).Bv(A.U(t.h(0,"revision"))),null,null,null,null,null,null,null,null,null,null,null)],y.e)
q=r.length===0?s:r
p=q.length
o=0
for(;o<q.length;q.length===p||(0,A.y)(q),++o){n=q[o]
m=H.ko(n.h(0,"start_ms"))
l=n.h(0,"speaker_name")
l=l==null?null:J.b0(l)
if(l==null)l=""
k=n.h(0,"text")
k=k==null?null:J.b0(k)
if(k==null)k=""
u.push(new A.ab(K.od,G.k_(m+" "+l+"\n"+k,null),null))}x=6
return A.h(F.ks(d,E.cQ(B.al,null,A.c9(u,null,null,I.ce,null,null,B.A,!1),!1,!0,!0,!1,!0,"Source transcript"),!1,A.ae(d,B.bZ,y.h).w.a.b*0.75,y.f),$async$mJ)
case 6:x=1
break
case 4:j=A.U(f.h(0,"type"))
A:{if("folder"===j){u=A.U(f.h(0,"title"))
u=F.aZ_(e,A.U(f.h(0,"id")),u,!1)
break A}if("note"===j){u=A.U(f.h(0,"id"))
q=A.eG(g==null?null:g.h(0,"revision"))
u=D.aqv(e,u,q==null?null:B.c.dw(q))
break A}if("file"===j){u=A.U(f.h(0,"id"))
q=A.eG(g==null?null:g.h(0,"page"))
u=D.apU(e,u,q==null?null:B.c.dw(q))
break A}u=A.U(f.h(0,"id"))
q=A.eG(g==null?null:g.h(0,"start_ms"))
u=D.Xs(e,u,q==null?null:B.c.dw(q))
break A}x=7
return A.h(E.by(d,u,y.b),$async$mJ)
case 7:case 1:return A.t(v,w)}})
return A.u($async$mJ,w)},
aWF:function aWF(d){this.a=d}},K
J=c[1]
A=c[0]
B=c[2]
G=c[66]
H=c[64]
I=c[72]
E=c[3]
D=c[56]
F=c[55]
C=a.updateHolder(c[47],C)
K=c[107]
var z=a.updateTypes([])
C.aWF.prototype={
$1(d){return J.c(d.h(0,"id"),this.a.h(0,"source_id"))},
$S:8};(function inheritance(){var x=a.inherit
x(C.aWF,A.ca)})()
var y={e:A.R("o<d>"),h:A.R("eC"),b:A.R("@"),f:A.R("~")}};
(a=>{a["QrjTqCC36ZFS/7PVYxTlacRbdc0="]=a.current})($__dart_deferred_initializers__);