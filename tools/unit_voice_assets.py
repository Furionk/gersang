"""Offline ElevenLabs asset pipeline. No keys in Godot, manifests or reports.

python tools/unit_voice_assets.py preview
python tools/unit_voice_assets.py generate --scope pilot
python tools/unit_voice_assets.py resume --scope pilot
python tools/unit_voice_assets.py validate --scope pilot --require-complete
Full generation requires manifest full_generation_approved=true after human listening review.
"""
import argparse
import hashlib
import html
import json
import os
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT/'features/audio/data/unit_voices.json'
STATE = ROOT/'artifacts/unit-voices/generation-state.json'
API = 'https://api.elevenlabs.io/v1/'
PIPELINE_VERSION = 1

class StopGeneration(Exception): pass
class UncertainGeneration(Exception): pass
class ClipFailure(Exception): pass

def digest(data): return hashlib.sha256(data).hexdigest()
def speech_text(unit, line):
 event=line['id'].rsplit('_',1)[0]
 delivery=unit.get('delivery_tags',{}).get(event,'')
 return (delivery+' '+line['text']).strip()

def fingerprint(unit, line):
 return digest(json.dumps({'pipeline':PIPELINE_VERSION,'text':speech_text(unit,line),'language':unit['language'],'voice_id':unit['voice']['voice_id'],'model':unit['model_id'],'settings':unit['voice_settings'],'conversion':unit['postprocess'],'output_format':'mp3_44100_128'},sort_keys=True,ensure_ascii=False).encode())

def local_path(path):
 if not path.startswith('res://art/voices/') or '..' in Path(path).parts: raise ValueError('Invalid asset path')
 result=(ROOT/path.removeprefix('res://')).resolve()
 if not result.is_relative_to((ROOT/'art/voices').resolve()): raise ValueError('Asset outside voices')
 return result

def entries(manifest, scope):
 for unit in manifest['units']:
  for event,lines in unit['events'].items():
   for line in lines:
    if scope=='all' or line['pilot']: yield unit,event,line

def check_manifest(manifest):
 ids=set(); paths=set()
 for unit in manifest['units']:
  uid=unit['unit_id']
  if uid in ids or not uid.replace('_','').isalnum(): raise ValueError('Duplicate/invalid unit ID')
  ids.add(uid)
  if unit['language'] and unit['voice'].get('native_language')!=unit['language']: raise ValueError('Voice language mismatch: '+uid)
  if unit['language'] and not unit['voice']['voice_id']: raise ValueError('Missing voice ID: '+uid)
  for event,lines in unit['events'].items():
   expected=unit.get('variation_counts',{}).get(event,3)
   if expected not in (2,3) or len(lines)!=expected or len({l['text'] for l in lines})!=expected: raise ValueError('Unexpected variation count: '+uid+'/'+event)
   for index,line in enumerate(lines,1):
    if line['id'] != f'{event}_{index:02}' or line['path'] != f'res://art/voices/{uid}/{line["id"]}.ogg': raise ValueError('Inconsistent clip identity/path')
    local_path(line['path'])
    if line['path'] in paths: raise ValueError('Duplicate audio path')
    paths.add(line['path'])
 return len(ids),len(paths)

def atomic_json(path, data):
 path.parent.mkdir(parents=True,exist_ok=True)
 tmp=path.with_suffix('.tmp'); tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 # Windows sync/import scanners can briefly hold the destination without delete sharing.
 # Retry the local atomic commit only, never the paid synthesis request.
 for attempt in range(10):
  try: tmp.replace(path); return
  except PermissionError:
   if attempt == 9: raise
   time.sleep(min(0.05 * 2**attempt, 0.8))

def load_state(): return json.loads(STATE.read_text(encoding='utf-8')) if STATE.exists() else {'schema':1,'clips':{}}

