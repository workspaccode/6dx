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
for f in ['V2Offline.dc.html','V2SyncFailed.dc.html','V2AccessRevoked.dc.html','V3NoPermission.dc.html','V3NotFound.dc.html','V2EmptyProjects.dc.html','V3GHAppInstall.dc.html','V3GHInstalling.dc.html','V3ImportIssues.dc.html','V3MapContributors.dc.html','V3MultiProvider.dc.html','V2AcceptInvite.dc.html','V2LinkGitHub.dc.html','V2InviteExpired.dc.html','V3JoinRequests.dc.html','V3BulkInvite.dc.html']:
    print('=====', f)
    print(txt(f)[:340])
