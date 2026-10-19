"""Disposable fresh database + API/worker test. Keeps the user's database intact."""
import datetime as dt
import json
import pathlib
import re
import subprocess
import time
import uuid
import argparse
import runpy
import api_smoke_test as api

root=pathlib.Path(__file__).resolve().parents[1]
api.BASE='http://localhost:5001'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--stripe-browser',action='store_true',help='Wait for real test Checkout in browser, then verify and refund')
parser.add_argument('--demo',action='store_true',help='Run all API flows and additional CRUD persistence checks in the disposable database')
parser.add_argument('--notification-checks',action='store_true',help='Check read-all ownership and idempotency')
parser.add_argument('--event-notification-checks',action='store_true',help='Verify client, owner and admin notices for booking, status and contact events')
args=parser.parse_args()
if args.demo:
    api.OUT=root/'tmp/audit/demo'
    api.OUT.mkdir(parents=True,exist_ok=True)
suffix=uuid.uuid4().hex[:10]
database='BeautyStudioFinalAudit_'+suffix
queue='beautystudio.final.audit.'+suffix
names=['beautystudio-final-api-'+suffix,'beautystudio-final-worker-'+suffix]
env_file=root/'tmp/audit/fresh-install.env'
def docker(*args):
    result=subprocess.run(['docker',*args],capture_output=True,text=True,encoding='utf-8',cwd=root)
    if result.returncode:
        raise RuntimeError('Docker command failed: '+args[0])
    return result.stdout.strip()