def http(method, endpoint, payload=None, retries=3):
 key=os.environ.get('ELEVENLABS_API_KEY','')
 if not key: raise StopGeneration('ELEVENLABS_API_KEY unavailable')
 for attempt in range(retries+1):
  request=urllib.request.Request(API+endpoint,data=json.dumps(payload,ensure_ascii=False).encode() if payload is not None else None,headers={'xi-api-key':key,'Content-Type':'application/json'},method=method)
  try:
   with urllib.request.urlopen(request,timeout=120) as response: return response.read(),dict(response.headers)
  except urllib.error.HTTPError as error:
   # Keep only service status/code, never headers, requests or credential-bearing tracebacks.
   try:
    detail=json.loads(error.read()).get('detail',{})
    code=detail.get('status','') if isinstance(detail,dict) else ''
   except (ValueError,AttributeError): code=''
   if error.code in (401,403) or code in ('quota_exceeded','insufficient_credits','missing_permissions'):
    raise StopGeneration(f'HTTP {error.code}: {code or "authentication/permission"}') from None
   if error.code==429 or 500<=error.code<600:
    if attempt==retries: raise StopGeneration(f'HTTP {error.code}: retry limit reached') from None
    try: delay=float(error.headers.get('Retry-After',''))
    except ValueError:
     from email.utils import parsedate_to_datetime
     try: delay=max(0,(parsedate_to_datetime(error.headers['Retry-After'])-datetime.now(timezone.utc)).total_seconds())
     except (ValueError,TypeError,KeyError): delay=2**attempt
    print(f'Retry HTTP {error.code} after {delay:.1f}s',flush=True)
    while delay>0:
     step=min(delay,30); time.sleep(step); delay-=step
    continue
   raise ClipFailure(f'HTTP {error.code}: {code or "request rejected"}') from None
  except (urllib.error.URLError,TimeoutError,OSError):
   if method=='POST': raise UncertainGeneration('Connection failed: generation outcome unknown; inspect ElevenLabs history before explicitly retrying.') from None
   raise StopGeneration('Read-only API connection failed') from None

def ensure_voice(unit):
 voice=unit['voice']; uid=voice['voice_id']
 # Public-library speech needs the voice in this workspace; adding the chosen licensed
 # library voice does not create a clone or change any existing voice.
 try: http('GET','voices/'+uid,retries=0)
 except ClipFailure as error:
  if 'HTTP 404' not in str(error) and 'voice_not_found' not in str(error): raise
  owner=voice.get('public_owner_id')
  if not owner: raise
  http('POST',f'voices/add/{owner}/{uid}',{'new_name':voice['name']})

def ffmpeg_path():
 candidate=shutil.which('ffmpeg') or 'C:/AdditionalApplication/ffmpeg/ffmpeg.exe'
 if not Path(candidate).exists(): raise StopGeneration('FFmpeg unavailable')
 return candidate

def probe(path):
 binary=Path(ffmpeg_path()).with_name('ffprobe.exe' if os.name=='nt' else 'ffprobe')
 result=subprocess.run([str(binary),'-v','error','-show_entries','format=duration:stream=channels,sample_rate','-of','json',str(path)],capture_output=True,text=True,check=True)
 data=json.loads(result.stdout)
 return {'duration':float(data['format']['duration']),'channels':data['streams'][0]['channels'],'sample_rate':int(data['streams'][0]['sample_rate'])}

def convert(raw, target, settings):
 target.parent.mkdir(parents=True,exist_ok=True); tmp=target.with_suffix('.partial.ogg')
 # Trim leading silence only; retain final consonants and the original raw source.
 pitch=settings['pitch_ratio']; rate=settings['sample_rate']
 filters='silenceremove=start_periods=1:start_duration=0.04:start_threshold=-50dB'
 if pitch != 1.0: filters+=f',asetrate={round(rate*pitch)},aresample={rate},atempo={1/pitch}'
 filters+=f',loudnorm=I={settings["loudness_lufs"]}:TP={settings["true_peak_db"]}:LRA=7'
 result=subprocess.run([ffmpeg_path(),'-hide_banner','-loglevel','error','-y','-i',str(raw),'-ar',str(rate),'-ac','1','-af',filters,'-c:a','libvorbis','-q:a',str(settings['vorbis_quality']),str(tmp)],capture_output=True,text=True)
 if result.returncode: raise ClipFailure('FFmpeg conversion failed')
 info=probe(tmp)
 if not 0.35<=info['duration']<=8 or info['channels']!=1: raise ClipFailure('Audio quality bounds failed')
 tmp.replace(target)
 info['duration_review_required']=not 1<=info['duration']<=3
 return info

