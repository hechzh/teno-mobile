((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,F,G,H,I,C={
bmw(d){var x,w=A.W(d.h(0,"type"))
A:{if("folder"===w){x=F.dL
break A}if("note"===w){x=I.h1
break A}if("file"===w){x=J.c(d.h(0,"kind"),"image")?E.v8:K.v5
break A}x=E.v9
break A}return x},
aWb(d,e,f,g,h,i,j,k){return new C.mS(d,e,h,g,j,f,k,i,null)},
b6y(d,e,f,g,h,i){var x,w,v,u,t,s,r,q,p=null
if(f==null||f.length===0)return A.at(e,g,h,p,p,p,i,p,p,p,p,p)
x=A.b([],y.i)
for(w=A.fR(A.abL(f),!1,!1).z3(0,e),w=new A.IQ(w.a,w.b,w.c),v=y.a,u=0;w.v();){t=w.d
s=(t==null?v.a(t):t).b
r=s.index
if(r>u){q=B.d.ar(e,u,r)
x.push(new A.ec(q,p,p,B.aK,p,p,p,p,p,p,p))}u=r+s[0].length
s=B.d.ar(e,r,u)
x.push(new A.ec(s,p,p,B.aK,p,p,p,p,p,p,D.agQ))}if(u<e.length)x.push(A.dY(p,p,p,p,p,p,p,p,p,p,B.d.dU(e,u)))
return A.b3D(A.dY(x,p,p,p,p,p,p,p,p,p,p),g,h,i,p)},
mS:function mS(d,e,f,g,h,i,j,k,l){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.y=k
_.a=l},
aeu:function aeu(){}},D,E,K,L,M,N
J=c[1]
A=c[0]
B=c[2]
F=c[89]
G=c[135]
H=c[58]
I=c[112]
C=a.updateHolder(c[33],C)
D=c[149]
E=c[98]
K=c[131]
L=c[35]
M=c[106]
N=c[123]
C.mS.prototype={
E(a1){var x,w,v,u,t,s,r,q=this,p=null,o="duration_ms",n="child_count",m="folder_title",l="status",k=q.e,j=k==null,i=j?q.d:q.f,h=y.e,g=A.b([],h),f=q.c,e=C.bmw(f),d=A.l(a1).ax,a0=d.rx
B.b.O(g,A.b([A.cL(e,a0==null?d.k3:a0,p,23),B.jf],h))
e=A.W(f.h(0,"title")).length===0?A.c1(a1,"Untitled"):A.W(f.h(0,"title"))
d=q.w
e=C.b6y(a1,e,d,p,p,D.ahd)
a0=f.h(0,"content_updated_at")
x=y.h
a0=A.b([H.r8(a0==null?f.h(0,"created_at"):a0,a1,!0)],x)
if(f.h(0,o)!=null){w=A.f5(f.h(0,o))
v=B.c.fq((w==null?0:w)/1000)
w=A.pq(a1)
u=(w==null?p:w.gdZ())==="zh"
if(v<60){w=u?"\u79d2":"s"
w=""+v+w}else if(v<3600){w=B.e.ey(v,60)
t=u?"\u5206\u949f":"m"
t=""+w+t
w=t}else{w=B.e.ey(v,3600)
t=u?"\u5c0f\u65f6":"h"
s=B.e.ey(B.e.aa(v,3600),60)
r=u?"\u5206\u949f":"m"
r=""+w+t+" "+s+r
w=r}a0.push(w)}if(f.h(0,n)!=null)a0.push(A.em(a1).a7b(B.c.dw(A.en(f.h(0,n)))))
a0=new A.aC(a0,new C.aeu(),y.l).cE(0," \xb7 ")
w=A.l(a1).ax
t=w.rx
e=A.b([e,N.qw,A.at(a0,p,p,p,p,p,A.bw(p,p,t==null?w.k3:t,p,p,p,p,p,p,p,p,12,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p)],h)
if(q.y){a0=A.l(a1).ax
w=a0.rx
a0=A.cL(F.dL,w==null?a0.k3:w,p,15)
w=A.W(f.h(0,"folder_id")).length===0||A.W(f.h(0,m)).length===0?A.c1(a1,"Recordings"):A.W(f.h(0,m))
t=A.l(a1).ax
s=t.rx
e.push(new A.ad(D.Tn,A.b9(A.b([a0,E.qt,A.bZ(A.at(w,p,p,p,p,p,A.bw(p,p,s==null?t.k3:s,p,p,p,p,p,p,p,p,13,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p),1)],h),B.o,B.h,B.l,0,p),p))}h=q.r
if(h!=null){a0=A.l(a1).ax
w=a0.rx
e.push(C.b6y(a1,h,d,2,B.aj,A.bw(p,p,w==null?a0.k3:w,p,p,p,p,p,p,p,p,12,p,p,p,p,p,!0,p,p,p,p,p,p,p,p)))}if(f.h(0,l)!=null&&!B.b.m(A.b(["ready","transcribed"],x),f.h(0,l))){h=A.c1(a1,L.b6X(f.h(0,l)))
f=A.l(a1).ax
d=f.rx
e.push(A.at(h,p,p,p,p,p,A.bw(p,p,d==null?f.k3:d,p,p,p,p,p,p,p,p,11,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p))}g.push(A.bZ(A.b0(e,B.a_,B.h,B.l,0,B.p),1))
h=q.x
if(h!=null)g.push(h)
if(!j)g.push(new A.ad(D.Tt,A.cL(k?D.UL:D.V8,p,p,18),p))
return A.e9(!1,p,!0,new A.ad(M.ki,A.b9(g,B.a_,B.h,B.l,0,p),p),p,!0,p,p,p,p,p,p,p,p,p,q.f,i,p,p,p,p,p,p,p)}}
var z=a.updateTypes([])
C.aeu.prototype={
$1(d){return d.length!==0},
$S:30};(function inheritance(){var x=a.inherit
x(C.mS,A.X)
x(C.aeu,A.co)})()
A.cs(b.typeUniverse,JSON.parse('{"mS":{"X":[],"e":[]}}'))
var y={h:A.T("o<j>"),i:A.T("o<ec>"),e:A.T("o<e>"),a:A.T("G9"),l:A.T("aC<j>")};(function constants(){D.Tn=new A.Z(0,5,0,0)
D.Tt=new A.Z(12,3,0,0)
D.UL=new A.b1(57689,"MaterialIcons",!1)
D.V8=new A.b1(61267,"MaterialIcons",!1)
D.agQ=new A.q(!0,G.e3,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.ahd=new A.q(!0,null,null,null,null,null,16,B.I,null,null,null,null,1.35,null,null,null,null,null,null,null,null,null,null,null,null,null)})()};
(a=>{a["XfCPinAhrsCjWCaWGCTcKt3To2g="]=a.current})($__dart_deferred_initializers__);