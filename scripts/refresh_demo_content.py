"""Replace only generated audit fixtures with readable fictional salon data.
Keeps identifiers, account passwords, bookings and payment history intact.
Run explicitly with --apply; a SQL backup is taken before the transaction.
"""
import argparse,json,pathlib,re,subprocess,sys,time,uuid
root=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'test'))
import api_smoke_test as api
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apply',action='store_true')
args=parser.parse_args()
if not args.apply: parser.error('Use --apply to authorize fixture replacement')
def docker(*args):
    r=subprocess.run(['docker',*args],capture_output=True,text=True,encoding='utf-8',cwd=root/'backend')
    if r.returncode: raise RuntimeError('Docker operation failed: '+args[0])
    return r.stdout
admin=api.login('admin','test')
users=api.get('/api/admin/users?pageSize=100',admin)['items']
fixtures=sorted((u for u in users if re.fullmatch(r'audit_[0-9a-f]{10}_(one|two)',u['username'])),key=lambda u:u['id'])
people=[('Petra','Perić','petra.peric'),('Zala','Zalać','zala.zalac'),('Lejla','Hadžić','lejla.hadzic'),('Ana','Kovač','ana.kovac'),('Nina','Jurić','nina.juric'),('Ema','Bašić','ema.basic'),('Sara','Babić','sara.babic'),('Mia','Tomić','mia.tomic')]
used={u['username'] for u in users}
def literal(s): return "N'"+s.replace("'","''")+"'"
statements=['SET XACT_ABORT ON; BEGIN TRANSACTION;']
for i,u in enumerate(fixtures):
    first,last,base=people[i%len(people)]
    username=base;number=2
    while username in used: username=base+'.'+str(number);number+=1
    used.add(username)
    statements.append("UPDATE Users SET FirstName="+literal(first)+",LastName="+literal(last)+",Username="+literal(username)+",Email="+literal(username+'@example.com')+",ProfileImageUrl=NULL,TokenVersion=TokenVersion+1 WHERE Id="+literal(u['id'])+" AND Username="+literal(u['username'])+";")
for username,old_first,old_last,first,last in [('mobile','Mobilni','Klijent','Lea','Marić'),('desktop','Desktop','Vlasnik','Ivana','Kovač'),('admin','Administrator','BeautyStudio','Martina','Horvat')]:
    statements.append('UPDATE Users SET FirstName='+literal(first)+',LastName='+literal(last)+' WHERE Username='+literal(username)+' AND FirstName='+literal(old_first)+' AND LastName='+literal(old_last)+';')
for kind,path,names in [('Cities','cities',['Tuzla','Zenica','Bihać','Travnik','Konjic']),('ReservationStatuses','statuses',['Termin potvrđen','Dolazak potvrđen','Rezervacija potvrđena']),('NotificationTypes','notification-types',['Podsjetnik za termin','Savjeti za njegu','Novosti salona'])]:
    rows=api.get('/api/admin/reference/'+path+'?pageSize=100',admin)['items']
    rows=sorted((r for r in rows if re.fullmatch(r'audit-[0-9a-f]{10}',r['name'])),key=lambda r:r['id'])
    for i,r in enumerate(rows):
        name=names[i%len(names)]
        if i>=len(names): name+=' '+str(i+1)
        code=(',Code='+literal(['AppointmentReminder','CareTips','StudioNews'][i%3])) if kind=='NotificationTypes' else ''
        statements.append('UPDATE '+kind+' SET Name='+literal(name)+code+' WHERE Id='+str(r['id'])+' AND Name='+literal(r['name'])+';')
categories=api.get('/api/admin/categories?pageSize=100',admin)['items']
old_category=next((c for c in categories if c['name']=='Make upiuhuikh'),None)
if old_category:
    duplicate=next((c for c in categories if c['name']=='Makeup'),None)
    target=str(old_category['id'])
    statements.append('IF EXISTS (SELECT 1 FROM ServiceCategories WHERE Id='+target+" AND Name=N'Make upiuhuikh') BEGIN")
    if duplicate:
        previous=str(duplicate['id'])
        for table in ['Services','GalleryItems','BlogPosts','UserActivities']:
            statements.append('UPDATE '+table+' SET CategoryId='+target+' WHERE CategoryId='+previous+';')
        statements.append('DELETE FROM ServiceCategories WHERE Id='+previous+" AND Name=N'Makeup';")
    statements.append("UPDATE ServiceCategories SET Name=N'Makeup' WHERE Id="+target+"; END;")
gallery=api.get('/api/admin/content/gallery?pageSize=100',admin)['items']
for i,r in enumerate(sorted((r for r in gallery if re.fullmatch(r'audit-[0-9a-f]{10}',r['title'])),key=lambda r:r['id'])):
    title=['Manikura u nježnim tonovima','Elegantni nokti za posebne prilike','Sjajna završnica gel manikure'][i%3]
    statements.append('UPDATE GalleryItems SET Title='+literal(title)+",CategoryId=(SELECT TOP(1) Id FROM ServiceCategories WHERE Name=N'Nokti') WHERE Id="+literal(r['id'])+' AND Title='+literal(r['title'])+';')
