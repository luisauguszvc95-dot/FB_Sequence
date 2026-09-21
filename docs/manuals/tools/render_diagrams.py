#!/usr/bin/env python3
"""Lay out existing documentary graph data as SVG; never execute ST or process data."""
from __future__ import annotations
import argparse, collections, hashlib, html, json, math, re
from pathlib import Path
import fitz

WIDTH, HEIGHT = 1040, 480
NODE_FONT, EDGE_FONT = 22, 19
FONT = fitz.Font('helv')
INK, BLUE, LINE = '#24333F', '#24577A', '#526779'
STYLE = {
 'input': ('#F4F6F8','#C0CED8'), 'process': ('#FFFFFF',LINE),
 'focal': ('#E7EFF5',BLUE), 'state': ('#EDF1F4',LINE),
 'output': ('#FFFFFF',BLUE), 'store': ('#EDF1F4',LINE),
}

def txt_width(s, size): return FONT.text_length(s, fontsize=size)
def wrap_label(label, width, size=NODE_FONT):
    lines=[]
    for part in label.split('\n'):
        cur=''
        for word in part.split():
            test=f'{cur} {word}'.strip()
            if cur and txt_width(test,size)>width: lines.append(cur);cur=word
            else: cur=test
        lines.append(cur)
    return lines

def intersect(a,b,pad=0):
    return min(a[2],b[2])-max(a[0],b[0])>pad and min(a[3],b[3])-max(a[1],b[1])>pad

def segments(points): return list(zip(points,points[1:]))
def seg_rect(a,b,box,margin=0.5):
    x0,y0,x1,y1=box
    if abs(a[0]-b[0])<.001:
        return x0+margin<a[0]<x1-margin and min(max(a[1],b[1]),y1-margin)>max(min(a[1],b[1]),y0+margin)
    if abs(a[1]-b[1])<.001:
        return y0+margin<a[1]<y1-margin and min(max(a[0],b[0]),x1-margin)>max(min(a[0],b[0]),x0+margin)
    raise ValueError('Only orthogonal edges supported')

def ranks_for(graph):
    ids=[n['id'] for n in graph['nodes']];adj={i:[] for i in ids}
    for k,e in enumerate(graph['edges']):adj[e['from']].append((e['to'],k))
    colors={};back=set()
    def visit(u):
        colors[u]=1
        for v,k in adj[u]:
            if colors.get(v)==1:back.add(k)
            elif not colors.get(v):visit(v)
        colors[u]=2
    for u in ids:
        if not colors.get(u):visit(u)
    rank={u:0 for u in ids}
    for _ in ids:
        for k,e in enumerate(graph['edges']):
            if k not in back:rank[e['to']]=max(rank[e['to']],rank[e['from']]+1)
    return rank,back

