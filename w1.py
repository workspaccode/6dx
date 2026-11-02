import re,json,html as H
p=r'C:\Users\xbrym\Downloads\6DX-all-screens.html'
s=open(p,encoding='utf-8').read()
d=json.loads(re.search(r'<script type="application/json" id="data">(.*?)</script>',s,re.S).group(1))
def txt(f):
    v=d['files'][f]
    v=re.sub(r'<script.*?</script>','',v,flags=re.S)
    v=re.sub(r'<style.*?</style>','',v,flags=re.S)
    v=re.sub(r'<svg.*?</svg>','',v,flags=re.S)
    v=re.sub(r'<[^>]+>','|',v)
    v=H.unescape(v)
    return ' || '.join([l.strip() for l in v.split('|') if l.strip() and not l.strip().startswith('{{')])
web=[x for x in d['pages'] if x['id']=='web'][0]
print('=== WEB SECTIONS ===')
for sec in web['sections']:
    print('--', sec['title'], len(sec['items']))
    for it in sec['items']:
        print('   ', it['file'], '|', it['title'])
