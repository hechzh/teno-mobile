((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,F,G,H,I,K,C={
bm6(d){var x,w=A.W(d.h(0,"type"))
A:{if("folder"===w){x=F.dL
break A}if("note"===w){x=I.h1
break A}if("file"===w){x=J.c(d.h(0,"kind"),"image")?E.vc:L.v9
break A}x=E.vd
break A}return x},
aVJ(d,e,f,g,h,i,j,k){return new C.mR(d,e,h,g,j,f,k,i,null)},
b67(d,e,f,g,h,i){var x,w,v,u,t,s,r,q,p=null
if(f==null||f.length===0)return A.ar(e,g,h,p,p,p,i,p,p,p,p,p)
x=A.b([],y.i)
for(w=A.fO(A.abC(f),!1,!1).yZ(0,e),w=new A.IJ(w.a,w.b,w.c),v=y.a,u=0;w.v();){t=w.d
s=(t==null?v.a(t):t).b
r=s.index
if(r>u){q=B.d.ar(e,u,r)
x.push(new A.ec(q,p,p,B.aJ,p,p,p,p,p,p,p))}u=r+s[0].length
s=B.d.ar(e,r,u)
x.push(new A.ec(s,p,p,B.aJ,p,p,p,p,p,p,D.agQ))}if(u<e.length)x.push(A.dX(p,p,p,p,p,p,p,p,p,p,B.d.dU(e,u)))
return A.b3b(A.dX(x,p,p,p,p,p,p,p,p,p,p),g,h,i,p)},
mR:function mR(d,e,f,g,h,i,j,k,l){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.y=k
_.a=l},
ael:function ael(){}},D,E,L,M,N
J=c[1]
A=c[0]
B=c[2]
F=c[86]
G=c[131]
H=c[55]
I=c[111]
K=c[104]
C=a.updateHolder(c[33],C)
D=c[143]
E=c[96]
L=c[128]
M=c[36]
N=c[120]
C.mR.prototype={
E(a1){var x,w,v,u,t,s,r,q=this,p=null,o="duration_ms",n="child_count",m="folder_title",l="status",k=q.e,j=k==null,i=j?q.d:q.f,h=y.e,g=A.b([],h),f=q.c,e=C.bm6(f),d=A.l(a1).ax,a0=d.rx
B.b.O(g,A.b([A.cJ(e,a0==null?d.k3:a0,p,23),B.je],h))
e=A.W(f.h(0,"title")).length===0?A.c5(a1,"Untitled"):A.W(f.h(0,"title"))
d=q.w
e=C.b67(a1,e,d,p,p,D.ahe)
a0=f.h(0,"content_updated_at")
x=y.h
a0=A.b([H.ra(a0==null?f.h(0,"created_at"):a0,a1,!0)],x)
if(f.h(0,o)!=null){w=A.fE(f.h(0,o))
v=B.c.fq((w==null?0:w)/1000)
w=A.pp(a1)
u=(w==null?p:w.gec())==="zh"
if(v<60){w=u?"\u79d2":"s"
w=""+v+w}else if(v<3600){w=B.e.ey(v,60)
t=u?"\u5206\u949f":"m"
t=""+w+t
w=t}else{w=B.e.ey(v,3600)
t=u?"\u5c0f\u65f6":"h"
s=B.e.ey(B.e.a7(v,3600),60)
r=u?"\u5206\u949f":"m"
r=""+w+t+" "+s+r
w=r}a0.push(w)}if(f.h(0,n)!=null)a0.push(A.n(f.h(0,n))+" items")
a0=new A.aF(a0,new C.ael(),y.l).cF(0," \xb7 ")
w=A.l(a1).ax
t=w.rx
e=A.b([e,N.qw,A.ar(a0,p,p,p,p,p,A.bu(p,p,t==null?w.k3:t,p,p,p,p,p,p,p,p,12,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p)],h)
if(q.y){a0=A.l(a1).ax
w=a0.rx
a0=A.cJ(F.dL,w==null?a0.k3:w,p,15)
w=A.W(f.h(0,"folder_id")).length===0||A.W(f.h(0,m)).length===0?A.c5(a1,"Recordings"):A.W(f.h(0,m))
t=A.l(a1).ax
s=t.rx
e.push(new A.ae(D.Tq,A.b9(A.b([a0,E.qt,A.bY(A.ar(w,p,p,p,p,p,A.bu(p,p,s==null?t.k3:s,p,p,p,p,p,p,p,p,13,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p),1)],h),B.o,B.h,B.l,0,p),p))}h=q.r
if(h!=null){a0=A.l(a1).ax
w=a0.rx
e.push(C.b67(a1,h,d,2,B.aj,A.bu(p,p,w==null?a0.k3:w,p,p,p,p,p,p,p,p,12,p,p,p,p,p,!0,p,p,p,p,p,p,p,p)))}if(f.h(0,l)!=null&&!B.b.m(A.b(["ready","transcribed"],x),f.h(0,l))){h=A.c5(a1,M.b6x(f.h(0,l)))
f=A.l(a1).ax
d=f.rx
e.push(A.ar(h,p,p,p,p,p,A.bu(p,p,d==null?f.k3:d,p,p,p,p,p,p,p,p,11,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p))}g.push(A.bY(A.b_(e,B.a_,B.h,B.l,0,B.p),1))
h=q.x
if(h!=null)g.push(h)
if(!j)g.push(new A.ae(D.Tv,A.cJ(k?D.UN:D.V8,p,p,18),p))
return A.e9(!1,p,!0,new A.ae(K.kj,A.b9(g,B.a_,B.h,B.l,0,p),p),p,!0,p,p,p,p,p,p,p,p,p,q.f,i,p,p,p,p,p,p,p)}}
var z=a.updateTypes([])
C.ael.prototype={
$1(d){return d.length!==0},
$S:30};(function inheritance(){var x=a.inherit
x(C.mR,A.X)
x(C.ael,A.cg)})()
A.cI(b.typeUniverse,JSON.parse('{"mR":{"X":[],"e":[]}}'))
var y={h:A.V("o<j>"),i:A.V("o<ec>"),e:A.V("o<e>"),a:A.V("G3"),l:A.V("aF<j>")};(function constants(){D.Tq=new A.a_(0,5,0,0)
D.Tv=new A.a_(12,3,0,0)
D.UN=new A.b0(57689,"MaterialIcons",!1)
D.V8=new A.b0(61267,"MaterialIcons",!1)
D.agQ=new A.q(!0,G.e4,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.ahe=new A.q(!0,null,null,null,null,null,16,B.H,null,null,null,null,1.35,null,null,null,null,null,null,null,null,null,null,null,null,null)})()};
(a=>{a["w/DnRJmlq/PFrpfjdU3qqEqRIM0="]=a.current})($__dart_deferred_initializers__);