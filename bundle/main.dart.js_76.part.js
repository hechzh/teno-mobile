((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,F,G,H,C={
bow(d){var x,w=A.U(d.h(0,"type"))
A:{if("folder"===w){x=F.dL
break A}if("note"===w){x=I.h7
break A}if("file"===w){x=J.c(d.h(0,"kind"),"image")?E.vg:O.p6
break A}x=E.vh
break A}return x},
aXN(d,e,f,g,h,i,j,k){return new C.n0(d,e,h,g,j,f,k,i,null)},
b8g(d,e,f,g,h,i){var x,w,v,u,t,s,r,q,p=null
if(f==null||f.length===0)return A.ai(e,g,h,p,p,p,i,p,p,p,p,p)
x=A.b([],y.i)
for(w=A.fG(A.ac7(f),!1,!1).zb(0,e),w=new A.J5(w.a,w.b,w.c),v=y.a,u=0;w.v();){t=w.d
s=(t==null?v.a(t):t).b
r=s.index
if(r>u){q=B.d.an(e,u,r)
x.push(new A.eh(q,p,p,B.aN,p,p,p,p,p,p,p))}u=r+s[0].length
s=B.d.an(e,r,u)
x.push(new A.eh(s,p,p,B.aN,p,p,p,p,p,p,D.ahv))}if(u<e.length)x.push(A.e0(p,p,p,p,p,p,p,p,p,p,B.d.dL(e,u)))
return A.b5i(A.e0(x,p,p,p,p,p,p,p,p,p,p),g,h,i,p)},
n0:function n0(d,e,f,g,h,i,j,k,l){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.y=k
_.a=l},
aeS:function aeS(){}},D,I,E,K,L,M,N,O
J=c[1]
A=c[0]
B=c[2]
F=c[99]
G=c[150]
H=c[54]
C=a.updateHolder(c[30],C)
D=c[165]
I=c[115]
E=c[109]
K=c[33]
L=c[42]
M=c[117]
N=c[140]
O=c[124]
C.n0.prototype={
D(a2){var x,w,v,u,t,s,r,q=this,p=null,o="duration_ms",n="child_count",m="folder_title",l="processing",k="status",j=q.e,i=j==null,h=i?q.d:q.f,g=y.e,f=A.b([],g),e=q.c,d=C.bow(e),a0=A.k(a2).ax,a1=a0.rx
B.b.N(f,A.b([A.cF(d,a1==null?a0.k3:a1,p,23),B.jh],g))
d=A.U(e.h(0,"title")).length===0?A.bi(a2,"Untitled"):A.U(e.h(0,"title"))
a0=q.w
d=C.b8g(a2,d,a0,p,p,D.ahT)
a1=e.h(0,"content_updated_at")
x=y.h
a1=A.b([H.rr(a1==null?e.h(0,"created_at"):a1,a2,!0)],x)
if(e.h(0,o)!=null){w=A.eG(e.h(0,o))
v=B.c.fq((w==null?0:w)/1000)
w=A.pF(a2)
u=(w==null?p:w.gdT())==="zh"
if(v<60){w=u?"\u79d2":"s"
w=""+v+w}else if(v<3600){w=B.e.ez(v,60)
t=u?"\u5206\u949f":"m"
t=""+w+t
w=t}else{w=B.e.ez(v,3600)
t=u?"\u5c0f\u65f6":"h"
s=B.e.ez(B.e.aa(v,3600),60)
r=u?"\u5206\u949f":"m"
r=""+w+t+" "+s+r
w=r}a1.push(w)}if(e.h(0,n)!=null)a1.push(A.es(a2).a7p(B.c.dw(A.ej(e.h(0,n)))))
a1=new A.az(a1,new C.aeS(),y.l).cw(0," \xb7 ")
w=A.k(a2).ax
t=w.rx
d=A.b([d,N.qC,A.ai(a1,p,p,p,p,p,A.bq(p,p,t==null?w.k3:t,p,p,p,p,p,p,p,p,12,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p)],g)
if(q.y){a1=A.k(a2).ax
w=a1.rx
a1=A.cF(F.dL,w==null?a1.k3:w,p,15)
w=A.U(e.h(0,"folder_id")).length===0||A.U(e.h(0,m)).length===0?A.bi(a2,"Recordings"):A.U(e.h(0,m))
t=A.k(a2).ax
s=t.rx
d.push(new A.ab(D.Tu,A.ba(A.b([a1,E.qB,A.bZ(A.ai(w,p,p,p,p,p,A.bq(p,p,s==null?t.k3:s,p,p,p,p,p,p,p,p,13,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p),1)],g),B.n,B.h,B.l,0,p),p))}g=q.r
if(g!=null){a1=A.k(a2).ax
w=a1.rx
d.push(C.b8g(a2,g,a0,2,B.am,A.bq(p,p,w==null?a1.k3:w,p,p,p,p,p,p,p,p,12,p,p,p,p,p,!0,p,p,p,p,p,p,p,p)))}if(A.bO(e.h(0,l)).a!==0)d.push(new L.q7(A.bO(e.h(0,l)),p,!0,!1,p))
if(A.bO(e.h(0,l)).a===0&&e.h(0,k)!=null&&!B.b.m(A.b(["ready","transcribed"],x),e.h(0,k))){g=A.bi(a2,K.b8H(e.h(0,k)))
e=A.k(a2).ax
a0=e.rx
d.push(A.ai(g,p,p,p,p,p,A.bq(p,p,a0==null?e.k3:a0,p,p,p,p,p,p,p,p,11,p,p,p,p,p,!0,p,p,p,p,p,p,p,p),p,p,p,p,p))}f.push(A.bZ(A.aR(d,B.X,B.h,B.l,0,B.p),1))
g=q.x
if(g!=null)f.push(g)
if(!i)f.push(new A.ab(D.TA,A.cF(j?D.US:D.Vj,p,p,18),p))
return A.ea(!1,p,!0,new A.ab(M.km,A.ba(f,B.X,B.h,B.l,0,p),p),p,!0,p,p,p,p,p,p,p,p,p,q.f,h,p,p,p,p,p,p,p)}}
var z=a.updateTypes([])
C.aeS.prototype={
$1(d){return d.length!==0},
$S:32};(function inheritance(){var x=a.inherit
x(C.n0,A.X)
x(C.aeS,A.ca)})()
A.cc(b.typeUniverse,JSON.parse('{"n0":{"X":[],"d":[]}}'))
var y={h:A.R("o<i>"),i:A.R("o<eh>"),e:A.R("o<d>"),a:A.R("Gp"),l:A.R("az<i>")};(function constants(){D.Tu=new A.a_(0,5,0,0)
D.TA=new A.a_(12,3,0,0)
D.US=new A.aT(57689,"MaterialIcons",!1)
D.Vj=new A.aT(61267,"MaterialIcons",!1)
D.ahv=new A.q(!0,G.e3,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.ahT=new A.q(!0,null,null,null,null,null,16,B.I,null,null,null,null,1.35,null,null,null,null,null,null,null,null,null,null,null,null,null)})()};
(a=>{a["DLFBOsi+qrFj6XZ88EGQdiWsPik="]=a.current})($__dart_deferred_initializers__);