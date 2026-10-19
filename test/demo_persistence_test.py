"""CRUD round trips, run only against the disposable demo database."""
import json
import uuid
import api_smoke_test as api

def run():
    assert api.BASE=='http://localhost:5001', 'Use fresh_install_test.py --demo'
    marker='demo-'+uuid.uuid4().hex[:10]
    admin=api.login('admin','test'); owner=api.login('desktop','test'); client=api.login('mobile','test')
    def write(label,method,path,body,token=admin,expected=200):
        status,value=api.call(method,path,body,token=token)
        api.ok(label,status==expected)
        return value
    def row(path,identity,token=admin):
        return next(x for x in api.get(path+'?pageSize=100',token)['items'] if x['id']==identity)
    context=json.loads((api.OUT/'payment-context.json').read_text(encoding='utf-8'))
    card=next(r for r in api.get('/api/reservations/mine?pageSize=100',context['token'])['items'] if r['id']==context['reservation']['id'])
    if card['status']!='Cancelled':
        write('Unpaid Stripe demo reservation cancelled','POST','/api/reservations/'+context['reservation']['id']+'/cancel',{'reason':marker},context['token'])
    else:
        api.ok('Stripe refunded reservation remains cancelled',card['status']=='Cancelled')
    category=write('Category created','POST','/api/admin/categories',{'name':marker,'isActive':True})
    category=write('Category renamed','PUT','/api/admin/categories/'+str(category['id']),{'name':marker+' edited','isActive':True})
    api.ok('Category rename survives reload',row('/api/admin/categories',category['id'])['name']==marker+' edited')
    service_body={'name':marker,'description':'Demonstration service','price':42.5,'durationMinutes':35,'categoryId':category['id'],'isActive':True}
    service=write('Service created','POST','/api/admin/services',service_body)
    service_body.update(price=48,durationMinutes=40,name=marker+' edited')
    write('Service updated','PUT','/api/admin/services/'+str(service['id']),service_body)
    saved=row('/api/services',service['id'],client)
    api.ok('Service price duration and category survive client reload',saved['price']==48 and saved['durationMinutes']==40 and saved['categoryName']==category['name'])
    service_body['isActive']=False
    write('Service deactivated','PUT','/api/admin/services/'+str(service['id']),service_body)
    api.ok('Inactive service hidden after client reload',not any(x['id']==service['id'] for x in api.get('/api/services?pageSize=100',client)['items']))
    write('Category deactivated after service','PUT','/api/admin/categories/'+str(category['id']),{'name':category['name'],'isActive':False})
    active_category=next(c['id'] for c in api.get('/api/admin/categories?pageSize=100',admin)['items'] if c['isActive'])
    image='https://images.unsplash.com/photo-1604654894610-df63bc536371'
    gallery_body={'title':marker,'description':'Uredan manikir u nježnoj ružičastoj nijansi.','imageUrl':image,'categoryId':active_category,'isActive':True}
    gallery=write('Gallery item created','POST','/api/admin/content/gallery',gallery_body,owner)
    gallery_body['title']=marker+' gallery edited'
    gallery_body['description']='Kratki nokti sa sjajnom završnicom, za svakodnevne prilike.'
    write('Gallery item updated','PUT','/api/admin/content/gallery/'+gallery['id'],gallery_body,owner)
    api.ok('Gallery edit survives client reload',row('/api/gallery',gallery['id'],client)['title']==gallery_body['title'])
    api.ok('Gallery description survives guest reload',row('/api/gallery',gallery['id'],None)['description']==gallery_body['description'])
    api.ok('Gallery description survives management reload',row('/api/admin/content/gallery',gallery['id'],owner)['description']==gallery_body['description'])
    api.ok('Gallery can be searched by description',any(x['id']==gallery['id'] for x in api.get('/api/gallery?search=svakodnevne')['items']))
    write('Overlong gallery description rejected','PUT','/api/admin/content/gallery/'+gallery['id'],{**gallery_body,'description':'x'*3001},owner,expected=400)
    gallery_body['isActive']=False
    write('Gallery item deactivated','PUT','/api/admin/content/gallery/'+gallery['id'],gallery_body,owner)
    api.ok('Inactive gallery item hidden after reload',not any(x['id']==gallery['id'] for x in api.get('/api/gallery?pageSize=100',client)['items']))
    api.ok('Inactive gallery item hidden from guest',not any(x['id']==gallery['id'] for x in api.get('/api/gallery?pageSize=100')['items']))
    guest_message={'fullName':'Petra Perić','email':'petra.peric@example.com','phone':'+387 61 234 567','message':'Da li imate slobodan termin za manikir u petak poslije podne?'}
    sent=write('Guest can send contact form','POST','/api/contact',guest_message,None)
    api.ok('Guest contact saved for staff',row('/api/contact',sent['id'],owner)['message']==guest_message['message'])
    write('Guest contact validation enforced','POST','/api/contact',{**guest_message,'email':'invalid'},None,expected=400)
    blog_body={'title':marker,'content':'Original long article. '*30,'imageUrl':image,'categoryId':active_category,'isPublished':True}
    blog=write('Blog created','POST','/api/admin/content/blog-posts',blog_body,owner)
    blog_body.update(title=marker+' blog edited',content='Complete edited article. '*40)
    write('Blog updated','PUT','/api/admin/content/blog-posts/'+blog['id'],blog_body,owner)
    api.ok('Full blog edit survives detail reload',api.get('/api/blog-posts/'+blog['id'],client)['content']==blog_body['content'].strip())
    blog_body['isPublished']=False
    write('Blog unpublished','PUT','/api/admin/content/blog-posts/'+blog['id'],blog_body,owner)
    api.ok('Unpublished blog unavailable to client',api.call('GET','/api/blog-posts/'+blog['id'],token=client)[0]==404)
    faq_body={'question':marker,'answer':'First answer','isActive':True,'sortOrder':99}
    faq=write('FAQ created','POST','/api/information/admin/faq',faq_body,owner)
    faq_body['answer']='Edited answer'
    write('FAQ updated','PUT','/api/information/admin/faq/'+faq['id'],faq_body,owner)
    api.ok('FAQ answer survives client reload',row('/api/information/faq',faq['id'],client)['answer']=='Edited answer')
    faq_body['isActive']=False
    write('FAQ deactivated','PUT','/api/information/admin/faq/'+faq['id'],faq_body,owner)
    api.ok('Inactive FAQ hidden after reload',not any(x['id']==faq['id'] for x in api.get('/api/information/faq?pageSize=100',client)['items']))
    original=api.get('/api/information/about',client)
    about={k:original[k] for k in ['title','content','imageUrl','address','phone','email','foundedYear','openingHour','closingHour','depositPercent','cityId']}
    changed={**about,'title':marker+' salon','address':'Demo address 11','depositPercent':35}
    write('Salon settings updated','PUT','/api/information/admin/about',changed,owner)
    loaded=api.get('/api/information/about',client)
    api.ok('Salon cache refreshed immediately',loaded['title']==changed['title'] and loaded['address']==changed['address'] and loaded['depositPercent']==35)
    write('Salon settings restored','PUT','/api/information/admin/about',about,owner)
    user_body={'firstName':'Demo','lastName':'Client','username':marker,'email':marker+'@example.invalid','password':'DemoPassword123!','role':'Client','isActive':True}
    user=write('Admin creates account','POST','/api/admin/users',user_body)
    user_token=api.login(marker,'DemoPassword123!')
    update={**user_body,'password':None,'firstName':'Edited','role':'Owner'}
    write('Admin edits account and role','PUT','/api/admin/users/'+user['id'],update)
    api.ok('Changed account survives reload',row('/api/admin/users',user['id'])['firstName']=='Edited')
    api.ok('Role change invalidates previous session',api.call('GET','/api/profile',token=user_token)[0]==401)
    new_token=api.login(marker,'DemoPassword123!')
    api.ok('New owner session can load dashboard',api.call('GET','/api/dashboard',token=new_token)[0]==200)
    update['isActive']=False
    write('Admin deactivates account','PUT','/api/admin/users/'+user['id'],update)
    api.ok('Deactivation invalidates session',api.call('GET','/api/profile',token=new_token)[0]==401)
    api.ok('Inactive account cannot sign in',api.call('POST','/api/auth/login',{'usernameOrEmail':marker,'password':'DemoPassword123!'})[0] in (400,401))
    notices=api.get('/api/notifications?pageSize=100',client)['items']
    if notices:
        n=notices[0]
        write('Notice marked read','POST','/api/notifications/'+n['id']+'/read',None,client,204)
        api.ok('Read state survives notification reload',row('/api/notifications',n['id'],client)['isRead'])
    bookings=api.get('/api/reservations/mine?pageSize=100',client)['items']
    api.ok('Completed review status survives reservation reload',sum(b['hasReview'] for b in bookings)>=7)
    completed=next(b for b in bookings if b['status']=='Completed')
    status,receipt=api.call('GET','/api/payments/reservation/'+completed['id']+'/receipt',token=client,raw=True)
    api.ok('Onsite payment receipt can be downloaded',status==200 and receipt.startswith(b'%PDF'))
    services=api.get('/api/services?pageSize=100',client)['items']
    reviewed=next(b for b in bookings if b['status']=='Completed' and b['hasReview'])
    service_id=next(s['id'] for s in services if s['name']==reviewed['serviceName'])
    api.ok('Saved reviews can be loaded',api.get('/api/reviews?serviceId='+str(service_id),client)['total']>0)
    api.ok('Owner dashboard reload succeeds',api.call('GET','/api/dashboard',token=owner)[0]==200)
    api.ok('Recommendations reload succeeds',api.call('GET','/api/recommendations',token=client)[0]==200)
    (api.OUT/'persistence-checks.json').write_text(json.dumps({'passed':api.passed,'count':len(api.passed)},indent=2),encoding='utf-8')
