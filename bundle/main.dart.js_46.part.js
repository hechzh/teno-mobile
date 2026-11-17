((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,F,E,D={pU:function pU(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},arc:function arc(d,e){this.a=d
this.b=e},
bdJ(d,e){var x=null
return new F.xx(d,e,x,x,x,x,x,x)}},B,G
J=c[1]
A=c[0]
C=c[2]
F=c[3]
E=c[104]
D=a.updateHolder(c[43],D)
B=c[128]
G=c[106]
D.pU.prototype={
D(a3){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=this,i="stage_status",h=null,g="waiting_reason",f="stage",e="local_file",d="Saved in this browser",a0="Saved on this phone",a1="warnings",a2=j.c
if(a2.gao(a2))return C.ai
x=J.c(a2.h(0,i),"failed")
w=A.bS(a2.h(0,"preserved"))
v=B.a9s.h(0,a2.h(0,g))
if(v==null)v=""
u=typeof a2.h(0,"percent")=="number"?C.c.e2(A.ee(a2.h(0,"percent")),0,100):h
t=J.c(a2.h(0,g),"cloud_disabled")
if(J.c(a2.h(0,f),"saved")&&J.c(w.h(0,e),!0))s=j.f?d:a0
else{r=B.a9k.h(0,a2.h(0,f))
s=r==null?"Checking processing status":r}r=j.e
q=r?4:12
p=A.bF(a3,s)
o=x?" \xb7 "+A.bF(a3,"Failed"):""
n=u==null
m=!n?" \xb7 "+A.n(u)+"%":""
l=r?12:14
k=y.e
l=A.b([A.ak(p+o+m,h,h,h,h,h,A.bo(h,h,x?A.l(a3).ax.fy:h,h,h,h,h,h,h,h,h,l,h,h,C.aB,h,h,!0,h,h,h,h,h,h,h,h),h,h,h,h,h)],k)
if(v.length!==0)l.push(A.cl(v,h,h,E.hE,h))
if(J.c(a2.h(0,"stale"),!0))l.push(B.anY)
if(!r){r=A.b([],k)
if(!x&&!t&&C.b.m(A.b(["running","queued"],y.h),a2.h(0,i)))r.push(new A.ac(C.eS,D.bdJ(2,n?h:u/100),h))
p=A.b([],k)
if(J.c(w.h(0,"device_file"),!0))p.push(B.aol)
if(J.c(w.h(0,e),!0))p.push(A.cl(j.f?d:a0,h,h,h,h))
if(J.c(w.h(0,"cloud_audio"),!0)||J.c(w.h(0,"cloud_file"),!0))p.push(B.ano)
if(J.c(w.h(0,"transcript"),!0))p.push(B.anf)
if(J.c(w.h(0,"extracted_text"),!0))p.push(B.anF)
o=A.eO(w.h(0,"notes"))
if((o==null?0:o)>0)p.push(B.anJ)
r.push(A.hK(C.bq,p,C.co,4,8))
p=y.d
o=p.a(a2.h(0,a1))
if(J.ac9(o==null?[]:o,"note_needs_verification"))r.push(G.r0)
p=p.a(a2.h(0,a1))
if(J.ac9(p==null?[]:p,"cleanup_failed_original_kept"))r.push(B.ao3)
if(x&&A.V(A.bS(a2.h(0,"error")).h(0,"message")).length!==0)r.push(new A.dP(A.V(A.bS(a2.h(0,"error")).h(0,"message")),h,h))
if(x&&j.d!=null)r.push(A.cE(A.cl(J.c(a2.h(0,f),"generating_note")?"Retry note generation":"Retry this step",h,h,h,h),new D.arc(j,a3),h))
C.b.N(l,r)}return new A.ac(new A.Z(0,q,0,q),A.aS(l,C.Y,C.h,C.l,0,C.p),h)}}
var z=a.updateTypes([])
D.arc.prototype={
$0(){var x=this.a.d
x.toString
return A.bT(this.b,x)},
$S:0};(function inheritance(){var x=a.inherit
x(D.pU,A.Y)
x(D.arc,A.dQ)})()
A.cx(b.typeUniverse,JSON.parse('{"pU":{"Y":[],"e":[]}}'))
var y={p:A.T("ag<j,j>"),h:A.T("o<j>"),e:A.T("o<e>"),d:A.T("W<@>?")};(function constants(){B.v8=new A.b0(61358,"MaterialIcons",!1)
B.a9W={saved:0,syncing:1,waiting_upload:2,uploading:3,transcribing:4,extracting_text:5,preparing_audio:6,generating_note:7,complete:8,awaiting_generation:9,awaiting_transcription:10,awaiting_extraction:11}
B.a9k=new A.ag(B.a9W,["Recording saved","Syncing from recorder","Waiting to upload","Uploading","Transcribing","Extracting text","Preparing audio","Generating note","Complete","Note generation not started","Transcription not started","Text extraction not started"],y.p)
B.aaa={wifi_only:0,network:1,cloud_disabled:2,sign_in:3,server_queue:4,retry_backoff:5,no_speech:6}
B.a9s=new A.ag(B.aaa,["Waiting for Wi-Fi","Network unavailable","Cloud processing is off \xb7 Saved locally only","Sign in to upload","Waiting for a processing slot","Waiting to retry","No speech was found. The audio is saved."],y.p)
B.anf=new A.a1("Transcript kept",null,null,null,null,null)
B.ano=new A.a1("Cloud file kept",null,null,null,null,null)
B.anF=new A.a1("Extracted text kept",null,null,null,null,null)
B.anJ=new A.a1("Existing notes kept",null,null,null,null,null)
B.anY=new A.a1("Showing the last confirmed status. Not refreshed.",E.hE,null,null,null,null)
B.ao3=new A.a1("Transcript cleanup failed. The original transcript is kept.",null,null,null,null,null)
B.aol=new A.a1("Saved on recorder",null,null,null,null,null)})()};
(a=>{a["ty5z8WWYtZYHAvzXz5/4WxcruIs="]=a.current})($__dart_deferred_initializers__);