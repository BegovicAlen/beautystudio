# BeautyStudio

BeautyStudio je Flutter aplikacija za Android i Windows, s ASP.NET Core API-jem, SQL Server bazom, RabbitMQ brokerom i odvojenim workerom za obavijesti u aplikaciji.

## Local backend stack

1. Copy `backend/.env.example` to `backend/.env`.
2. Replace every example password and `JWT_KEY`.
3. Start Docker Desktop, then run this command from the `backend` folder:

```powershell
docker compose up --build
```

The API starts at `http://localhost:5000`; its health endpoint is `http://localhost:5000/health`. Startup applies the EF Core migrations and seeds the service catalogue and test users.

Compose pokreće četiri servisa: `api`, `worker`, `rabbitmq`, `sqlserver`. Baza, RabbitMQ i upload slike koriste trajne Docker volumene. `SEED_DEMO_DATA=true` priprema demonstracijske korisnike i, u praznoj bazi rezervacija, termine, recenzije i naplate na mjestu. Postojeći korisnički podaci se čuvaju. Demo računi služe za lokalni pregled rada.

## Seeded accounts

| Username | Password | Role |
| --- | --- | --- |
| `desktop` | `test` | Owner |
| `mobile` | `test` | Client |
| `admin` | `test` | Admin |

The login endpoint accepts either username or email: `POST /api/auth/login` with `usernameOrEmail` and `password`.

## Flutter connection

After the backend health endpoint works, run Flutter with the environment-specific API address:

```powershell
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000

# Windows desktop
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

Do not commit `backend/.env`; it is intentionally ignored. The committed `.env.example` files are the configuration templates.

## Funkcionalnosti i uloge

- Gost: početna, katalog i kategorije, galerija s pretragom i filterom, blog, salon, kontakt forma i FAQ, uz pristup prijavi i registraciji. Pristup je usklađen s originalnom prijavom teme.
- Klijent: rezervacija, otkazivanje uz razlog, Stripe kartica ili plaćanje na mjestu, historija, recenzije obavljenih tretmana, profil i obavijesti.
- Vlasnik: dashboard, termini, historija klijenata, naplate, sadržaj i tri PDF izvještaja za preuzimanje i štampu.
- Administrator: dodatno korisnici i uloge, referentni gradovi, nazivi statusa i tipovi obavijesti, postavke salona i slanje obavijesti.

Radno vrijeme i avans podešavaju se u postavkama salona. Cijena, valuta i procenat avansa snimaju se uz rezervaciju. Server provjerava radno vrijeme, trajanje i preklapanje u transakciji; konkurentni zahtjevi ne mogu rezervisati isti termin. Završavanje je dozvoljeno tek nakon kraja tretmana i evidentira naplatu na mjestu/preostali iznos. Nova imena statusa vezana su za četiri poslovna stanja; poslovna pravila ostaju definisana na serveru.

## Obavijesti

Promjena rezervacije/plaćanja upisuje `NotificationOutbox` u istu bazu. API objavljuje poruku uz potvrdu brokera. Odvojeni worker upisuje stvarnu obavijest, koristi ID događaja protiv duplikata i preusmjerava trajno neuspjele poruke u `.dead` red nakon ponovnih pokušaja. Aplikacija automatski osvježava obavijesti i omogućava označavanje pročitanih. Klik na obavijest otvara puni tekst u dijalogu, uključujući već pročitane poruke. Zatvaranje dijaloga označava nepročitanu poruku pročitanom. Dugme „Označi sve kao pročitano“ obuhvata sve poruke trenutnog korisnika, nezavisno od filtera, i osvježava listu i brojač. Profil omogućava isključivanje obavijesti. Email servis se ne koristi, prema odabranoj funkcionalnosti obavijesti u aplikaciji.

## Lozinka i sesija

Registracija izdaje jednokratni kod za oporavak koji korisnik treba sačuvati. Kod važi godinu dana. Ekran za zaboravljenu lozinku traži korisničko ime/email, kod i novu lozinku. Uspješan reset poništava kod i stare JWT sesije te izdaje novi kod. Novi kod se može dobiti i iz prijavljenog profila. Odjava poništava JWT na serveru; odgovor 401 vraća aplikaciju na prijavu. Lozinke koriste bcrypt.

Pregled objavljenog sadržaja i aktivnih referentnih lista dostupan je gostima. Rezervacije, profil, historija plaćanja, personalizovane preporuke, obavijesti i administracija zahtijevaju važeći JWT i odgovarajuću ulogu. Kontakt forma dostupna je i gostima, uz validaciju i ograničenje pet slanja u minuti po IP adresi. Odjava ili istek sesije vraćaju korisnika na gostujući pregled. Health, Stripe povrat i potpisani webhook ostaju tehnički javne rute.

Galerija podržava zaseban opis slike do 3000 znakova, uređivanje naslova/opisa/kategorije i deaktivaciju. Opis se prikazuje u detalju slike i ulazi u pretragu. Migracija `GalleryDescriptions` dodaje polje postojećoj bazi bez brisanja slika; postojeći opisi su početno prazni i mogu se unijeti kroz panel sadržaja.

## Stripe sandbox

U `backend/.env` postaviti `STRIPE_SECRET_KEY=sk_test_...` i `STRIPE_WEBHOOK_SECRET=whsec_...`. Živi ključevi se odbijaju. Podaci kartice unose se na Stripe Checkout stranici; API ih ne prima. Za demonstraciju koristiti test karticu `4242 4242 4242 4242`, budući datum isteka i bilo koji trocifreni CVC. Ponovljeni zahtjev vraća postojeći otvoreni Checkout. Plaćanje se potvrđuje serverom kod Stripea i može automatski potvrditi rezervaciju. Otkazivanje plaćene rezervacije traži stvarni Stripe test refund.

Za lokalnu dostavu stvarnih webhook događaja koristiti Stripe CLI: `stripe listen --forward-to localhost:5000/api/stripe/webhook`, postaviti njegov signing secret u `.env` i ponovo pokrenuti API. Provjeriti putanju u `StripeWebhookController` ako se konfiguracija mijenja. Povrat iz Checkouta otvara `beautystudio://payment-return`; aplikacija tada ponovo provjerava status na serveru. Ručno osvježavanje je također dostupno. Kod fizičkog telefona treba izgraditi aplikaciju s LAN adresom računara i postaviti odgovarajući `PAYMENT_MOBILE_RETURN_BASE_URL`.

