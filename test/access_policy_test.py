"""Read-only checks of guest content and authenticated role boundaries."""
import json
import api_smoke_test as api

def run():
    paths=['/api/services','/api/gallery','/api/blog-posts','/api/information/faq','/api/information/about','/api/reference/cities','/api/reference/statuses','/api/reviews?serviceId=1','/api/reservations/mine','/api/notifications','/api/dashboard','/api/admin/users']
    for path in paths[:8]:
        api.ok('Guest content available '+path,api.call('GET',path)[0]==200)
    for path in paths[8:]:
        api.ok('Anonymous blocked '+path,api.call('GET',path)[0]==401)
    for path in ['/api/profile','/api/payments/mine','/api/recommendations']:
        api.ok('Guest cannot read private data '+path,api.call('GET',path)[0]==401)
    for path in ['/api/reservations','/api/reviews','/api/activities','/api/admin/content/gallery']:
        api.ok('Guest cannot mutate private data '+path,api.call('POST',path,{})[0]==401)
    mobile=api.login('mobile','test'); owner=api.login('desktop','test'); admin=api.login('admin','test')
    for path in paths[:10]:
        api.ok('Client access '+path,api.call('GET',path,token=mobile)[0]==200)
    api.ok('Client cannot access staff dashboard',api.call('GET','/api/dashboard',token=mobile)[0]==403)
    api.ok('Client cannot access admin users',api.call('GET','/api/admin/users',token=mobile)[0]==403)
    api.ok('Owner dashboard available',api.call('GET','/api/dashboard',token=owner)[0]==200)
    api.ok('Owner cannot access admin users',api.call('GET','/api/admin/users',token=owner)[0]==403)
    api.ok('Admin users available',api.call('GET','/api/admin/users',token=admin)[0]==200)
    api.ok('Invalid session blocked',api.call('GET','/api/profile',token='invalid')[0]==401)
    api.ok('Recovery remains reachable',api.call('POST','/api/auth/reset-password',{'usernameOrEmail':'missing-audit-account','recoveryCode':'0'*48,'newPassword':'ExamplePassword123!'})[0]==400)
    (api.OUT/'access-policy-checks.json').write_text(json.dumps({'passed':api.passed,'count':len(api.passed)},indent=2),encoding='utf-8')
if __name__=='__main__': run()