def layout(graph,slug=None):
    if slug in {'SEQ-072','SEQ-073','SEQ-076','SEQ-078'}:
        return explicit_layout(graph,slug)
    rank,back=ranks_for(graph);depth=max(rank.values())+1
    rows=[[n for n in graph['nodes'] if rank[n['id']]==r] for r in range(depth)]
    # Preserve source order within every layer. Text wraps, identifiers do not change.
    has_outer=bool(back) or any(rank[e['to']]>rank[e['from']]+1 for e in graph['edges'])
    center=420 if has_outer else 520
    layout_width=780 if has_outer else 1000
    row_heights=[];nodes={}
    for r,row in enumerate(rows):
        count=len(row)
        width=min(580,(layout_width-(count-1)*36)/count)
        step=layout_width/count
        for j,n in enumerate(row):
            cx=center+(j-(count-1)/2)*step
            lines=wrap_label(n['label'],width-32)
            h=max(66,len(lines)*26+14)
            nodes[n['id']]={**n,'lines':lines,'cx':cx,'width':width,'height':h,'rank':r}
        row_heights.append(max(nodes[n['id']]['height'] for n in row))
    free=440-sum(row_heights)
    gap=min(94,free/max(1,depth-1))
    if gap<26 and depth>1:raise ValueError(f'Graph exceeds readable height: gap={gap}')
    used=sum(row_heights)+gap*(depth-1);y=(HEIGHT-used)/2
    for r,row in enumerate(rows):
        for n in row:
            obj=nodes[n['id']];h=obj['height'];cy=y+row_heights[r]/2
            obj['cy']=cy;obj['box']=[obj['cx']-obj['width']/2,cy-h/2,obj['cx']+obj['width']/2,cy+h/2]
        y+=row_heights[r]+gap
    incoming=collections.Counter(e['to'] for e in graph['edges'])
    outgoing=collections.Counter(e['from'] for e in graph['edges'])
    edges=[];outer_count=0
    for i,e in enumerate(graph['edges']):
        a=nodes[e['from']];b=nodes[e['to']];ax0,ay0,ax1,ay1=a['box'];bx0,by0,bx1,by1=b['box']
        label=' '.join(e['label'].split());lw=txt_width(label,EDGE_FONT)+12;lh=25
        outer=i in back or rank[e['to']]>rank[e['from']]+1
        if outer:
            ch=1006-outer_count*25;outer_count+=1
            sy=a['cy'];ty=b['cy']
            start=[[ax1,sy],[ch,sy]]
            end=[[ch,ty],[bx1,ty]]
            peers=[n for n in nodes.values() if n['id'] not in (e['from'],e['to'])]
            if any(seg_rect(start[0],start[1],n['box']) for n in peers):
                rail=ay1+min(14,gap*.3);sx=a['cx']+18
                start=[[sx,ay1],[sx,rail],[ch,rail]]
            if any(seg_rect(end[0],end[1],n['box']) for n in peers):
                rail=by0-min(14,gap*.3);tx=b['cx']+18
                end=[[ch,rail],[tx,rail],[tx,by0]]
            points=start+end
            lx=ch-lw-10;ly=(sy+ty-lh)/2
        else:
            sx=a['cx'];tx=b['cx'];sy=ay1;ty=by0
            # Give joined branches different ports while preserving exact connectivity.
            if outgoing[e['from']]>1 and tx!=sx:sx+=(-18 if tx<sx else 18)
            if incoming[e['to']]>1 and sx!=tx:tx+=(-18 if sx<tx else 18)
            mid=(sy+ty)/2
            points=[[sx,sy],[sx,mid],[tx,mid],[tx,ty]]
            if abs(sx-tx)<.01:
                lx=sx+10;ly=(sy+ty-lh)/2
            elif outgoing[e['from']]>1:
                # Label the branch after it has separated from the source.
                lx=tx+10 if tx<center else tx-lw-10
                ly=mid+max(1,(ty-mid-lh)/2)
            else:
                # Convergence: label near the independent source branch.
                lx=sx+10 if sx<center else sx-lw-10
                ly=sy+max(1,(mid-sy-lh)/2)
            # Very short gaps: put labels over the horizontal segment, away from the stroke.
            if ty-sy<62 and abs(sx-tx)>15:
                lx=(sx+tx-lw)/2;ly=mid-lh-4
        points=[p for k,p in enumerate(points) if k==0 or p!=points[k-1]]
        edges.append({**e,'index':i,'label_lines':[label], 'points':points,'label_box':[lx,ly,lx+lw,ly+lh],'outer':outer})
    # Reposition edge labels into genuinely free nearby space. Try many small candidates.
    placed=[]
    for e in sorted(edges,key=lambda e:(not e['outer'],e['index'])):
        box=e['label_box'];w=box[2]-box[0];h=box[3]-box[1];candidates=[box]
        a=nodes[e['from']];b=nodes[e['to']]
        for p,q in segments(e['points']):
            if abs(p[0]-q[0])<.01:
                ym=(p[1]+q[1]-h)/2
                for dx in [10,-w-10,22,-w-22]:candidates.append([p[0]+dx,ym,p[0]+dx+w,ym+h])
            else:
                xm=(p[0]+q[0]-w)/2
                for dy in [-h-5,5]:candidates.append([xm,p[1]+dy,xm+w,p[1]+dy+h])
        def score(z):
            penalty=0
            if min(z[:2])<8 or z[2]>WIDTH-8 or z[3]>HEIGHT-8:penalty+=10000
            penalty+=10000*sum(intersect(z,n['box']) for n in nodes.values())
            penalty+=10000*sum(intersect(z,p) for p in placed)
            penalty+=1000*sum(seg_rect(p,q,z) for other in edges for p,q in segments(other['points']))
            return penalty
        best=min(enumerate(candidates),key=lambda it:(score(it[1]),it[0]))[1]
        e['label_box']=best;e['placement_penalty']=score(best);placed.append(best)
    return nodes,edges

