((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,F,E,D={q7:function q7(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},arC:function arC(d,e){this.a=d
this.b=e},
bf3(d,e){var x=null
return new F.xF(d,e,x,x,x,x,x,x)}},B,G
J=c[1]
A=c[0]
C=c[2]
F=c[65]
E=c[115]
D=a.updateHolder(c[42],D)
B=c[168]
G=c[117]
D.q7.prototype={
D(a3){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=this,i="stage_status",h=null,g="waiting_reason",f="stage",e="local_file",d="Saved in this browser",a0="Saved on this phone",a1="warnings",a2=j.c
if(a2.gap(a2))return C.aj
x=J.c(a2.h(0,i),"failed")
w=A.bO(a2.h(0,"preserved"))
v=B.a9E.h(0,a2.h(0,g))
if(v==null)v=""
u=typeof a2.h(0,"percent")=="number"?C.c.dY(A.ej(a2.h(0,"percent")),0,100):h
t=J.c(a2.h(0,g),"cloud_disabled")
if(J.c(a2.h(0,f),"saved")&&J.c(w.h(0,e),!0))s=j.f?d:a0
else{r=B.a9v.h(0,a2.h(0,f))
s=r==null?"Checking processing status":r}r=j.e
q=r?4:12
p=A.bi(a3,s)
o=x?" \xb7 "+A.bi(a3,"Failed"):""
n=u==null
m=!n?" \xb7 "+A.n(u)+"%":""
l=r?12:14
k=y.e
l=A.b([A.ai(p+o+m,h,h,h,h,h,A.bq(h,h,x?A.k(a3).ax.fy:h,h,h,h,h,h,h,h,h,l,h,h,C.aD,h,h,!0,h,h,h,h,h,h,h,h),h,h,h,h,h)],k)
if(v.length!==0)l.push(A.cj(v,h,h,E.hH,h))
if(J.c(a2.h(0,"stale"),!0))l.push(B.aoA)
if(!r){r=A.b([],k)
if(!x&&!t&&C.b.m(A.b(["running","queued"],y.h),a2.h(0,i)))r.push(new A.ab(C.eW,D.bf3(2,n?h:u/100),h))
p=A.b([],k)
if(J.c(w.h(0,"device_file"),!0))p.push(B.ap2)
if(J.c(w.h(0,e),!0))p.push(A.cj(j.f?d:a0,h,h,h,h))
if(J.c(w.h(0,"cloud_audio"),!0)||J.c(w.h(0,"cloud_file"),!0))p.push(B.anS)
if(J.c(w.h(0,"transcript"),!0))p.push(B.anF)
if(J.c(w.h(0,"extracted_text"),!0))p.push(B.aoc)
o=A.eG(w.h(0,"notes"))
if((o==null?0:o)>0)p.push(B.aoh)
r.push(A.hM(C.br,p,C.co,4,8))
p=y.d
o=p.a(a2.h(0,a1))
if(J.acp(o==null?[]:o,"note_needs_verification"))r.push(G.r5)
p=p.a(a2.h(0,a1))
if(J.acp(p==null?[]:p,"cleanup_failed_original_kept"))r.push(B.aoG)
if(x&&A.U(A.bO(a2.h(0,"error")).h(0,"message")).length!==0)r.push(new A.dI(A.U(A.bO(a2.h(0,"error")).h(0,"message")),h,h))
if(x&&j.d!=null)r.push(A.cl(A.cj(J.c(a2.h(0,f),"generating_note")?"Retry note generation":"Retry this step",h,h,h,h),new D.arC(j,a3),h))
C.b.N(l,r)}return new A.ab(new A.a_(0,q,0,q),A.aR(l,C.X,C.h,C.l,0,C.p),h)}}
var z=a.updateTypes([])
D.arC.prototype={
$0(){var x=this.a.d
x.toString
return A.bP(this.b,x)},
$S:0};(function inheritance(){var x=a.inherit
x(D.q7,A.X)
x(D.arC,A.dk)})()
A.cc(b.typeUniverse,JSON.parse('{"q7":{"X":[],"d":[]}}'))
var y={p:A.R("ag<i,i>"),h:A.R("o<i>"),e:A.R("o<d>"),d:A.R("Y<@>?")};(function constants(){B.aa7={saved:0,syncing:1,waiting_upload:2,uploading:3,transcribing:4,extracting_text:5,preparing_audio:6,generating_note:7,complete:8,awaiting_generation:9,awaiting_transcription:10,awaiting_extraction:11}
B.a9v=new A.ag(B.aa7,["Recording saved","Syncing from recorder","Waiting to upload","Uploading","Transcribing","Extracting text","Preparing audio","Generating note","Complete","Note generation not started","Transcription not started","Text extraction not started"],y.p)
B.aam={wifi_only:0,network:1,cloud_disabled:2,sign_in:3,server_queue:4,retry_backoff:5,no_speech:6}
B.a9E=new A.ag(B.aam,["Waiting for Wi-Fi","Network unavailable","Cloud processing is off \xb7 Saved locally only","Sign in to upload","Waiting for a processing slot","Waiting to retry","No speech was found. The audio is saved."],y.p)
B.anF=new A.V("Transcript kept",null,null,null,null,null)
B.anS=new A.V("Cloud file kept",null,null,null,null,null)
B.aoc=new A.V("Extracted text kept",null,null,null,null,null)
B.aoh=new A.V("Existing notes kept",null,null,null,null,null)
B.aoA=new A.V("Showing the last confirmed status. Not refreshed.",E.hH,null,null,null,null)
B.aoG=new A.V("Transcript cleanup failed. The original transcript is kept.",null,null,null,null,null)
B.ap2=new A.V("Saved on recorder",null,null,null,null,null)})()};
(a=>{a["FqWniRgNm0zyt7G9LZmpPgsAAvM="]=a.current})($__dart_deferred_initializers__);