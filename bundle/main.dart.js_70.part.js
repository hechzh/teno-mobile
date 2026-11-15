((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={aEO:function aEO(d){this.a=d},
rc(){var x,w=$.b7O(),v=J.pf(16,y.c)
for(x=0;x<16;++x)v[x]=C.d.dJ(C.e.oK(w.aTS(256),16),2,"0")
return C.b.Am(v)}}
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[47],B)
B.aEO.prototype={
asq(){var x=self.crypto
if(x!=null)if(x.getRandomValues!=null)return
throw A.m(A.c8("No source of cryptographically secure random numbers available."))},
aTS(d){var x,w,v,u,t,s,r,q
if(d<=0||d>4294967296)throw A.m(A.beZ("max must be in range 0 < max \u2264 2^32, was "+d))
if(d>255)if(d>65535)x=d>16777215?4:3
else x=2
else x=1
w=this.a
w.$flags&2&&A.aP(w,11)
w.setUint32(0,0,!1)
v=4-x
u=A.cU(Math.pow(256,x))
for(t=d-1,s=(d&t)===0;;){crypto.getRandomValues(J.kd(C.b7.gdL(w),v,x))
r=w.getUint32(0,!1)
if(s)return(r&t)>>>0
q=r%d
if(r-q+d<u)return q}}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(B.aEO,A.Q)})()
var y={c:A.U("j")};(function lazyInitializers(){var x=a.lazyFinal
x($,"bpj","b7O",()=>{var w=new B.aEO(A.bdJ(8))
w.asq()
return w})})()};
(a=>{a["w8JIEnpfSdGeMxj19dRIpPsaEbo="]=a.current})($__dart_deferred_initializers__);