articles=[('Kako odabrati manikuru za posebnu priliku','Prilikom izbora manikure razmislite o bojama koje najčešće nosite i stilu događaja. Nježni tonovi lako se uklapaju u svakodnevne kombinacije, dok sjajne završnice i dekoracije mogu naglasiti svečani izgled. U ponudi salona pogledajte opis, cijenu i trajanje tretmana. Ako želite poseban dizajn, spomenite ga pri dolasku kako biste zajedno s osobljem odabrali izgled koji vam odgovara.'),('Termin koji se uklapa u vaš dan','Planiranje posjete salonu lakše je kada unaprijed provjerite trajanje odabrane usluge. U aplikaciji možete pregledati ponudu, izabrati datum i dostupno vrijeme, a zatim pratiti status rezervacije. Ostavite dovoljno vremena za dolazak i završetak tretmana. Ako se vaši planovi promijene, otkažite termin uz kratko objašnjenje i po potrebi napravite novu rezervaciju.'),('Od rezervacije do dolaska u salon','Nakon odabira tretmana i slobodnog vremena rezervacija se pojavljuje u vašim terminima. Potvrdu i promjene statusa pratite kroz obavijesti u aplikaciji. Kod kartičnog plaćanja pregledajte iznos na Stripe stranici prije potvrde, a za plaćanje u salonu naplata se evidentira po završetku tretmana. Sve važne informacije o rezervaciji, plaćanju i promjenama ostaju sačuvane za kasniji pregled.')]
blogs=api.get('/api/admin/content/blog-posts?pageSize=100',admin)['items']
for i,r in enumerate(sorted((r for r in blogs if re.fullmatch(r'audit-[0-9a-f]{10}',r['title'])),key=lambda r:r['id'])):
    title,body=articles[i%3]
    statements.append('UPDATE BlogPosts SET Title='+literal(title)+',Content='+literal(body)+" WHERE Id="+literal(r['id'])+' AND Title='+literal(r['title'])+';')
statements.extend([
 "UPDATE c SET FullName=u.FirstName+N' '+u.LastName,Email=u.Email,Message=N'Pozdrav, željela bih rezervisati termin u poslijepodnevnim satima. Možete li mi pomoći pri izboru odgovarajuće usluge?' FROM ContactMessages c JOIN Users u ON c.UserId=u.Id WHERE c.FullName=N'Audit Client' OR c.Message LIKE N'audit-%';",
 "UPDATE Reservations SET CancellationReason=N'Termin otkazan zbog promjene privatnih obaveza.' WHERE CancellationReason LIKE N'%audit%' OR CancellationReason=N'Stripe sandbox integration refund';",
 "UPDATE ReservationStatusHistories SET Reason=CASE ToStatus WHEN 'Cancelled' THEN N'Termin otkazan na zahtjev klijentice.' WHEN 'Confirmed' THEN N'Termin potvrđen nakon dogovora s klijenticom.' ELSE N'Promjena termina evidentirana u salonu.' END WHERE Reason LIKE N'%audit%' OR Reason=N'Stripe sandbox integration refund';",
])
for table in ['Notifications','NotificationOutbox']:
    statements.append("UPDATE "+table+" SET Title=N'Novosti salona',Message=N'Hvala što ste odabrali BeautyStudio. Pregledajte ponudu usluga i rezervišite termin koji odgovara vašim planovima.' WHERE Title LIKE N'audit-%' OR Title=N'Preference audit';")
    statements.append("UPDATE "+table+" SET Message=REPLACE(Message,N'Audit Client',N'Klijentica') WHERE Message LIKE N'%Audit Client%';")
    for marker in sorted({'audit-'+u['username'].split('_')[1] for u in fixtures}):
        statements.append('UPDATE '+table+' SET Message=REPLACE(Message,'+literal(marker)+",N'Promjena termina na zahtjev klijentice') WHERE Message LIKE "+literal('%'+marker+'%')+';')
statements.append('COMMIT TRANSACTION;')
env=(root/'backend/.env').read_text(encoding='utf-8-sig')
database=re.search(r'(?im)^CONNECTION_STRING=.*?Database=([^;\r\n]+)',env)[1]
assert re.fullmatch(r'[A-Za-z0-9_]+',database)
backup='beautystudio-before-content-2026-10-12-'+uuid.uuid4().hex[:8]+'.bak'
file=root/'tmp/audit/refresh-demo-content.sql';file.write_text('\n'.join(statements),encoding='utf-8')
docker('compose','stop','api','worker')
try:
    docker('exec','backend-sqlserver-1','mkdir','-p','/var/opt/mssql/backup')
    backup_query="BACKUP DATABASE ["+database+"] TO DISK=N'/var/opt/mssql/backup/"+backup+"' WITH COPY_ONLY, INIT;"
    backup_sql=root/'tmp/audit/content-backup.sql';backup_sql.write_text(backup_query,encoding='utf-8')
    docker('cp',str(backup_sql),'backend-sqlserver-1:/tmp/content-backup.sql')
    command='/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -b -d '+database+' -i '
    docker('exec','backend-sqlserver-1','/bin/sh','-c',command+'/tmp/content-backup.sql -f 65001')
    docker('cp',str(file),'backend-sqlserver-1:/tmp/refresh-demo-content.sql')
    docker('exec','backend-sqlserver-1','/bin/sh','-c',command+'/tmp/refresh-demo-content.sql -f 65001')
finally:
    docker('compose','start','api','worker')
print(json.dumps({'fictionalClients':len(fixtures),'backup':backup,'preserved':'IDs, passwords, reservations, payments, history'},ensure_ascii=False))
