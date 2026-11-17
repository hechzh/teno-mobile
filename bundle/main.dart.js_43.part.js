((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,F,G,H,C={
bn_(d){var x,w=A.V(d.h(0,"type"))
A:{if("folder"===w){x=F.dL
break A}if("note"===w){x=I.h4
break A}if("file"===w){x=J.c(d.h(0,"kind"),"image")?E.vb:L.v8
break A}x=E.vc
break A}return x},
aWA(d,e,f,g,h,i,j,k){return new C.mT(d,e,h,g,j,f,k,i,null)},
b6Z(d,e,f,g,h,i){var x,w,v,u,t,s,r,q,p=null
if(f==null||f.length===0)return A.ak(e,g,h,p,p,p,i,p,p,p,p,p)
x=A.b([],y.i)
for(w=A.fR(A.abS(f),!1,!1).z8(0,e),w=new A.IV(w.a,w.b,w.c),v=y.a,u=0;w.v();){t=w.d
s=(t==null?v.a(t):t).b
r=s.index
if(r>u){q=B.d.ar(e,u,r)
x.push(new A.ec(q,p,p,B.aL,p,p,p,p,p,p,p))}u=r+s[0].length
s=B.d.ar(e,r,u)
x.push(new A.ec(s,p,p,B.aL,p,p,p,p,p,p,D.ah9))}if(u<e.length)x.push(A.dZ(p,p,p,p,p,p,p,p,p,p,B.d.dV(e,u)))
return A.b42(A.dZ(x,p,p,p,p,p,p,p,p,p,p),g,h,i,p)},
mT:function mT(d,e,f,g,h,i,j,k,l){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.y=k
_.a=l},
aeC:function aeC(){}},D,I,E,K,L,M,N,O
J=c[1]
A=c[0]
B=c[2]
F=c[89]
G=c[132]
H=c[55]
C=a.updateHolder(c[31],C)
D=c[144]
I=c[104]
E=c[98]
K=c[43]
L=c[128]
M=c[33]
N=c[106]
O=c[121]
C.mT.prototype={
D(a2){var x,w,v,u,t,s,r,q=this,p=null,o="duration_ms",n="child_count",m="folder_title",l="processing",k="status",j=q.e,i=j==null,h=i?q.d:q.f,g=y.e,f=A.b([],g),e=q.c,d=C.bn_(e),a0=A.l(a2).ax,a1=a0.rx
B.b.N(f,A.b([A.cL(d,a1==null?a0.k3:a1,p,23),B.jf],g))
d=A.V(e.h(0,"title")).length===0?A.bF(a2,"Untitled"):A.V(e.h(0,"title"))
a0=q.w
d=C.b6Z(a2,d,a0,p,p,D.ahx)
a1=e.h(0,"content_updated_at")
x=y.h
a1=A.b([H.rc(a1==null?e.h(0,"created_at"):a1,a2,!0)],x)
if(e.h(0,o)!=null){w=A.eO(e.h(0,o))
v=B.c.fq((w==null?0:w)/1000)
w=A.pt(a2)
u=(w==null?p:w.gdQ())==="zh"
if(v<60){w=u?"\u79d2":"s"
w=""+v+w}else if(v<3600){w=B.e.ey(v,60)
t=u?"\u5206\u949f":"m"
t=""+w+t
w=t}else{w=B.e.ey(v,3600)
t=u?"\u5c0f\u65f6":"h"
s=B.e.ey(B.e.aa(v,3600),60)
r=u?"\u5206\u949f":"m"
r=""+w+t+" "+s+r
w=r}a1.push(w)}if(e.h(0,n)!=null)a1.push(A.eo(a2).a7h(B.c.dw(A.ee(e.h(0,n)))))
a1=new A.aB(a1,new C.aeC(),y.l).cv(0," \xb7 ")
w=A.l(a2).ax
t=w.rx
d=A.b([d,O.qw,A.ak(a1,p,p,p,p,p,A.bo(p,p,t==null?w.k3:t,p,p,p,p,p,p,p,p,12,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p)],g)
if(q.y){a1=A.l(a2).ax
w=a1.rx
a1=A.cL(F.dL,w==null?a1.k3:w,p,15)
w=A.V(e.h(0,"folder_id")).length===0||A.V(e.h(0,m)).length===0?A.bF(a2,"Recordings"):A.V(e.h(0,m))
t=A.l(a2).ax
s=t.rx
d.push(new A.ac(D.Tm,A.b9(A.b([a1,E.qv,A.bY(A.ak(w,p,p,p,p,p,A.bo(p,p,s==null?t.k3:s,p,p,p,p,p,p,p,p,13,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p),1)],g),B.o,B.h,B.l,0,p),p))}g=q.r
if(g!=null){a1=A.l(a2).ax
w=a1.rx
d.push(C.b6Z(a2,g,a0,2,B.aj,A.bo(p,p,w==null?a1.k3:w,p,p,p,p,p,p,p,p,12,p,p,p,p,p,!0,p,p,p,p,p,p,p,p)))}if(A.bS(e.h(0,l)).a!==0)d.push(new K.pU(A.bS(e.h(0,l)),p,!0,!1,p))
if(A.bS(e.h(0,l)).a===0&&e.h(0,k)!=null&&!B.b.m(A.b(["ready","transcribed"],x),e.h(0,k))){g=A.bF(a2,M.b7n(e.h(0,k)))
e=A.l(a2).ax
a0=e.rx
d.push(A.ak(g,p,p,p,p,p,A.bo(p,p,a0==null?e.k3:a0,p,p,p,p,p,p,p,p,11,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p))}f.push(A.bY(A.aS(d,B.Y,B.h,B.l,0,B.p),1))
g=q.x
if(g!=null)f.push(g)
if(!i)f.push(new A.ac(D.Ts,A.cL(j?D.UK:D.V8,p,p,18),p))
return A.ea(!1,p,!0,new A.ac(N.kj,A.b9(f,B.Y,B.h,B.l,0,p),p),p,!0,p,p,p,p,p,p,p,p,p,q.f,h,p,p,p,p,p,p,p)}}
var z=a.updateTypes([])
C.aeC.prototype={
$1(d){return d.length!==0},
$S:30};(function inheritance(){var x=a.inherit
x(C.mT,A.Y)
x(C.aeC,A.cq)})()
A.cx(b.typeUniverse,JSON.parse('{"mT":{"Y":[],"e":[]}}'))
var y={h:A.T("o<j>"),i:A.T("o<ec>"),e:A.T("o<e>"),a:A.T("Ge"),l:A.T("aB<j>")};(function constants(){D.Tm=new A.Z(0,5,0,0)
D.Ts=new A.Z(12,3,0,0)
D.UK=new A.b0(57689,"MaterialIcons",!1)
D.V8=new A.b0(61267,"MaterialIcons",!1)
D.ah9=new A.q(!0,G.e3,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.ahx=new A.q(!0,null,null,null,null,null,16,B.I,null,null,null,null,1.35,null,null,null,null,null,null,null,null,null,null,null,null,null)})()};
(a=>{a["NGIqKietC146Q69bOmTKOynVh5k="]=a.current})($__dart_deferred_initializers__);