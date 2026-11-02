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
for f in ['V2Commits.dc.html','V3ReleaseTracker.dc.html','V3ReviewerPick.dc.html','V3BigPRWarning.dc.html','V3MergeFromApp.dc.html','V3SprintHistory.dc.html','V3EstimateLearning.dc.html','V3Dependencies.dc.html','V3TaskContext.dc.html','V3BugReport.dc.html','V3BulkActions.dc.html','V3EditTask.dc.html','V3RegionalCalendar.dc.html','V3Billing.dc.html','V3ExportData.dc.html','V3WeeklySummary.dc.html','V3RichNotification.dc.html','V3PushPermission.dc.html']:
    print('=====', f)
    print(txt(f)[:280])
