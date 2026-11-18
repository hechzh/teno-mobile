((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={aFD:function aFD(d){this.a=d},
kr(){var x,w=$.b9J(),v=J.pu(16,y.c)
for(x=0;x<16;++x)v[x]=C.d.dK(C.e.oO(w.aXO(256),16),2,"0")
return C.b.Ax(v)}}
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[57],B)
B.aFD.prototype={
awn(){var x=self.crypto
if(x!=null)if(x.getRandomValues!=null)return
throw A.m(A.cb("No source of cryptographically secure random numbers available."))},
aXO(d){var x,w,v,u,t,s,r,q
if(d<=0||d>4294967296)throw A.m(A.bh4("max must be in range 0 < max \u2264 2^32, was "+d))
if(d>255)if(d>65535)x=d>16777215?4:3
else x=2
else x=1
w=this.a
w.$flags&2&&A.aP(w,11)
w.setUint32(0,0,!1)
v=4-x
u=A.cV(Math.pow(256,x))
for(t=d-1,s=(d&t)===0;;){crypto.getRandomValues(J.ku(C.bb.gdN(w),v,x))
r=w.getUint32(0,!1)
if(s)return(r&t)>>>0
q=r%d
if(r-q+d<u)return q}}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(B.aFD,A.P)})()
var y={c:A.R("i")};(function lazyInitializers(){var x=a.lazyFinal
x($,"brv","b9J",()=>{var w=new B.aFD(A.bfN(8))
w.awn()
return w})})()};
(a=>{a["vnowcevnzQ5/gLc9V+dsK7xx9Js="]=a.current})($__dart_deferred_initializers__);