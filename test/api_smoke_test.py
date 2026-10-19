"""Integration checks against the real local API, SQL Server and RabbitMQ.

Creates uniquely named audit users/content/appointments. Never logs credentials.
Stripe charges are exercised separately through genuine Stripe test Checkout.
Run: python -X utf8 test/fresh_install_test.py --demo
"""
import base64
import concurrent.futures
import datetime as dt
import io
import json
import pathlib
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

BASE = "http://localhost:5000"
OUT = pathlib.Path("tmp/audit")
OUT.mkdir(parents=True, exist_ok=True)
passed = []
suffix = uuid.uuid4().hex[:10]
marker = "audit-" + suffix

def call(method, path, body=None, token=None, raw=False, headers=None):
    data = None if body is None else json.dumps(body).encode()
    hs = {"Content-Type": "application/json", **(headers or {})}
    if token:
        hs["Authorization"] = "Bearer " + token
    request = urllib.request.Request(BASE + path, data=data, method=method, headers=hs)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            value = response.read()
            return response.status, value if raw else (json.loads(value) if value else None)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            print("Authentication rate limit reached; waiting for the next window.", flush=True)
            time.sleep(min(65, max(1, int(error.headers.get("Retry-After", "61")))))
            return call(method, path, body, token, raw, headers)
        value = error.read()
        try:
            return error.code, json.loads(value)
        except (json.JSONDecodeError, UnicodeDecodeError):
            return error.code, None

def ok(label, condition):
    if not condition:
        raise AssertionError(label)
    passed.append(label)
    print("PASS", label, flush=True)

def get(path, token=None):
    status, value = call("GET", path, token=token)
    ok("GET " + path.split("?")[0], status == 200)
    return value

def login(username, password):
    status, value = call("POST", "/api/auth/login", {"usernameOrEmail": username, "password": password})
    ok("Login " + username.split("_")[0], status == 200)
    return value["token"]

def register(tag):
    user = "audit_" + suffix + "_" + tag
    password = "AuditPassword123!"
    status, value = call("POST", "/api/auth/register", {"firstName": "Audit", "lastName": "Client", "username": user, "email": user + "@example.invalid", "password": password, "role": "Admin"})
    ok("Registration cannot escalate role", status == 200 and value["role"] == "Client")
    ok("Recovery code issued once", len(value["recoveryCode"]) == 48)
    return user, password, value

