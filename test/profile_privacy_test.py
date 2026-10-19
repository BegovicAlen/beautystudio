"""Local profile upload privacy and notification preference checks."""
import base64, json, urllib.error, urllib.request, uuid
from api_smoke_test import BASE, OUT, call, ok, passed, login

if BASE != 'http://localhost:5001':
    raise RuntimeError('Use test/fresh_install_test.py --demo for isolated profile checks.')

context=json.loads((OUT/'payment-context.json').read_text(encoding='utf-8'))
token=login(context['username'],'UpdatedPassword123!'); admin=login('admin','test')
def upload(data, mime):
    boundary='audit'+uuid.uuid4().hex
    body=(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="test.png"\r\nContent-Type: {mime}\r\n\r\n'.encode()+data+f'\r\n--{boundary}--\r\n'.encode())
    request=urllib.request.Request(BASE+'/api/profile/image',data=body,method='POST',headers={'Authorization':'Bearer '+token,'Content-Type':'multipart/form-data; boundary='+boundary})
    try:
        with urllib.request.urlopen(request,timeout=30) as response:
            return response.status,json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code,None

ok('Fake image rejected',upload(b'not an image','image/png')[0]==400)
png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lXcAAAAASUVORK5CYII=')
status,image=upload(png,'image/png')
ok('Profile PNG uploaded',status==200)
path=image['imageUrl']
ok('Profile image requires authentication',call('GET',path,raw=True)[0]==401)
ok('Profile image owner can read',call('GET',path,token=token,raw=True)[0]==200)
ok('Different account cannot read image',call('GET',path,token=admin,raw=True)[0]==404)
status,profile=call('GET','/api/profile',token=token)
profile['profileImageUrl']=path
status,_=call('PUT','/api/profile',profile,token=token)
ok('Owned profile image saved',status==200)
profile['notificationsEnabled']=False
status,_=call('PUT','/api/profile',profile,token=token)
ok('Notification preference saved',status==200)
claims=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'=='))
recipient=claims.get('sub') or claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
types=call('GET','/api/reference/notification-types',token=admin)[1]['items']
status,_=call('POST','/api/admin/notices',{'recipientId':recipient,'notificationTypeId':types[0]['id'],'title':'Preference audit','message':'Disposable test notice'},token=admin)
ok('Disabled notifications respected',status==400)
profile['notificationsEnabled']=True
ok('Preference restored',call('PUT','/api/profile',profile,token=token)[0]==200)
ok('Unsigned Stripe webhook rejected',call('POST','/api/stripe/webhook',{})[0]==400)
(OUT/'profile-checks.json').write_text(json.dumps({'passed':passed,'count':len(passed)},indent=2),encoding='utf-8')