def current(record, target, key):
 return record.get('fingerprint')==key and record.get('status')=='generated' and target.exists() and digest(target.read_bytes())==record.get('sha256')

def generate(manifest, scope, retry_uncertain=False):
 if scope=='all' and not manifest.get('full_generation_approved'): raise StopGeneration('Full generation waits for pilot listening approval; manifest full_generation_approved is false.')
 ffmpeg_path(); state=load_state(); voices=set(); done=0
 for unit,event,line in entries(manifest,scope):
  uid=unit['unit_id']; clip=f'{uid}/{line["id"]}'; target=local_path(line['path']); key=fingerprint(unit,line); record=state['clips'].get(clip,{})
  if current(record,target,key): print('CACHED '+clip,flush=True); done+=1; continue
  if record.get('status')=='uncertain' and record.get('fingerprint')==key and not retry_uncertain:
   print('SKIP UNCERTAIN '+clip,flush=True); continue
  raw=ROOT/'artifacts/unit-voices/raw'/uid/(line['id']+'-'+key[:16]+'.mp3')
  try:
   if raw.exists() and record.get('raw_sha256') and digest(raw.read_bytes()) != record['raw_sha256']:
    raise ClipFailure('Raw source checksum mismatch; original retained for investigation')
   if not raw.exists():
    if unit['language']:
     if unit['voice']['voice_id'] not in voices: ensure_voice(unit); voices.add(unit['voice']['voice_id'])
     endpoint='text-to-speech/'+unit['voice']['voice_id']+'?output_format=mp3_44100_128'
     payload={'text':speech_text(unit,line),'model_id':unit['model_id'],'language_code':unit['language'],'voice_settings':unit['voice_settings']}
    else:
     endpoint='sound-generation?output_format=mp3_44100_128'; payload={'text':line['text'],'model_id':unit['model_id'],**unit['voice_settings']}
    print('GENERATING '+clip,flush=True)
    state['clips'][clip]={'fingerprint':key,'status':'uncertain','reason':'Request starting; interruption must not cause an automatic duplicate charge.'}; atomic_json(STATE,state)
    audio,headers=http('POST',endpoint,payload)
    if not audio: raise ClipFailure('Empty audio response')
    raw.parent.mkdir(parents=True,exist_ok=True); raw.write_bytes(audio)
    normalized_headers={k.lower():v for k,v in headers.items()}
    record={'request_id':next((normalized_headers[k] for k in ('request-id','x-request-id','xi-request-id') if k in normalized_headers),''),'raw_sha256':digest(audio),'fingerprint':key,'raw_path':raw.relative_to(ROOT).as_posix(),'status':'raw_ready'}
    state['clips'][clip]=record; atomic_json(STATE,state)
   info=convert(raw,target,unit['postprocess'])
   state['clips'][clip]={**record,'fingerprint':key,'status':'generated','path':line['path'],'raw_path':raw.relative_to(ROOT).as_posix(),'sha256':digest(target.read_bytes()),'voice_id':unit['voice']['voice_id'],'voice_source':unit['voice']['source'],'model_id':unit['model_id'],'generation_text':speech_text(unit,line) if unit['language'] else line['text'],'performance_direction':unit.get('performance_direction',''),'voice_settings':unit['voice_settings'],'postprocess':unit['postprocess'],'generated_at':datetime.now(timezone.utc).isoformat(),**info}
   atomic_json(STATE,state); done+=1; print(f'DONE {clip} {info["duration"]:.2f}s',flush=True)
  except UncertainGeneration as error:
   state['clips'][clip]={'fingerprint':key,'status':'uncertain','reason':str(error)}; atomic_json(STATE,state); print('UNCERTAIN '+clip,flush=True)
  except StopGeneration as error:
   state['clips'][clip]={**record,'fingerprint':key,'status':'failed','reason':str(error),'raw_path':raw.relative_to(ROOT).as_posix() if raw.exists() else ''}; atomic_json(STATE,state)
   raise
  except ClipFailure as error:
   state['clips'][clip]={**record,'fingerprint':key,'status':'failed','reason':str(error),'raw_path':raw.relative_to(ROOT).as_posix() if raw.exists() else ''}; atomic_json(STATE,state)
   print('FAILED '+clip+': '+str(error),flush=True)
  except subprocess.SubprocessError:
   state['clips'][clip]={'fingerprint':key,'status':'failed','reason':'Audio probe failed; raw source preserved'}; atomic_json(STATE,state)
 print(f'Generated/cached {done} clips.',flush=True)
 return done == sum(1 for _ in entries(manifest,scope))

