#!/usr/bin/env python3
"""Strict daily economic walkthrough comparison; never round or ignore mismatches."""
import argparse,json
from pathlib import Path

def compare(before, after):
    errors=[]
    def visit(a,b,path):
        if type(a) is not type(b):
            errors.append({'path':path,'before':a,'after':b})
        elif isinstance(a,dict):
            for key in sorted(set(a)|set(b)):
                if key not in a or key not in b:
                    errors.append({'path':path+'/'+key,'before':a.get(key),'after':b.get(key)})
                else: visit(a[key],b[key],path+'/'+key)
        elif isinstance(a,list):
            if len(a)!=len(b): errors.append({'path':path+'/length','before':len(a),'after':len(b)})
            for i,(x,y) in enumerate(zip(a,b)):visit(x,y,path+'/'+str(i))
        elif a!=b:errors.append({'path':path,'before':a,'after':b})
    visit(before,after,'')
    return {'equal':not errors,'before_days':len(before.get('days',[])),'after_days':len(after.get('days',[])), 'seed':before.get('seed'),'difference_count':len(errors),'differences':errors}

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('before',type=Path)
    parser.add_argument('after',type=Path)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    result=compare(json.loads(args.before.read_text(encoding='utf-8')),json.loads(args.after.read_text(encoding='utf-8')))
    args.out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(('PASS' if result['equal'] else 'FAIL')+f": seed {result['seed']}, {result['before_days']} / {result['after_days']} daily snapshots, {result['difference_count']} differences")
    raise SystemExit(0 if result['equal'] else 1)