def explicit_layout(graph,slug):
    """Four reviewed editorial layouts; source graph data is not modified."""
    if slug=='SEQ-072':
        boxes={'a':[35,36,295,108],'b':[440,36,880,108],'c':[40,218,450,294],'d':[590,218,1000,294],'e':[340,386,700,462]}
        routes=[([[295,72],[440,72]],[314,39]),([[642,108],[642,163],[245,163],[245,218]],[255,177]),([[678,108],[678,163],[795,163],[795,218]],[600,177]),([[502,386],[502,338],[245,338],[245,294]],[255,304]),([[538,386],[538,338],[795,338],[795,294]],[680,304])]
    elif slug=='SEQ-073':
        boxes={'a':[35,36,465,108],'b':[575,36,1005,108],'c':[575,204,1005,276],'d':[35,204,465,276],'e':[35,372,465,444]}
        routes=[([[790,108],[790,204]],[801,143]),([[250,108],[250,204]],[261,143]),([[250,276],[250,372]],[261,311])]
    elif slug=='SEQ-076':
        boxes={'a':[230,36,810,108],'b':[360,204,680,276],'c':[230,382,810,454],'d':[40,204,310,276],'e':[730,204,1000,276]}
        routes=[([[520,108],[520,204]],[531,143]),([[520,276],[520,382]],[531,316]),([[175,276],[175,334],[310,334],[310,382]],[185,291]),([[865,276],[865,334],[730,334],[730,382]],[665,291])]
    else:
        boxes={'a':[130,36,450,108],'b':[700,36,1020,108],'c':[130,220,450,292],'d':[700,220,1020,292],'e':[395,390,755,462]}
        routes=[([[290,108],[290,220]],[301,151]),([[860,108],[860,220]],[674,151]),([[450,256],[700,256]],[497,223]),([[555,390],[555,340],[290,340],[290,292]],[301,304]),([[595,390],[595,340],[860,340],[860,292]],[744,304])]
    expected_edges={
        'SEQ-072':[('a','b'),('b','c'),('b','d'),('e','c'),('e','d')],
        'SEQ-073':[('b','c'),('a','d'),('d','e')],
        'SEQ-076':[('a','b'),('b','c'),('d','c'),('e','c')],
        'SEQ-078':[('a','c'),('b','d'),('c','d'),('e','c'),('e','d')],
    }
    if set(boxes)!={n['id'] for n in graph['nodes']} or [(e['from'],e['to']) for e in graph['edges']]!=expected_edges[slug]:
        raise ValueError(f'{slug}: changed topology requires a fresh editorial layout review')
    nodes={}
    for n in graph['nodes']:
        x0,y0,x1,y1=boxes[n['id']];w=x1-x0;h=y1-y0
        nodes[n['id']]={**n,'box':boxes[n['id']],'width':w,'height':h,'cx':(x0+x1)/2,'cy':(y0+y1)/2,'lines':wrap_label(n['label'],w-32),'rank':None}
    edges=[]
    for i,(e,(points,anchor)) in enumerate(zip(graph['edges'],routes)):
        label=' '.join(e['label'].split());w=txt_width(label,EDGE_FONT)+12;x,y=anchor
        edges.append({**e,'index':i,'label_lines':[label],'points':points,'label_box':[x,y,x+w,y+25],'outer':False,'placement_penalty':0})
    for e in edges:
        z=e['label_box'];penalty=0
        if min(z[:2])<8 or z[2]>WIDTH-8 or z[3]>HEIGHT-8:penalty+=10000
        penalty+=10000*sum(intersect(z,n['box']) for n in nodes.values())
        penalty+=10000*sum(intersect(z,o['label_box']) for o in edges if o is not e)
        penalty+=1000*sum(seg_rect(p,q,z) for o in edges for p,q in segments(o['points']))
        e['placement_penalty']=penalty
    return nodes,edges