def preview(manifest):
 state=load_state(); rows=[]; review=[]; ready=0
 for unit,event,line in entries(manifest,'all'):
  target=local_path(line['path']); record=state['clips'].get(unit['unit_id']+'/'+line['id'],{}); status=record.get('status','pending_review')
  playable=current(record,target,fingerprint(unit,line))
  if playable: ready+=1
  src=os.path.relpath(target,ROOT/'artifacts/unit-voices').replace('\\','/')
  if playable: src+='?v='+record['sha256'][:12]
  audio=f'<audio controls preload="none" src="{html.escape(src)}"></audio>' if playable else '<span class="pending">待生成</span>'
  esc=html.escape
  rows.append(f'<tr data-unit="{esc(unit["unit_id"])}" data-pilot="{str(line["pilot"]).lower()}"'+(' hidden' if not line['pilot'] else '')+f'><td>{esc(unit["name"])}<small>{esc(unit["language"] or unit["species"])}</small></td><td>{esc(line["id"])}'+(' ★試音' if line['pilot'] else '')+f'</td><td>{esc(line["text"])}<small>{esc(line["translation_zh"])}</small></td><td>{esc(unit["voice"]["name"])}<small>{esc(unit["personality"])}</small></td><td>{audio}<small>{esc(status)} · {record.get("duration",0):.2f}s</small></td></tr>')
  review.append({'unit_id':unit['unit_id'],'name':unit['name'],'language':unit['language'],'event':event,**line,'status':status,'duration':record.get('duration')})
 destination=ROOT/'artifacts/unit-voices'; destination.mkdir(parents=True,exist_ok=True)
 document='''<!doctype html><meta charset="utf-8"><title>巨雙2.0 兵種語音試音</title><style>body{font:16px system-ui;background:#171711;color:#eee4ce;margin:32px}h1{color:#e4c789}table{border-collapse:collapse;width:100%}td,th{padding:14px;text-align:left;border-bottom:1px solid #494334;vertical-align:top}small{display:block;color:#b9b19e;margin-top:8px}audio{width:260px}.pending{color:#c6a86d}button{padding:10px;background:#dfc893;border:0;cursor:pointer}</style><h1>巨雙2.0 · 兵種語音試音</h1><p>32種兵 · 237個槽位 · 11段首批試音。先確認聲線、口音、個性及句尾完整度，再全量生成。</p><button onclick="for(const r of document.querySelectorAll('tr[data-pilot]'))r.hidden=(r.dataset.pilot!=='true')">只看11段試音</button> <button onclick="for(const r of document.querySelectorAll('tr'))r.hidden=false">查看全部台詞</button><table><thead><tr><th>兵種／語言</th><th>事件</th><th>台詞／中文意思</th><th>聲線／個性</th><th>播放／狀態</th></tr></thead><tbody>'''+''.join(rows)+'</tbody></table>'
 if manifest.get('review_note'):
  document=document.replace('<h1>巨雙2.0 · 兵種語音試音</h1>', '<h1>巨雙2.0 · 兵種語音試音</h1><p>'+html.escape(manifest['review_note'])+'</p>')
 document=document.replace('32種兵 · 237個槽位 · 11段首批試音。先確認聲線、口音、個性及句尾完整度，再全量生成。',f'{len(manifest["units"])}種兵 · {ready}/{len(review)}段音訊可播放。')
 options='<option value="">全部兵種</option>'+''.join('<option value="'+html.escape(u['unit_id'])+'">'+html.escape(u['name'])+'</option>' for u in manifest['units'])
 controls='''<script>let voiceMode="pilot";function filterVoices(mode){if(mode)voiceMode=mode;const unit=document.getElementById("unitFilter").value;for(const row of document.querySelectorAll("tr[data-pilot]"))row.hidden=(voiceMode==="pilot"&&row.dataset.pilot!=="true")||(unit&&row.dataset.unit!==unit);}</script>'''
 controls+='<label>兵種：<select id="unitFilter" onchange="filterVoices(\'all\')">'+options+'</select></label> '
 controls+='''<button onclick="document.getElementById('unitFilter').value='';filterVoices('pilot')">只看首批試音</button> <button onclick="document.getElementById('unitFilter').value='';filterVoices('all')">查看全部語音</button>'''
 start=document.index('<button onclick='); end=document.index('<table>',start)
 document=document[:start]+controls+document[end:]
 if ready == len(review): document+='<script>filterVoices("all")</script>'
 if (destination/'review/v1/index.html').exists():
  document=document.replace('<table>', '<p><a style="color:#e4c789" href="review/v1/index.html">第一版對比</a></p><table>',1)
 (destination/'preview.html').write_text(document,encoding='utf-8')
 atomic_json(destination/'dialogue-review.json',review)
 print(str(destination/'preview.html'))

