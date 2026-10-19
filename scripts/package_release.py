from pathlib import Path
import sys, secrets, os, zipfile, hashlib, json
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tmp/python-deps'))
import pyzipper

root=Path(__file__).resolve().parents[1]; os.chdir(root)
import argparse
parser=argparse.ArgumentParser(description='Package locally built BeautyStudio releases and private AES configuration.')
parser.add_argument('--date', default='2026-10-12')
args=parser.parse_args()
import re
if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',args.date): parser.error('Date must use YYYY-MM-DD')
out=root/'output'; out.mkdir(exist_ok=True)
audit=root/'tmp/audit'; audit.mkdir(exist_ok=True)
archive=root/'backend/.env-tajne.zip'; password_file=audit/'env-archive-password.txt'
password=password_file.read_text(encoding='utf-8').strip() if password_file.exists() else secrets.token_urlsafe(32)
with pyzipper.AESZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,encryption=pyzipper.WZ_AES) as z:
    z.setpassword(password.encode()); z.setencryption(pyzipper.WZ_AES,nbits=256)
    z.write(root/'backend/.env','.env')
password_file.write_text(password+'\n',encoding='utf-8')
with pyzipper.AESZipFile(archive) as z:
    z.setpassword(password.encode()); assert z.read('.env')==(root/'backend/.env').read_bytes()
print('AES configuration archive created and verified; password stored privately.')

apk=root/'build/app/outputs/flutter-apk/app-release.apk'
windows=root/'build/windows/x64/runner/Release'
assert apk.exists() and (windows/'beautystudio_aplikacija.exe').exists()
latest_source=max(f.stat().st_mtime for f in (root/'lib').rglob('*.dart'))
assert (windows/'data/app.so').stat().st_mtime >= latest_source, 'Rebuild Windows after source changes'
assert apk.stat().st_mtime >= latest_source, 'Rebuild APK after source changes'
with zipfile.ZipFile(apk) as z:
    assert z.testzip() is None
    assert b'http://10.0.2.2:5000' in z.read('lib/arm64-v8a/libapp.so')
assert b'http://localhost:5000' in (windows/'data/app.so').read_bytes()
build_zip=out/f'fit-build-{args.date}.zip'
with zipfile.ZipFile(build_zip,'w',zipfile.ZIP_DEFLATED) as z:
    z.write(apk,'beautystudio_aplikacija/build/app/outputs/flutter-apk/app-release.apk')
    for f in windows.rglob('*'):
        if f.is_file(): z.write(f,'beautystudio_aplikacija/build/windows/x64/runner/Release/'+f.relative_to(windows).as_posix())
with zipfile.ZipFile(build_zip) as z:
    assert z.testzip() is None
    assert not any('.env' in n for n in z.namelist())
    assert any(n.endswith('flutter_windows.dll') for n in z.namelist())

excluded={'.git','.dart_tool','.gradle','build','docs','tmp','output','bin','obj','node_modules','ephemeral','.idea','.vs','private-uploads','uploads','Beauty Studio Prototype App','__pycache__'}
source_zip=out/f'beautystudio-source-{args.date}.zip'
with zipfile.ZipFile(source_zip,'w',zipfile.ZIP_DEFLATED) as z:
    for directory, subdirectories, files in os.walk(root):
        subdirectories[:]=[d for d in subdirectories if d not in excluded]
        for name in files:
            f=Path(directory)/name; rel=f.relative_to(root)
            if rel.parent == Path('.') and f.suffix.lower() in {'.pdf','.docx'}: continue
            if f.name in {'.env','.env-tajne.zip','.flutter-plugins-dependencies','local.properties'} or f.name.startswith('flutter_') or f.suffix in {'.iml','.user','.pyc'}: continue
            z.write(f,rel.as_posix())
    z.write(archive,'backend/.env-tajne.zip')
with zipfile.ZipFile(source_zip) as z:
    assert z.testzip() is None
    assert not any(n.endswith('.env') or 'payment-context' in n or 'env-archive-password' in n for n in z.namelist())
    assert 'backend/.env-tajne.zip' in z.namelist()

checks={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [build_zip,source_zip,apk]}
(out/'SHA256SUMS.txt').write_text('\n'.join(f'{digest}  {name}' for name,digest in checks.items())+'\n',encoding='utf-8')
print(json.dumps({'buildArchive':build_zip.name,'sourceArchive':source_zip.name,'apkBytes':apk.stat().st_size,'windowsFiles':sum(f.is_file() for f in windows.rglob('*')),'checksumsVerified':True},indent=2))

private_values=[]
for line in (root/'backend/.env').read_text(encoding='utf-8-sig').splitlines():
    if '=' in line:
        key,value=line.split('=',1)
        if key in {'STRIPE_SECRET_KEY','STRIPE_WEBHOOK_SECRET','JWT_KEY','JWT_SECRET'} and len(value.strip())>8:
            private_values.append(value.strip().strip('"').encode())
for archive_path in (build_zip,source_zip):
    with zipfile.ZipFile(archive_path) as z:
        for name in z.namelist():
            data=z.read(name)
            assert not any(secret in data for secret in private_values), 'Private value detected in release archive'
print('Public archives verified: no configured Stripe/JWT secrets.')