network=next(iter(json.loads(docker('inspect','--format','{{json .NetworkSettings.Networks}}','backend-api-1'))))
env=(root/'backend/.env').read_text(encoding='utf-8-sig')
env=re.sub(r'(?mi)^CONNECTION_STRING=(.*)$',lambda m:'CONNECTION_STRING='+re.sub(r'(?i)Database=[^;]+','Database='+database,m[1]),env)
env=re.sub(r'(?mi)^RABBITMQ_QUEUE=.*$', 'RABBITMQ_QUEUE='+queue,env)
env=re.sub(r'(?mi)^SEED_DEMO_DATA=.*$', 'SEED_DEMO_DATA=true',env)
env=re.sub(r'(?mi)^PAYMENT_RETURN_BASE_URL=.*$', 'PAYMENT_RETURN_BASE_URL=http://localhost:5001',env)
env_file.write_text(env,encoding='utf-8')
try:
    docker('run','-d','--name',names[0],'--network',network,'--env-file',str(env_file),'-p','5001:8080','backend-api')
    for _ in range(60):
        try:
            if api.call('GET','/health')[0]==200: break
        except OSError: pass
        time.sleep(1)
    api.ok('Fresh database migrated and API started',api.call('GET','/health')[0]==200)
    docker('run','-d','--name',names[1],'--network',network,'--env-file',str(env_file),'backend-worker')
    admin=api.login('admin','test'); owner=api.login('desktop','test'); mobile=api.login('mobile','test')
    people=api.get('/api/admin/users?pageSize=100',admin)['items']
    api.ok('Natural fictional demo clients seeded',{'petra.peric','zala.zalac','lejla.hadzic','ana.kovac','nina.juric','ema.basic'} <= {u['username'] for u in people})
    catalogue=api.get('/api/services?pageSize=100',mobile)
    api.ok('Fresh catalogue has useful demo services',catalogue['total']>=20)
    about=api.get('/api/information/about',mobile)
    api.ok('Fresh salon contacts available',bool(about['address'] and about['phone'] and about['email']))
    statuses=api.get('/api/reference/statuses',mobile)['items']
    api.ok('Four initial business status labels',len(statuses)==4)
    bookings=api.get('/api/reservations/mine?pageSize=100',mobile)['items']
    api.ok('Fresh bookings include completed and future appointments',len(bookings)>=14 and any(b['status']=='Completed' for b in bookings) and any(b['status']=='Pending' for b in bookings))
    completed=next(b for b in bookings if b['status']=='Completed' and not b['hasReview'])
    status,review=api.call('POST','/api/reviews',{'reservationId':completed['id'],'rating':5,'comment':'Isolated fresh install audit'},token=mobile)
    api.ok('Completed treatment accepts genuine client review',status==200)
    api.ok('Duplicate review rejected',api.call('POST','/api/reviews',{'reservationId':completed['id'],'rating':4},token=mobile)[0]==400)
    api.ok('Completed treatment cannot be cancelled',api.call('POST','/api/reservations/'+completed['id']+'/cancel',{'reason':'Audit'},token=mobile)[0]==400)
    payments=api.get('/api/payments/mine?pageSize=100',mobile)
    api.ok('Demo onsite payments have actual ledger totals',payments['total']>=12 and all(p['provider']=='OnSite' and p['amount']>0 for p in payments['items']))
    for _ in range(15):
        status,notices=api.call('GET','/api/notifications',token=mobile)
        if status==200 and notices['total']>0: break
        time.sleep(1)
    api.ok('Separate worker processes fresh seeded outbox',status==200 and notices['total']>0)
    status,category=api.call('POST','/api/admin/categories',{'name':'Fresh audit '+suffix,'isActive':True},token=admin)
    api.ok('Isolated category created',status==200)
    status,blog=api.call('POST','/api/admin/content/blog-posts',{'title':'Fresh category audit','content':'Fresh test content','categoryId':category['id'],'isPublished':True},token=admin)
    api.ok('Isolated blog created',status==200)
    api.ok('Category deactivation saved',api.call('PUT','/api/admin/categories/'+str(category['id']),{'name':category['name'],'isActive':False},token=admin)[0]==200)
    api.ok('Public blog detail hides inactive category',api.call('GET','/api/blog-posts/'+blog['id'],token=mobile)[0]==404)
    api.ok('Admin can still edit hidden blog',api.call('GET','/api/admin/content/blog-posts/'+blog['id'],token=admin)[0]==200)
    now=dt.datetime.now(dt.timezone.utc).date()
    for report in ['reservations','popular-services','payments']:
        status,pdf=api.call('GET','/api/reports/'+report+'?from='+str(now-dt.timedelta(days=30))+'&to='+str(now+dt.timedelta(days=30)),token=owner,raw=True)
        api.ok('Fresh PDF '+report,status==200 and pdf.startswith(b'%PDF'))
    (api.OUT/'fresh-install-checks.json').write_text(json.dumps({'passed':api.passed,'count':len(api.passed),'isolation':'temporary database and separate queue'},indent=2),encoding='utf-8')
    fresh_count=len(api.passed)
    if args.notification_checks:
        api.passed.clear()
        for _ in range(15):
            status,staff_notices=api.call('GET','/api/notifications?active=true',token=owner)
            if status==200 and staff_notices['total']>0: break
            time.sleep(1)
        api.ok('Owner has separate unread notifications',status==200 and staff_notices['total']>0)
        before=staff_notices['total']
        api.ok('Anonymous read-all forbidden',api.call('POST','/api/notifications/read-all')[0]==401)
        api.ok('Client read-all succeeds',api.call('POST','/api/notifications/read-all',token=mobile)[0]==204)
        api.ok('Client unread counter becomes zero',api.get('/api/notifications?active=true',mobile)['total']==0)
        api.ok('Read state saved for all client notifications',all(n['isRead'] for n in api.get('/api/notifications',mobile)['items']))
        api.ok('Other user unread notices unchanged',api.get('/api/notifications?active=true',owner)['total']==before)
        api.ok('Repeated read-all is idempotent',api.call('POST','/api/notifications/read-all',token=mobile)[0]==204)
        (api.OUT/'notification-checks.json').write_text(json.dumps({'passed':api.passed,'count':len(api.passed)},indent=2),encoding='utf-8')
    if args.event_notification_checks:
        api.passed.clear()
        types=api.get('/api/reference/notification-types?pageSize=100',admin)['items']
        api.ok('Contact notice type is active',any(x['code']=='ContactMessageReceived' and x['isActive'] for x in types))
        def wait_notice(token,title,fragment):
            for _ in range(20):
                status,payload=api.call('GET','/api/notifications?pageSize=100',token=token)
                if status==200 and any(x['title']==title and fragment in x['message'] for x in payload['items']): return True
                time.sleep(1)
            return False
        email='petra.'+suffix+'@example.com'
        status,_=api.call('POST','/api/contact',{'fullName':'Petra Perić','email':email,'phone':'+387 61 123 456','message':'Molim informacije o tretmanu.'})
        api.ok('Guest contact message saved',status==200)
        api.ok('Owner receives contact notice',wait_notice(owner,'Nova poruka klijenta',email))
        api.ok('Admin receives contact notice',wait_notice(admin,'Nova poruka klijenta',email))
        service=api.get('/api/services?pageSize=100',mobile)['items'][0]
        slot=None
        for offset in range(1,15):
            date=(dt.datetime.now(dt.timezone.utc)+dt.timedelta(days=offset)).date().isoformat()
            status,available=api.call('GET','/api/reservations/availability?serviceId='+str(service['id'])+'&date='+date,token=mobile)
            if status==200 and available['availableStartAtUtc']:
                slot=available['availableStartAtUtc'][0]
                break
        api.ok('Free slot for event check',slot is not None)
        status,booking=api.call('POST','/api/reservations',{'serviceId':service['id'],'startAtUtc':slot,'paymentMethod':'OnSite'},token=mobile)
        api.ok('Mobile booking saved for event check',status==200)
        api.ok('Owner receives new booking notice',wait_notice(owner,'Nova rezervacija',service['name']))
        api.ok('Admin receives new booking notice',wait_notice(admin,'Nova rezervacija',service['name']))
        reason='Termin potvrđen '+suffix
        status,_=api.call('POST','/api/reservations/'+booking['id']+'/status',{'status':'Confirmed','reason':reason},token=owner)
        api.ok('Owner confirms booking for event check',status==200)
        for label,token in [('Client',mobile),('Owner',owner),('Admin',admin)]:
            api.ok(label+' receives changed status notice',wait_notice(token,'Rezervacija potvrđena',reason))
        (api.OUT/'event-notification-checks.json').write_text(json.dumps({'passed':api.passed,'count':len(api.passed),'isolation':'temporary database and separate queue'},indent=2),encoding='utf-8')
    if args.demo:
        api.passed.clear()
        api.run()
        api_count=len(api.passed)
        stripe_count=0
        if args.stripe_browser:
            resume=api.OUT/'stripe-browser-complete.txt'
            resume.unlink(missing_ok=True)
            print('STRIPE_BROWSER_READY: payment-context.json stored privately; waiting for Checkout.',flush=True)
            for _ in range(600):
                if resume.exists(): break
                time.sleep(1)
            else: raise TimeoutError('Browser Checkout not completed within 10 minutes')
            api.passed.clear()
            runpy.run_path(str(root/'test/stripe_checkout_test.py'),run_name='__main__')
            stripe_count=len(api.passed)
        api.passed.clear()
        runpy.run_path(str(root/'test/profile_privacy_test.py'),run_name='__main__')
        profile_count=len(api.passed)
        api.passed.clear()
        import demo_persistence_test
        demo_persistence_test.run()
        summary={'freshInstall':fresh_count,'apiFlows':api_count,'profile':profile_count,'persistence':len(api.passed),'stripeChecks':stripe_count,'isolation':'disposable database and queue','stripe':'real test charge and refund' if stripe_count else 'real Checkout creation and cancellation; no new card charge'}
        (api.OUT/'demo-summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
        print(json.dumps(summary),flush=True)
    print('Fresh installation verified. Cleaning only disposable test resources.',flush=True)
finally:
    for name in reversed(names):
        subprocess.run(['docker','rm','-f',name],capture_output=True,cwd=root)
    assert re.fullmatch(r'BeautyStudioFinalAudit_[0-9a-f]{10}',database)
    command='/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "IF DB_ID(\''+database+'\') IS NOT NULL DROP DATABASE ['+database+']"'
    docker('exec','backend-sqlserver-1','/bin/sh','-c',command)
    for q in [queue,queue+'.dead']:
        subprocess.run(['docker','exec','backend-rabbitmq-1','rabbitmqctl','delete_queue',q],capture_output=True,cwd=root)
    env_file.unlink(missing_ok=True)