## Izgradnja i provjera

```powershell
flutter pub get
flutter analyze --no-pub
flutter test
dotnet build backend/BeautyStudio.sln
python -X utf8 test/fresh_install_test.py --demo
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5000
flutter build windows --release --dart-define=API_BASE_URL=http://localhost:5000
```

Za provjeru nove instalacije može se pokrenuti `python -X utf8 test/fresh_install_test.py --demo`. Skripta koristi privremenu bazu i red na portu 5001.

APK izlaz je `build/app/outputs/flutter-apk/app-release.apk`. Windows zahtijeva cijeli `build/windows/x64/runner/Release` folder, uključujući DLL-ove i `data`, a ne samo EXE. APK koristi razvojni potpis za lokalnu seminarsku demonstraciju.

## Predaja

Dokumentacija algoritma: `recommender-dokumentacija.md`. Build ZIP u `output` sadrži APK i puni Windows folder. Tajni `.env` nije dio build ZIP-a; lokalna AES arhiva `backend/.env-tajne.zip` priprema se odvojeno, a nasumična šifra se čuva lokalno u `tmp/audit/env-archive-password.txt` i dostavlja nastavniku kroz predviđeni kanal. Ne postavljati tu šifru zajedno s arhivom.

Za konačnu predaju treba odabrati javni GitHub repozitorij, uključiti immutable releases, postaviti provjereni ZIP u draft release, objaviti ga i dostaviti tačan tag link na DLWMS.

Za ponovljivo pakovanje build fajlova pokrenuti `./scripts/prepare-release.ps1 -ReleaseDate YYYY-MM-DD`. Nova demo instalacija priprema račune iz tabele iznad i primjere sadržaja potrebne za pregled funkcionalnosti.
