/*********************************************************************************************

ALTTXT V1.5
BY: BRIAN GOSSELIN OF SCRIPTASYLUM.COM

INSTRUCTIONS:

1: PUT THESE DIVS IN THE END OF THE BODY AREA:

   <div id="navtxt" class="navtext" style="position:absolute; top:-100px; left:0px; visibility:hidden;"></div>

2: NEXT, PLACE THIS STYLE DECLARATION IN THE HEAD SECTION OF YOUR PAGE (JUST CHANGE YOUR SETTINGS):

   .navtext { width:235px; font:bold 8pt sans-serif; border-width:2px; border-style:outset; border-color:#006BAE; z-index:10000; layer-background-color:#FFF6D9; background-color:#FFF6D9; color:black; }

2: THEN, SET THE 5 SETTINGS BELOW (mousefollow, dofade, centertext, xoffset, and yoffset) AS DESIRED.

3: LASTLY ADD THE MOUSEOVER/MOUSEOUT EVENT HANDLERS TO EACH LINK THAT YOU WANT THIS EFFECT FOR:

     EXAMPLE: <a href="scriptasylum.com" onmouseover="writetxt('Popup text')" onmouseout="writetxt(0)">Link text</a>

     NOTE: YOU CAN CAUSE A BOX *NOT* TO DISAPPEAR ONCE THE MOUSE LEAVES THE LINK BY SIMPLY OMITTING
           THE onmouseout="writetxt(0)" PART. THIS WILL CAUSE THE CURRENT BOX TO REMAIN VISIBLE. THIS
           IS BEST USED WHEN mousefollow MODE IS DISABLED (SET TO false).

*********************************************************************************************/

var mousefollow=true;  // ENABLES MOUSE FOLLOW MODE WHERE THE BOX CONTINUES TO FOLLOW THE MOUSE.
                       // SETTING TO false WILL CAUSE THE BOX TO APPEAR NEAR THE MOUSE BUT WILL NOT
                       // CONTINUE TO FOLLOW THE MOUSE. 
var dofade=false       // ENABLES FADE-IN EFFECT (FOR IE4+ AND NS6 ONLY)
var centertext=false;  // CENTERS THE TEXT INSIDE THE BOX. YOU CAN'T SIMPLY DO THIS VIA "STYLE" BECAUSE OF NS4.
                       // OTHERWISE, TEXT IS LEFT-JUSTIFIED.
var xoffset=-50;         // HORIZONTAL PIXEL COUNT FROM CURSOR
var yoffset=10;         // VERTICAL PIXEL COUNT FROM CURSOR

////////////////////////////// NO NEED TO EDIT BEYOND THIS POINT //////////////////////////////////////

function altProps(){
this.ns4=(navigator.appName.indexOf("Netscape")>=0 && !document.getElementById)? true : false;
this.ie4=(document.all && !document.getElementById)? true : false;
this.ie5=(document.getElementById && document.all)? true : false;
this.ns6=(document.getElementById && navigator.appName.indexOf("Netscape")>=0 )? true: false;
this.w3c=(document.getElementById)? true : false;
this.w_y=0;
this.w_x=0;
this.navtxt=0;
this.boxheight=0;
this.boxwidth=0;
this.ishover=false;
this.isloaded=false;
this.ieop=0;
this.op_id=0;
this.oktomove=false;
}

function toggle_centertext(){
centertext=!centertext;
AT.navtxt.style.textAlign=((AT.w3c || AT.ie4) && centertext)?"center" : "left";
}

function toggle_mousefollow(){
mousefollow=!mousefollow;
}

function toggle_dofade(){
dofade=!dofade;
if(!dofade)AT.ieop=100;
}

var AT=new altProps();

function getwindowdims(){
AT.w_y=(AT.ie5||AT.ie4)?document.body.clientHeight:window.innerHeight;
AT.w_x=(AT.ie5||AT.ie4)?document.body.clientWidth:window.innerWidth;
}

function getboxwidth(){
if(AT.ns4)AT.boxwidth=(AT.navtxt.document.width)? AT.navtxt.document.width : AT.navtxt.clip.width;
else if(AT.ie4)AT.boxwidth=(AT.navtxt.style.pixelWidth)? AT.navtxt.style.pixelWidth : AT.navtxt.offsetWidth;
else AT.boxwidth=(AT.navtxt.style.width)? parseInt(AT.navtxt.style.width) : parseInt(AT.navtxt.offsetWidth);
}

function getboxheight(){
if(AT.ns4)AT.boxheight=(AT.navtxt.document.height)? AT.navtxt.document.height : AT.navtxt.clip.height;
else if(AT.ie4)AT.boxheight=(AT.navtxt.style.pixelHeight)? AT.navtxt.style.pixelHeight : AT.navtxt.offsetHeight;
else AT.boxheight=parseInt(AT.navtxt.offsetHeight);
}

function movenavtxt(x,y){
if(AT.ns4)AT.navtxt.moveTo(x,y);
else{
AT.navtxt.style.left=x+'px';
AT.navtxt.style.top=y+'px';
}}