def validate(manifest,scope,require_complete=False):
 state=load_state(); missing=[]; stale=[]; generated=0; warnings=[]
 for unit,event,line in entries(manifest,scope):
  target=local_path(line['path']); clip=unit['unit_id']+'/'+line['id']; record=state['clips'].get(clip,{})
  if not target.exists(): missing.append(clip); continue
  if not current(record,target,fingerprint(unit,line)): stale.append(clip); continue
  info=probe(target)
  if info['channels']!=1 or info['sample_rate']!=44100: stale.append(clip); continue
  generated+=1
  if not 1<=info['duration']<=3: warnings.append(clip)
 report={'scope':scope,'generated':generated,'passed':generated,'failed':len(stale)+(len(missing) if require_complete else 0),'missing':missing,'stale':stale,'duration_review':warnings,'human_listening':'unverified'}
 atomic_json(ROOT/'artifacts/unit-voices/asset-validation.json',report)
 print(json.dumps(report,ensure_ascii=False))
 return not stale and (not require_complete or not missing)

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('command',choices=['preview','generate','resume','validate'])
 parser.add_argument('--scope',choices=['pilot','all'],default='pilot')
 parser.add_argument('--require-complete',action='store_true')
 parser.add_argument('--retry-uncertain',action='store_true',help='Only after checking provider history to avoid duplicate charges')
 args=parser.parse_args()
 try:
  manifest=json.loads(MANIFEST.read_text(encoding='utf-8')); check_manifest(manifest)
  if args.command in ('generate','resume'):
   complete=generate(manifest,args.scope,args.retry_uncertain); preview(manifest)
   if not complete: return 1
  elif args.command=='preview': preview(manifest)
  elif not validate(manifest,args.scope,args.require_complete): return 1
 except (StopGeneration,UncertainGeneration,ValueError) as error:
  print(str(error)); return 1
 return 0

if __name__=='__main__': raise SystemExit(main())
