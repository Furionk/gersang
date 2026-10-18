"""Author four short comic TTS cues and original transient SFX; no runtime network."""
import json, math, random, struct, wave, hashlib, subprocess
from pathlib import Path
import unit_voice_assets as pipeline

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'features/rainbow/audio'
RAW = ROOT / 'artifacts/rainbow-polish/audio-source'

def main():
    OUT.mkdir(parents=True, exist_ok=True); RAW.mkdir(parents=True, exist_ok=True)
    data = json.loads(pipeline.MANIFEST.read_text(encoding='utf-8'))
    voice = next(u for u in data['units'] if u['unit_id'] == 'archer')
    records = []
    for name, text in [('cut', '切！'), ('cleave', '劈！'), ('bang', '砰！'), ('break', '破！')]:
        raw = RAW / (name + '.mp3'); target = OUT / ('voice_' + name + '.ogg')
        pending = RAW / (name + '.pending')
        if not raw.exists():
            if pending.exists(): raise RuntimeError('Uncertain prior request; inspect service history: ' + name)
            pending.write_text('request started; do not automatically repeat',encoding='utf-8')
            body, _ = pipeline.http('POST', 'text-to-speech/' + voice['voice']['voice_id'] + '?output_format=mp3_44100_128', {
                'text': '[shouts] ' + text, 'model_id': voice['model_id'], 'language_code': 'zh', 'voice_settings': voice['voice_settings']}, retries=0)
            raw.write_bytes(body); pending.unlink()
        if not target.exists(): pipeline.convert(raw, target, voice['postprocess'])
        records.append({'file':str(target.relative_to(ROOT)), 'text':text,'voice':voice['voice']['name'],'model':voice['model_id'],'sha256':pipeline.digest(target.read_bytes()), **pipeline.probe(target)})
    # Deterministic original whoosh, blade, heavy impact, projectile and guard layers.
    for kind in ['swing','cut','cleave','bang','break','guard']:
        rate=44100; duration=0.20 if kind=='swing' else 0.25
        rng=random.Random(kind); samples=[]; previous=0.0
        for i in range(int(rate*duration)):
            t=i/rate; n=rng.uniform(-1,1); high=n-previous; previous=n
            if kind=='swing': value=high*0.25*math.sin(math.pi*t/duration)**2
            else:
                decay=math.exp(-t*(28 if kind=='cut' else 19))
                base={'cut':750,'cleave':160,'bang':100,'break':65,'guard':1150}[kind]
                tone=math.sin(2*math.pi*base*t*(1-t*0.9))
                value=(high*0.24*math.exp(-t*45)+tone*0.45*decay)*min(1,t/0.0015)
            samples.append(struct.pack('<h',int(max(-0.95,min(0.95,value))*32767)))
        path=OUT/(kind+'.wav')
        with wave.open(str(path),'wb') as w:
            w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(b''.join(samples))
        records.append({'file':str(path.relative_to(ROOT)),'source':'original deterministic transient synthesis','sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT/'provenance.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Authored audio:',len(records),'clips; cached speech retained.',flush=True)

if __name__ == '__main__': main()
