# Sistem preporuka BeautyStudio

## Pristup

Implementacija kombinuje preporuke po sadržaju (kategorija usluge/sadržaja), popularnost i ocjene. Ne koristi kolaborativno filtriranje niti trenirani model. Izračun se izvršava u API-ju iz podataka SQL Servera, za trenutno prijavljenog korisnika.

## Podaci i signali

`UserActivities` čuva stvarne preglede usluge, kategorije, galerije i bloga. Kategorija se određuje iz povezanog zapisa na serveru. Rezervacija dodaje signal `ServiceReserved` na serveru; klijent ga ne može sam poslati. Aktivnost je vezana za korisnika iz JWT-a.

Interes za kategoriju je zbir aktivnosti u zadnjih 90 dana: rezervacija nosi 5 bodova, pregled kategorije 2, ostali pregledi 1. Vrijednost se normalizuje najvećim korisnikovim interesom. Popularnost koristi broj neotkazanih rezervacija i pregleda usluge u posljednjih 30 dana. Recenzije se mogu dodati samo za vlastiti završeni tretman, jednom po rezervaciji.

## Rangiranje usluga

`P = 0.8 × normalizovani broj rezervacija + 0.2 × normalizovani broj pregleda`.

`R = prosječna ocjena / 5 × min(1, broj ocjena / 3)` smanjuje uticaj jedne ocjene.

Sa korisničkim signalima: `S = 0.60 × interes + 0.25 × P + 0.15 × R`.

Bez signala: `S = 0.70 × P + 0.30 × R`. Ako ni popularnost ni ocjene ne postoje, redoslijed je abecedni. Vraća se najviše pet aktivnih usluga iz aktivnih kategorija, uz objašnjenje preporuke.

## Kategorije i blog

Kategorije koriste 70% korisničkog interesa i 30% popularnosti rezervacija; vraćaju se tri kategorije. Blog koristi 60% interesa, 30% pregleda u zadnjih 30 dana i 10% svježine `1 / (1 + starost u danima)`. Već pročitani blogovi su izostavljeni, neobjavljeni sadržaj i neaktivne kategorije nisu kandidati. Vraćaju se tri članka.

## API i prikaz

- `POST /api/activities`: evidentiranje podržanih pregleda.
- `GET /api/recommendations`: preporučene usluge.
- `GET /api/recommendations/content`: kategorije i blogovi.
- Početna stranica osvježava preporuke nakon prijave; galerija, katalog i blog šalju signale pri stvarnom otvaranju sadržaja.

## Provjera i ograničenja

Integracijski test u `test/api_smoke_test.py` provjerava da pregled galerije nove kategorije promijeni preporuke usluga, te da lažni signal rezervacije bude odbijen. Rangiranje je determinističko; jednaki rezultati se razrješavaju nazivom. Brojanje pregleda može favorizovati često otvarani sadržaj; sistem nema kontrolisani eksperiment za mjerenje kvaliteta preporuka.