def run():
    if BASE != "http://localhost:5001":
        raise RuntimeError("Use test/fresh_install_test.py --demo; generated fixtures must stay in a disposable database.")
    get("/health")
    admin = login("admin", "test")
    owner = login("desktop", "test")
    mobile = login("mobile", "test")
    cities = get("/api/reference/cities?pageSize=1", mobile)
    ok("Reference pagination", len(cities["items"]) == 1 and cities["total"] >= 3)
    for path in ["/api/services", "/api/gallery", "/api/blog-posts", "/api/information/faq", "/api/information/about", "/api/reference/statuses"]:
        get(path, mobile)
    about = get("/api/information/about", mobile)
    ok("Studio hours and deposit configured", 0 <= about["openingHour"] < about["closingHour"] <= 23 and 1 <= about["depositPercent"] <= 100)
    ok("Guest cannot read personal data", call("GET", "/api/reservations/mine")[0] == 401)
    ok("Client cannot read admin users", call("GET", "/api/admin/users", token=mobile)[0] == 403)
    ok("Owner cannot change admin-only reference data", call("POST", "/api/admin/reference/cities", {"name": marker, "isActive": True}, token=owner)[0] == 403)
    one, password, session = register("one")
    two, password_two, session_two = register("two")
    token, other = session["token"], session_two["token"]
    old_code = session["recoveryCode"]
    ok("Incorrect recovery code rejected", call("POST", "/api/auth/reset-password", {"usernameOrEmail": one, "recoveryCode": "0" * 48, "newPassword": "UpdatedPassword123!"})[0] == 400)
    status, recovery = call("POST", "/api/auth/reset-password", {"usernameOrEmail": one, "recoveryCode": old_code, "newPassword": "UpdatedPassword123!"})
    ok("Recovery resets password", status == 200 and recovery["recoveryCode"] != old_code)
    ok("Reset revokes previous JWT", call("GET", "/api/profile", token=token)[0] == 401)
    ok("Recovery code is single-use", call("POST", "/api/auth/reset-password", {"usernameOrEmail": one, "recoveryCode": old_code, "newPassword": "AnotherPassword123!"})[0] == 400)
    token = login(one, "UpdatedPassword123!")
    status, city = call("POST", "/api/admin/reference/cities", {"name": marker, "isActive": True}, token=admin)
    ok("City CRUD create", status == 200)
    status, profile = call("PUT", "/api/profile", {"firstName": "Audit", "lastName": "Client", "email": one + "@example.invalid", "cityId": city["id"], "notificationsEnabled": True}, token=token)
    ok("Profile city FK", status == 200 and profile["cityId"] == city["id"])
    ok("Used city cannot deactivate", call("PUT", "/api/admin/reference/cities/" + str(city["id"]), {"name": marker, "isActive": False}, token=admin)[0] == 400)
    ok("Email format validation", call("PUT", "/api/profile", {"firstName": "Audit", "lastName": "Client", "email": "bad@example", "notificationsEnabled": True}, token=token)[0] == 400)
    ok("Contact phone validation", call("POST", "/api/contact", {"fullName": "Audit Client", "email": one + "@example.invalid", "phone": "bad", "message": marker}, token=token)[0] == 400)
    status, _ = call("POST", "/api/contact", {"fullName": "Audit Client", "email": one + "@example.invalid", "phone": "+387 61 123 456", "message": marker}, token=token)
    ok("Contact saved", status == 200)
    ok("Contact search", get("/api/contact?search=" + marker, admin)["total"] == 1)
    catalogue = get("/api/services?pageSize=1", mobile)
    next_page = get("/api/services?page=2&pageSize=1", mobile)
    ok("Distinct catalogue pages", catalogue["items"][0]["id"] != next_page["items"][0]["id"])
    all_services = get("/api/services?pageSize=100", mobile)["items"]
    service = next(s for s in all_services if s["durationMinutes"] <= 60)
    category = service["categoryId"]
    status, gallery = call("POST", "/api/admin/content/gallery", {"title": marker, "imageUrl": "https://images.unsplash.com/photo-1604654894610-df63bc536371", "categoryId": category, "isActive": True}, token=admin)
    ok("Gallery category FK", status == 200 and gallery["categoryId"] == category)
    status, blog = call("POST", "/api/admin/content/blog-posts", {"title": marker, "content": "Testirani edukativni sadržaj. " * 30, "imageUrl": gallery["imageUrl"], "categoryId": category, "isPublished": True}, token=admin)
    ok("Blog category FK", status == 200 and blog["categoryId"] == category)
    preview = get("/api/blog-posts?search=" + marker, mobile)
    detail = get("/api/blog-posts/" + blog["id"], mobile)
    ok("Master/detail separates excerpt", len(preview["items"][0]["content"]) <= 180 and len(detail["content"]) > 180)
    status, _ = call("POST", "/api/activities", {"type": "GalleryViewed", "galleryItemId": gallery["id"]}, token=token)
    ok("Gallery signal stored", status == 204)
    recommendations = get("/api/recommendations", token)
    recommended = next(s for s in all_services if s["id"] == recommendations[0]["serviceId"])
    ok("Gallery interest affects service recommendations", recommended["categoryId"] == category)
    ok("Cannot fabricate a booking signal", call("POST", "/api/activities", {"type": "ServiceReserved", "serviceId": service["id"]}, token=token)[0] == 400)
    day = (dt.datetime.now(dt.timezone.utc).date() + dt.timedelta(days=12)).isoformat()
    slots = get("/api/reservations/availability?serviceId=" + str(service["id"]) + "&date=" + day, token)["availableStartAtUtc"]
    ok("Future availability returned", bool(slots))
    body = {"serviceId": service["id"], "startAtUtc": slots[0], "paymentMethod": "OnSite"}
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda jwt: call("POST", "/api/reservations", body, token=jwt), [token, other]))
    ok("Concurrent booking has one winner", sorted(r[0] for r in results) == [200, 400])
    winner = 0 if results[0][0] == 200 else 1
    appointment = results[winner][1]
    owner_token = [token, other][winner]
    wrong_token = [other, token][winner]
    ok("Ownership enforced", call("POST", "/api/reservations/" + appointment["id"] + "/cancel", {"status": "Cancelled", "reason": marker}, token=wrong_token)[0] in (400, 404))
    status, custom = call("POST", "/api/admin/reference/statuses", {"name": marker, "code": "Confirmed", "isActive": True}, token=admin)
    ok("Custom reservation status label created", status == 200)
    status, confirmed = call("POST", "/api/reservations/" + appointment["id"] + "/status", {"status": "Confirmed", "statusDefinitionId": custom["id"], "reason": marker}, token=owner)
    ok("Owner selects custom status label", status == 200 and confirmed["statusDisplayName"] == marker)
    ok("Used status label cannot deactivate", call("PUT", "/api/admin/reference/statuses/" + str(custom["id"]), {"name": marker, "code": "Confirmed", "isActive": False}, token=admin)[0] == 400)
    ok("Cannot complete future appointment", call("POST", "/api/reservations/" + appointment["id"] + "/status", {"status": "Completed", "reason": marker}, token=owner)[0] == 400)
    ok("Cannot review unfinished appointment", call("POST", "/api/reviews", {"reservationId": appointment["id"], "rating": 5}, token=owner_token)[0] == 400)
    status, cancelled = call("POST", "/api/reservations/" + appointment["id"] + "/cancel", {"status": "Cancelled", "reason": marker}, token=owner_token)
    ok("Soft cancellation", status == 200 and cancelled["status"] == "Cancelled")
    history = get("/api/reservations/" + appointment["id"] + "/history?pageSize=1", owner)
    ok("Paged audit trail", history["total"] >= 3 and len(history["items"]) == 1)
    ok("Outside working hours rejected", call("POST", "/api/reservations", {"serviceId": service["id"], "startAtUtc": day + "T23:00:00Z", "paymentMethod": "OnSite"}, token=token)[0] == 400)
    notice = None
    for _ in range(15):
        status, value = call("GET", "/api/notifications?search=" + marker, token=owner_token)
        if status == 200 and value["items"]:
            notice = value["items"][0]
            break
        time.sleep(1)
    ok("Worker delivers status notification", notice is not None)
    status, _ = call("POST", "/api/notifications/" + notice["id"] + "/read", token=owner_token)
    ok("Notification marked read", status == 204)
    ok("Notification ownership enforced", call("POST", "/api/notifications/" + notice["id"] + "/read", token=wrong_token)[0] == 404)
    status, notice_type = call("POST", "/api/admin/reference/notification-types", {"name": marker, "isActive": True}, token=admin)
    ok("Custom notification type created", status == 200)
    claims = json.loads(base64.urlsafe_b64decode(token.split('.')[1] + '=='))
    recipient = claims.get("sub") or claims["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"]
    status, _ = call("POST", "/api/admin/notices", {"recipientId": recipient, "notificationTypeId": notice_type["id"], "title": marker + " custom", "message": marker}, token=admin)
    ok("Custom notification queued", status == 204)
    for _ in range(15):
        notices = get("/api/notifications?search=" + marker, token)["items"]
        if any(n["title"] == marker + " custom" for n in notices):
            break
        time.sleep(1)
    ok("Worker delivers custom notification", any(n["title"] == marker + " custom" for n in notices))
    today = dt.datetime.now(dt.timezone.utc).date()
    for report in ["reservations", "popular-services", "payments"]:
        status, pdf = call("GET", "/api/reports/" + report + "?from=" + (today - dt.timedelta(days=60)).isoformat() + "&to=" + (today + dt.timedelta(days=30)).isoformat(), token=owner, raw=True)
        ok("PDF " + report, status == 200 and pdf.startswith(b"%PDF"))
        (OUT / (report + ".pdf")).write_bytes(pdf)
    # Leave a genuine Stripe checkout appointment for the browser integration test.
    slots = get("/api/reservations/availability?serviceId=" + str(service["id"]) + "&date=" + day, token)["availableStartAtUtc"]
    status, card = call("POST", "/api/reservations", {"serviceId": service["id"], "startAtUtc": slots[0], "paymentMethod": "Card"}, token=token)
    ok("Card reservation created", status == 200)
    status, checkout = call("POST", "/api/payments/reservation/" + card["id"] + "/checkout", {"mobile": False}, token=token)
    ok("Real Stripe sandbox Checkout created", status == 200 and checkout["url"].startswith("https://checkout.stripe.com/"))
    again = call("POST", "/api/payments/reservation/" + card["id"] + "/checkout", {"mobile": False}, token=token)
    ok("Open checkout is reused", again[0] == 200 and again[1]["url"] == checkout["url"])
    (OUT / "payment-context.json").write_text(json.dumps({"token": token, "otherToken": other, "adminToken": admin, "reservation": card, "checkout": checkout, "username": one, "marker": marker}), encoding="utf-8")
    ok("Logout invalidates token", call("POST", "/api/auth/logout", token=other)[0] == 204 and call("GET", "/api/profile", token=other)[0] == 401)
    (OUT / "api-checks.json").write_text(json.dumps({"passed": passed, "count": len(passed)}, indent=2), encoding="utf-8")
    print("Completed", len(passed), "checks. Payment context saved privately for the Stripe test.", flush=True)

if __name__ == "__main__":
    try:
        run()
    except Exception as error:
        (OUT / "api-checks.json").write_text(json.dumps({"passed": passed, "count": len(passed), "failure": str(error)}, indent=2), encoding="utf-8")
        raise
