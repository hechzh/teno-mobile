((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={aF0:function aF0(d){this.a=d},
ra(){var x,w=$.b7Z(),v=J.pg(16,y.c)
for(x=0;x<16;++x)v[x]=C.d.dI(C.e.oK(w.aUg(256),16),2,"0")
return C.b.Aq(v)}}
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[47],B)
B.aF0.prototype={
asP(){var x=self.crypto
if(x!=null)if(x.getRandomValues!=null)return
throw A.m(A.c8("No source of cryptographically secure random numbers available."))},
aUg(d){var x,w,v,u,t,s,r,q
if(d<=0||d>4294967296)throw A.m(A.bf9("max must be in range 0 < max \u2264 2^32, was "+d))
if(d>255)if(d>65535)x=d>16777215?4:3
else x=2
else x=1
w=this.a
w.$flags&2&&A.aP(w,11)
w.setUint32(0,0,!1)
v=4-x
u=A.cW(Math.pow(256,x))
for(t=d-1,s=(d&t)===0;;){crypto.getRandomValues(J.kk(C.ba.gdK(w),v,x))
r=w.getUint32(0,!1)
if(s)return(r&t)>>>0
q=r%d
if(r-q+d<u)return q}}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(B.aF0,A.Q)})()
var y={c:A.T("j")};(function lazyInitializers(){var x=a.lazyFinal
x($,"bpu","b7Z",()=>{var w=new B.aF0(A.bdU(8))
w.asP()
return w})})()};
(a=>{a["cbVTvYptzzWYGCtep1U3WfeAyos="]=a.current})($__dart_deferred_initializers__);