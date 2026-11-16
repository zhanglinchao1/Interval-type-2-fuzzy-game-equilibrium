"""Replay both exact covers and recompute every directed enclosure.

Also audit the invariant domains and the source hash. No derivative sample
is used to accept a cell. The cover may be reused after tightening arithmetic.
"""
from pathlib import Path
from fractions import Fraction as F
import hashlib
import json
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from verify_r3_sparse import VeinsBound,split,I,D,OUT,input_hull


def replay(root,depths):
    stack=[(root,0)];volume=F(0)
    for target in depths:
        assert stack
        V,depth=stack.pop()
        while depth<target:
            a,b=split(V);stack.append((a,depth+1));V,depth=b,depth+1
        assert depth==target
        volume+=F(1,2**depth)
        yield V
    assert not stack and volume==1


def main():
    path=OUT/'certificate.json';result=json.loads(path.read_text());calc=VeinsBound()
    fullroot=[[F(i==j) for j in range(4)] for i in range(4)]
    root=[[F(1,4)*(j==0)+F(3,4)*(i==j) for j in range(4)] for i in range(4)]
    original=calc.theta_vertices[:]
    calc.theta_vertices.append([input_hull(.4),input_hull(.35),input_hull(.25)])
    margin=min(calc.action_margin(V) for V in replay(fullroot,result['dominance_cover']))
    assert margin>0
    print('Dominance cover replay PASS',len(result['dominance_cover']),flush=True)
    maxes=[D(0)]*4;count=0
    boxes=[]
    for cover in result['covers']:
        bx,by=[[F(v) for v in b] for b in cover['theta_box']]
        boxes.append((bx,by))
        calc.theta_vertices=[[I(a),I(b),1-I(a)-I(b)] for a in bx for b in by]
        for V in replay(root,cover['leaf_depths']):
            maxes=list(map(max,maxes,calc.enclose(V)));count+=1
        print('Response cover replay PASS',count,flush=True)
    # Verify a rectangular tiling with shared boundaries, containing P*Omega.
    xs=sorted(set(v for bx,by in boxes for v in bx));ys=sorted(set(v for bx,by in boxes for v in by))
    assert len(xs)==len(ys)==3 and len(boxes)==4
    assert set((tuple(bx),tuple(by)) for bx,by in boxes)==set(
        ((xs[i],xs[i+1]),(ys[j],ys[j+1])) for i in range(2) for j in range(2))
    for th in original:
        assert xs[0]<=F(th[0].lo)<=F(th[0].hi)<=xs[-1]
        assert ys[0]<=F(th[1].lo)<=F(th[1].hi)<=ys[-1]
    k,kr,B,Br=map(I,maxes)
    feedback=calc.d+calc.c*B/(1-k)
    assert k.hi<1 and kr.hi<1 and feedback.hi<1
    z=I('.4');rate=max((1-I('.3')+I('.3')*(k+B*z)).hi,
                       (1-I('.004')+I('.004')*(calc.d+calc.c/z)).hi)
    assert rate<1
    result.update(kappa_vehicle=str(k.hi),kappa_rsu=str(kr.hi),B_vehicle=str(B.hi),
                  B_rsu=str(Br.hi),feedback=str(feedback.hi),
                  q_vehicle=str((1-I('.3')+I('.3')*k).hi),
                  weighted_norm_omega_scale='.4',joint_update_bound=str(rate),
                  response_cells=count,SC_payoff_margin=str(margin),
                  independent_cover_replay='PASS',
                  source_sha256=hashlib.sha256((OUT.parents[1]/'verify_r3_sparse.py').read_bytes()).hexdigest(),
                  audit_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    path.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['kappa_vehicle','kappa_rsu','B_vehicle','c','d','feedback','joint_update_bound','response_cells']},indent=2))


if __name__=='__main__':main()