def rounded_route(points, radius=7):
    """Rounded visual stroke; geometry retains original orthogonal control vertices."""
    clean=[]
    for p in points:
        if len(clean)>1 and ((clean[-2][0]==clean[-1][0]==p[0]) or (clean[-2][1]==clean[-1][1]==p[1])):clean[-1]=p
        else:clean.append(p)
    sampled=[clean[0]];cmd=[f'M {clean[0][0]:.2f} {clean[0][1]:.2f}']
    for i in range(1,len(clean)-1):
        a,b,c=clean[i-1:i+2];la=math.hypot(b[0]-a[0],b[1]-a[1]);lb=math.hypot(c[0]-b[0],c[1]-b[1]);r=min(radius,la/2,lb/2)
        start=[b[0]-(b[0]-a[0])*r/la,b[1]-(b[1]-a[1])*r/la];end=[b[0]+(c[0]-b[0])*r/lb,b[1]+(c[1]-b[1])*r/lb]
        q1=[start[k]+2*(b[k]-start[k])/3 for k in (0,1)];q2=[end[k]+2*(b[k]-end[k])/3 for k in (0,1)]
        cmd.append(f'L {start[0]:.2f} {start[1]:.2f} C {q1[0]:.2f} {q1[1]:.2f} {q2[0]:.2f} {q2[1]:.2f} {end[0]:.2f} {end[1]:.2f}')
        sampled.append(start)
        for t in [j/8 for j in range(1,9)]:sampled.append([(1-t)**2*start[k]+2*(1-t)*t*b[k]+t*t*end[k] for k in (0,1)])
    sampled.append(clean[-1]);cmd.append(f'L {clean[-1][0]:.2f} {clean[-1][1]:.2f}')
    return ' '.join(cmd),sampled

def dash_paths(points,on=7,off=5):
    paths=[];active=[];phase=0.;cycle=on+off
    for a,b in segments(points):
        length=math.hypot(b[0]-a[0],b[1]-a[1])
        if length<1e-6:continue
        dx=(b[0]-a[0])/length;dy=(b[1]-a[1])/length;cursor=0.
        while cursor<length-1e-6:
            drawing=phase<on-1e-6;remain=(on-phase) if drawing else (cycle-phase);step=min(remain,length-cursor)
            p=[a[0]+dx*cursor,a[1]+dy*cursor];q=[a[0]+dx*(cursor+step),a[1]+dy*(cursor+step)]
            if drawing:
                if not active:active=[p]
                active.append(q)
            elif active:paths.append(active);active=[]
            cursor+=step;phase=(phase+step)%cycle
            if cycle-phase<1e-6:phase=0.
    if active:paths.append(active)
    return paths

