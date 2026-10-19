"""Verify a genuine browser-completed Stripe test Checkout, then refund it."""
import json
import pathlib
import time
from api_smoke_test import call, ok, passed, OUT

context = json.loads((OUT / 'payment-context.json').read_text(encoding='utf-8'))
token = context['token']
reservation_id = context['reservation']['id']
route = '/api/payments/reservation/' + reservation_id
for attempt in range(15):
    status, payment = call('POST', route + '/verify', token=token)
    if status == 200 and payment['status'] == 'Paid':
        break
    time.sleep(2)
ok('Stripe confirms actual test payment', status == 200 and payment['status'] == 'Paid')
status, duplicate = call('POST', route + '/verify', token=token)
ok('Repeated verification is idempotent', status == 200 and duplicate['amount'] == payment['amount'])
status, rows = call('GET', '/api/reservations/mine', token=token)
reservation = next(r for r in rows['items'] if r['id'] == reservation_id)
ok('Paid reservation auto-confirmed', reservation['isPaid'] and reservation['status'] == 'Confirmed')
ok('Cannot start another checkout after payment', call('POST', route + '/checkout', {}, token=token)[0] == 400)
status, receipt = call('GET', route + '/receipt', token=token, raw=True)
ok('Actual payment receipt PDF', status == 200 and receipt.startswith(b'%PDF'))
(OUT / 'receipt.pdf').write_bytes(receipt)
status, _ = call('POST', '/api/reservations/' + reservation_id + '/cancel', {'reason':'Stripe sandbox integration refund'}, token=token)
ok('Paid reservation cancellation', status == 200)
for attempt in range(15):
    status, refund = call('POST', route + '/verify', token=token)
    if status == 200 and refund['status'] == 'Refunded':
        break
    time.sleep(2)
ok('Stripe confirms full refund', status == 200 and refund['status'] == 'Refunded' and refund['refundedAmount'] == payment['amount'])
status, repeated = call('POST', route + '/verify', token=token)
ok('Repeated refund verification is idempotent', status == 200 and repeated['refundedAmount'] == refund['refundedAmount'])
for attempt in range(15):
    status, notifications = call('GET', '/api/notifications', token=token)
    if status == 200 and any(n['title'] == 'Povrat sredstava potvrđen' for n in notifications['items']):
        break
    time.sleep(1)
ok('Worker delivers payment refund notification', any(n['title'] == 'Povrat sredstava potvrđen' for n in notifications['items']))
(OUT / 'stripe-checks.json').write_text(json.dumps({'passed':passed,'amount':payment['amount'],'currency':payment['currency'],'refund':refund['refundedAmount'],'mode':'Stripe test Checkout'},indent=2),encoding='utf-8')
print('Verified test payment and full refund; no real card used.')