function getpagescrolly(){
if(AT.ie5||AT.ie4)return document.body.scrollTop;
else return window.pageYOffset;
}

function getpagescrollx(){
if(AT.ie5||AT.ie4)return document.body.scrollLeft;
else return window.pageXOffset;
}

function writeindiv(text){
if(AT.ns4){
AT.navtxt.document.open();
AT.navtxt.document.write(text);
AT.navtxt.document.close();
}
else AT.navtxt.innerHTML=text;
}

function writetxt(text,col){
if(AT.isloaded){
if(text!=0){
AT.oktomove=true;
AT.ishover=true;
if(AT.ns4)text='<div class="navtext">'+((centertext)?'<center>':'')+text+((centertext)?'</center>':'')+'</div>';
writeindiv(text);
if(AT.ns4)AT.navtxt.visibility="show";
else{
AT.navtxt.style.visibility="visible";
AT.navtxt.style.display="block";
}
getboxheight();
if((AT.w3c || AT.ie4) && dofade){
if(AT.ie4||AT.ie5)AT.navtxt.style.filter="alpha(opacity=0)";
if(AT.ns6)AT.navtxt.style.MozOpacity=0;
AT.ieop=0;
AT.op_id=setInterval('incropacity()',50);
}}else{
if(AT.ns4)AT.navtxt.visibility="hide";
else{
if(dofade)clearInterval(AT.op_id);
AT.navtxt.style.display="none";
AT.navtxt.style.visibility="hidden";
}
movenavtxt(-AT.boxwidth-10,0);
writeindiv('');
}}}

function incropacity(){
if(AT.ieop<=100){
AT.ieop+=7;
if(AT.ie4||AT.ie5)AT.navtxt.style.filter="alpha(opacity="+AT.ieop+")";
if(AT.ns6)AT.navtxt.style.MozOpacity=AT.ieop/100;
}else clearInterval(AT.op_id);
}

function moveobj(evt){
mx=(AT.ie5||AT.ie4)?event.clientX:evt.pageX;
my=(AT.ie5||AT.ie4)?event.clientY:evt.pageY;
if(AT.isloaded && AT.ishover && AT.oktomove){
margin=(AT.ie4||AT.ie5)?5:25;
if(AT.ns6)if(document.height+27-window.innerHeight<0)margin=15;
if(AT.ns4)if(document.height-window.innerHeight<0)margin=10;
if(AT.ns4||AT.ns6)mx-=getpagescrollx();
if(AT.ns4)my-=getpagescrolly();
xoff=mx+xoffset;
yoff=(my+AT.boxheight+yoffset-((AT.ns6)?getpagescrolly():0)>=AT.w_y)? -5-AT.boxheight-yoffset: yoffset;
movenavtxt( Math.min(AT.w_x-AT.boxwidth-margin , Math.max(2,xoff))+getpagescrollx(), my+yoff+((!AT.ns6)?getpagescrolly():0));
if(!mousefollow)AT.oktomove=false;
}}

if(AT.ns4)document.captureEvents(Event.MOUSEMOVE);

document.onmousemove=moveobj;

window.onload=function(){
  AT.navtxt=(AT.ns4)? document.layers['navtxt'] : (AT.ie4)? document.all['navtxt'] : (AT.w3c)? document.getElementById('navtxt') : null;
  getboxwidth();
  getboxheight();
  getwindowdims();
  AT.isloaded=true;
  if((AT.w3c || AT.ie4) && centertext)AT.navtxt.style.textAlign="center";
  if(AT.w3c)AT.navtxt.style.padding='4px';
  if(AT.ie4 || AT.ie5 && dofade)AT.navtxt.style.filter="alpha(opacity=0)";
  }

window.onresize=getwindowdims;

bcolor   = "#909090";     // popup border color
fcolor   = "#000000";     // popup font color
tcolor   = "#ffffff";
bgcolor  = "#000000";



function popup(titl,msg,bak){
 writetxt("<TABLE BORDER=\"0\" "+
 "       CELLPADDING=\"1\" CELLSPACING=\"0\" BGCOLOR=\""+bgcolor+"\">"+
 "<TBODY><TR><TD NOWRAP><TABLE BORDER=\"0\" BGCOLOR=\""+bak+"\" " +
 " WIDTH=\"100%\"CELLSPACING=\"0\"  CELLPADDING=\"2\">"+
 "<TR><TD NOWRAP BGCOLOR=\""+bcolor+"\"ALIGN=\"CENTER\"><FONT COLOR=\""+tcolor+"\" >"+
 "<B><SMALL>"+titl+"</SMALL></B></FONT></TD></TR><TR>"+
 "<TD ALIGN=\"center\"><FONT COLOR=\""+fcolor+"\"><SMALL>"+
 msg+"</SMALL></FONT></TD></TR></TABLE></TD></TR></TBODY></TABLE>");
}

function kill(){
 writetxt(0);
}