def render_graph(graph, slug, output_dir):
    """Return (SVG path, geometry dict) from a pre-existing documentary graph."""
    out=Path(output_dir);out.mkdir(parents=True,exist_ok=True)
    if not re.fullmatch(r'[A-Za-z0-9_.-]+',slug):raise ValueError('Unsafe slug')
    if len({n['id'] for n in graph['nodes']})!=len(graph['nodes']):raise ValueError('Duplicate node')
    nodes,edges=layout(graph,slug)
    esc=lambda x:html.escape(str(x),quote=True)
    s=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" width="{WIDTH}" height="{HEIGHT}" role="img" aria-labelledby="title-{slug} desc-{slug}">',f'<title id="title-{slug}">{esc(slug)} — {esc(graph.get("caption", ""))}</title>', '<rect width="1040" height="480" fill="#FFFFFF"/>', '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#526779"/></marker></defs>']
    labels={n['id']:' '.join(n['label'].split()) for n in graph['nodes']}
    description='Nós: '+ '; '.join(f'{n["id"]}: {labels[n["id"]]}' for n in graph['nodes'])+'. Relações: '+ '; '.join(f'{labels[e["from"]]} → {labels[e["to"]]}: {" ".join(e["label"].split())} ({e.get("kind", "normal")})' for e in graph['edges'])+'.'
    s.insert(2, f'<desc id="desc-{slug}">{esc(description)}</desc>')
    s.insert(3, '<metadata id="diagram-source">'+html.escape(json.dumps({'case_id':slug,'diagram':graph},ensure_ascii=False,separators=(',',':')))+'</metadata>')
    for e in edges:
        s.append(f'<g data-from="{esc(e["from"])}" data-to="{esc(e["to"])}" data-kind="{esc(e.get("kind","normal"))}"><title>{esc(e["label"])}</title>')
        dashed=e.get('kind') in ('return','reject')
        rounded,sampled=rounded_route(e['points'])
        if not dashed:
            s.append(f'<path d="{rounded}" fill="none" stroke="{LINE}" stroke-width="2"/>')
        else:
            for run in dash_paths(sampled):
                pts=' '.join(f'{x:.2f},{y:.2f}' for x,y in run)
                s.append(f'<polyline points="{pts}" fill="none" stroke="{LINE}" stroke-width="2" stroke-linejoin="round"/>')
        a,b=e['points'][-2:];length=math.hypot(b[0]-a[0],b[1]-a[1]);dx=(b[0]-a[0])/length;dy=(b[1]-a[1])/length
        tri=[b,[b[0]-dx*11-dy*5,b[1]-dy*11+dx*5],[b[0]-dx*11+dy*5,b[1]-dy*11-dx*5]]
        points=' '.join(f'{x:.2f},{y:.2f}' for x,y in tri)
        s.append(f'<polygon points="{points}" fill="{LINE}"/></g>')
    for n in nodes.values():
        x0,y0,x1,y1=n['box'];fill,border=STYLE.get(n.get('role'),STYLE['process']);w=x1-x0;h=y1-y0
        s.append(f'<g data-node-id="{esc(n["id"])}" data-role="{esc(n.get("role", "process"))}"><title>{esc(n["label"])}</title><rect x="{x0:.2f}" y="{y0:.2f}" width="{w:.2f}" height="{h:.2f}" rx="7" fill="{fill}" stroke="{border}" stroke-width="2"/>')
        if n.get('role')=='store':s.append(f'<path d="M{x0+10:.2f},{y0+9:.2f} H{x1-10:.2f}" stroke="{border}" stroke-width="1"/>')
        yy=n['cy']-(len(n['lines'])-1)*13+7.5
        for line in n['lines']:
            s.append(f'<text x="{n["cx"]:.2f}" y="{yy:.2f}" text-anchor="middle" font-family="Helvetica" font-size="{NODE_FONT}" fill="{INK}">{esc(line)}</text>');yy+=26
        s.append('</g>')
    for e in edges:
        x0,y0,x1,y1=e['label_box'];s.append(f'<g data-edge-label="{e["index"]}"><rect x="{x0:.2f}" y="{y0:.2f}" width="{x1-x0:.2f}" height="{y1-y0:.2f}" rx="3" fill="#FFFFFF"/><text x="{(x0+x1)/2:.2f}" y="{y0+19:.2f}" text-anchor="middle" font-family="Helvetica" font-size="{EDGE_FONT}" fill="{LINE}">{esc(e["label_lines"][0])}</text></g>')
    s.append('</svg>');svg='\n'.join(s)+'\n';path=out/f'{slug}.svg';path.write_text(svg)
    issues=[]
    for i,n in enumerate(nodes.values()):
        if n['box'][0]<8 or n['box'][1]<8 or n['box'][2]>WIDTH-8 or n['box'][3]>HEIGHT-8:issues.append({'type':'node_outside_viewbox','node':n['id']})
        for line in n['lines']:
            if txt_width(line,NODE_FONT)>n['width']-24:issues.append({'type':'node_text_width','node':n['id']})
        for other in list(nodes.values())[i+1:]:
            if intersect(n['box'],other['box']):issues.append({'type':'node_overlap','nodes':[n['id'],other['id']]})
    for e in edges:
        if e['placement_penalty']:issues.append({'type':'label_placement','edge':e['index'],'penalty':e['placement_penalty']})
        for n in nodes.values():
            if n['id'] in (e['from'],e['to']):continue
            if any(seg_rect(a,b,n['box']) for a,b in segments(e['points'])):issues.append({'type':'edge_crosses_node','edge':e['index'],'node':n['id']})
    semantic=json.dumps(graph,ensure_ascii=False,sort_keys=True,separators=(',',':'))
    meta={'slug':slug,'viewbox':[0,0,WIDTH,HEIGHT],'node_font_size':NODE_FONT,'edge_font_size':EDGE_FONT,'corner_radius':7,'semantic_sha256':hashlib.sha256(semantic.encode()).hexdigest(),'nodes':list(nodes.values()),'edges':edges,'issues':issues,'caption':graph.get('caption','')}
    (out/f'{slug}.geometry.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
    return path,meta

def load_cases(root):
    cases=[]
    for family in ['FB_Service','FB_Sequence']:
        p=Path(root)/family/'docs'/'manuals'/family/'catalog.json'
        for c in json.loads(p.read_text())['cases']:cases.append((family,c))
    return cases

def render_catalogs(root,output_dir,selected=None,catalog=None):
    out=Path(output_dir);out.mkdir(parents=True,exist_ok=True);results=[];cards=[]
    if catalog:
        catalog=Path(catalog);cases=[(catalog.parent.name,c) for c in json.loads(catalog.read_text())['cases']]
    else:cases=load_cases(root)
    for family,c in cases:
        if selected and c['id'] not in selected:continue
        path,meta=render_graph(c['diagram'],c['id'],out if catalog else out/family);results.append({'family':family,'id':c['id'],'path':str(path),'issues':meta['issues']})
        cards.append(f'<article id="{c["id"]}"><h2>{html.escape(c["id"])} · {html.escape(c["title"])}</h2>{path.read_text()}<p>{html.escape(c["diagram"].get("caption",""))}</p></article>')
    document='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Revisão dos diagramas documentais</title><style>body{margin:0;background:#edf1f4;color:#24333f;font:16px Arial,sans-serif}main{max-width:1160px;margin:24px auto;padding:0 20px}article{background:white;margin:24px 0;padding:24px;border:1px solid #c0ced8;break-inside:avoid}h1{font-size:26px}h2{font-size:20px;font-weight:600;color:#24577a;margin:0 0 14px}svg{width:100%;height:auto;display:block}p{line-height:1.5;color:#526779;margin:14px 0 0}@media print{body{background:white}article{border:0;padding:0;page-break-after:always}}</style><main><h1>Revisão dos diagramas documentais</h1><p>Rótulos, relações, identificadores e tipos preservados. Esta revisão trata da apresentação visual.</p>'''+''.join(cards)+'</main></html>'
    (out/'review.html').write_text(document)
    (out/'render-report.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
    topology=collections.Counter();families=collections.Counter();node_count=edge_count=0
    for family,c in cases:
        if selected and c['id'] not in selected:continue
        g=c['diagram'];ids={n['id']:i for i,n in enumerate(g['nodes'])}
        signature=';'.join(f'{ids[e["from"]]}>{ids[e["to"]]}' for e in g['edges'])
        topology[signature]+=1;families[family]+=1;node_count+=len(g['nodes']);edge_count+=len(g['edges'])
    summary={'diagrams':len(results),'families':dict(families),'nodes':node_count,'edges':edge_count,'issues':sum(len(x['issues']) for x in results),'node_font_px':NODE_FONT,'edge_font_px':EDGE_FONT,'font_family':'Helvetica','corner_radius_px':7,'viewBox':[0,0,WIDTH,HEIGHT],'distinct_topologies':len(topology),'topologies':dict(topology),'checks':['exact source metadata','node text fit','node/node overlap','node bounds','edge/other node intersection','edge label/node overlap','edge label/label overlap','edge label/stroke overlap','edge label bounds'],'scope':'DOCUMENTARY_GRAPH_LAYOUT_ONLY'}
    (out/'render-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    return results

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).parent/'branches');p.add_argument('--output',type=Path,default=Path(__file__).parent/'rendered');p.add_argument('--samples',action='store_true');p.add_argument('--catalog',type=Path,help='Render one catalog directly into --output');a=p.parse_args()
    selected={'SVC-001','SVC-068','SVC-071','SEQ-055'} if a.samples else None
    report=render_catalogs(a.root,a.output,selected,a.catalog)
    print(json.dumps({'diagrams':len(report),'issues':sum(len(x['issues']) for x in report),'review':str(a.output/'review.html')},ensure_ascii=False))
