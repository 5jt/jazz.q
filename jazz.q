/ INGESTION
xml:read0`$":Classic Jazz.xml"
i:(first where@)each xml like/:{"*<key>",string[x],"</key>"}each`Tracks`Playlists
tx:(2+i 0)_(-1+ i 1)#xml
dix:1_'-2_'_[;tx]where tx like"*<dict>*"  / group of k:v lines
pl:{@[;1 3] _[;x]where differ (or). 1 prev\(<>)scan x in "<>"} except[;"\t"]@  / parse line
dd:{.[!](`$;::)@'flip pl each x}each dix  / list of dictionaries
tmpl:{x!count[x]#enlist""}(union) over key each dd  / template
t:tmpl upsert/:dd  / table

/ PARSING
update disc:{(x?" ")#x}each Name from `t;
update side:`$'last each disc from `t;
update disc:"H"$'-1_'disc from `t;
update track:{"H"$@[;1]" "vs x}each Name from `t;
update Name:{_[;x]1+@[;1]where null x}each Name from `t;  / remove disc, side, track
/ # of tracks on each disc
t:t lj select ntrack:count i by disc from `t
/ # of tracks on A side of disc
t:t lj select atrack:count i by disc from `t where side=`A
/ absolute track # on disc
update track:track+(side=`B)*atrack from `t;

/ IDENTIFY ARTISTS
pa:{ / parse artist
  q:"|"vs'2#("#"vs x),enlist"";
  k:raze q;  / keys
  v:count[k]#enlist first first q;  / canonical name
  n:neg[count k]#(count[k]#enlist""),q 1;  / Comments
  flip`key`val`Comments!(k;v;n)@\:where 0<count each k}
/ longest keys first
arts:{x idesc count each x`key}raze pa each read0`:artists.txt

pns:{[a;s] / parse Name string
  i:where 0<count each ii:s ss/:a`key;  / find artist?
  $[count i; (pny trim s til first ii i 0),a[i 0]`val`Comments; (s;"";"";"")] }[arts;]
pny:{lw:last w:" "vs x; $[all lw within"09";(" "sv -1_w;lw);(x;"")]}  / parse song name and year
update syan:pns each Name from `t;  / song; year; artist; Comments
update song:syan[;0],Year:syan[;1],Artist:syan[;2],Comments:syan[;3] from `t;

/ MISCELLANEOUS
update song:ssr[;"'";"’"] each song from `t;  / typographer's quotes
/ spelling corrections
typos:("**";csv)0:`:typos.csv  
update song:ssr/[;typos 0;typos 1] each song from `t;
/ default track names
q:not count each t`song;
update song:sum[q]#enlist"(unknown)" from `t where q;

/ rename files to stop Apple Music renaming the songs
update oldfilepath:.h.uh each 7_' Location from `t;
newfp:{ / new filepath
  new:("-"sv string x`disc`track)," ",x`song;
  fpn:` vs hsym`$7_ .h.uh x`Location;  / filepath; name
  ext:@[;1]"." vs string fpn 1;  / file extension
  1_ string` sv fpn[0],`$"."sv(new;ext) } 
update newfilepath:newfp each t from `t;
/ rename files
/ `:tmp.txt 0:t[`oldfilepath]{"mv '",x,"' '",y,"'"}'t`newfilepath
DQ:"\"" / double quote
{if[(~). 1 key\hsym`$x;system"mv ",DQ,x,DQ," ",DQ,y,DQ]}' . t`oldfilepath`newfilepath;
update Location:{"file://:","/"sv{@[x;count[x]-1;.h.hu]}"/"vs x}each newfilepath from `t;

/ PREPARE OUTPUT
/ rename columns
ctrn:`disc`track`ntrack`song!`$("Disc Number";"Track Number";"Track Count";"Name")  / cols to rename
u:?[t;();0b;{x!x}cols[t]except`syan`atrack`side`newfilepath`oldfilepath,value ctrn]
u:@[cols u;cols[u]?key ctrn;:;value ctrn] xcol u
/ XML escaping
update Artist:.h.xs each Artist, Name:.h.xs each Name, Comments:.h.xs each Comments from `u

/ MARK UP AS XML
/ XML data types
DT:.[!]("SS";csv)0:`:datatypes.csv
/ mark up value y from column x
mukv:{typ:DT x;"\t",.h.htc[`key;string x],$[typ=`boolean;"<true/>";.h.htc[typ]$[10h=type y;y;string y]]}
/ mark up track
mut:{"\t",'(.h.htc[`key;x`$"Track ID"];"<dict>"),(key[x]mukv'value x),enlist"</dict>"}
`:importPlaylist.xml 0:((2+i 0)#xml),("\t",'raze mut each u),(-1+i 1) _ xml

