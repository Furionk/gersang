"""Pipeline failure/cache tests; no network, credentials or generated asset mutation."""
import copy
import importlib.util
import io
import json
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('assets',Path(__file__).resolve().parents[1]/'tools/unit_voice_assets.py')
assets=importlib.util.module_from_spec(spec); spec.loader.exec_module(assets)
TEST_TEMP=Path(__file__).resolve().parents[1]/'artifacts/unit-voices/test-temp'
TEST_TEMP.mkdir(parents=True,exist_ok=True)

def temporary_folder():
 folder=tempfile.TemporaryDirectory(dir=TEST_TEMP)
 assert Path(folder.name).resolve().is_relative_to(TEST_TEMP.resolve())
 return folder

class PipelineTests(unittest.TestCase):
 def setUp(self):
  self.manifest=json.loads(assets.MANIFEST.read_text(encoding='utf-8'))
  self.unit=next(u for u in self.manifest['units'] if u['unit_id']=='merchant')
  self.line=self.unit['events']['select'][0]

 def test_inventory_and_scope(self):
  self.assertEqual(assets.check_manifest(self.manifest),(34,258))
  self.assertEqual(len(list(assets.entries(self.manifest,'pilot'))),11)

 def test_fingerprint_change_dependencies(self):
  key=assets.fingerprint(self.unit,self.line)
  for field in ('text',):
   line=copy.deepcopy(self.line); line[field]+=' changed'; self.assertNotEqual(assets.fingerprint(self.unit,line),key)
  for field in ('language','model_id'):
   unit=copy.deepcopy(self.unit); unit[field]+='changed'; self.assertNotEqual(assets.fingerprint(unit,self.line),key)
  for field,subfield in [('voice','voice_id'),('voice_settings','stability'),('postprocess','pitch_ratio')]:
   unit=copy.deepcopy(self.unit); unit[field][subfield]='changed'; self.assertNotEqual(assets.fingerprint(unit,self.line),key)

 def test_review_translation_does_not_regenerate(self):
  line=copy.deepcopy(self.line); line['translation_zh']='Review translation corrected'
  self.assertEqual(assets.fingerprint(self.unit,line),assets.fingerprint(self.unit,self.line))

 def test_ninja_exact_two_choice_categories(self):
  ninja=next(u for u in self.manifest['units'] if u['unit_id']=='ninja')
  self.assertEqual([l['text'] for l in ninja['events']['select']],['I smell magic in the air.','Be quick; time is mana.'])
  self.assertEqual([l['text'] for l in ninja['events']['move']],['Watch and learn','Very clever'])
  self.assertEqual(ninja['language'],'en'); self.assertEqual(ninja['gender'],'male')
  self.assertEqual([l['text'] for l in ninja['events']['inspect']],[l['text'] for l in ninja['events']['select']])
  self.assertEqual(assets.check_manifest(self.manifest),(34,258))

 def test_delivery_direction_changes_cache_and_request_text(self):
  unit=copy.deepcopy(self.unit); unit['delivery_tags']={'select':'[confident]'}
  self.assertEqual(assets.speech_text(unit,self.line),'[confident] '+self.line['text'])
  key=assets.fingerprint(unit,self.line)
  unit['delivery_tags']['select']='[excited]'
  self.assertNotEqual(assets.fingerprint(unit,self.line),key)
  self.assertNotIn('[',self.line['text'])

 def test_cache_checks_output_checksum(self):
  with temporary_folder() as folder:
   p=Path(folder)/'test.ogg'; p.write_bytes(b'original')
   record={'fingerprint':'key','status':'generated','sha256':assets.digest(p.read_bytes())}
   self.assertTrue(assets.current(record,p,'key'))
   self.assertFalse(assets.current(record,p,'changed'))
   p.write_bytes(b'corrupt'); self.assertFalse(assets.current(record,p,'key'))

 def test_full_generation_gate_precedes_side_effects(self):
  self.manifest['full_generation_approved']=False
  with patch.object(assets,'ffmpeg_path') as binary:
   with self.assertRaises(assets.StopGeneration): assets.generate(self.manifest,'all')
   binary.assert_not_called()

 def test_path_escape_rejected(self):
  for path in ['res://art/voices/../../outside.ogg','C:/secret','res://other/path.ogg']:
   with self.assertRaises(ValueError): assets.local_path(path)

 def test_raw_path_identity_rejected(self):
  self.manifest['units'][0]['events']['engage'][0]['id']='../../escape'
  with self.assertRaises(ValueError): assets.check_manifest(self.manifest)

 def test_timeout_uncertain_not_auto_retried(self):
  with patch.dict(assets.os.environ,{'ELEVENLABS_API_KEY':'test-only'}), patch.object(assets.urllib.request,'urlopen',side_effect=TimeoutError) as call:
   with self.assertRaises(assets.UncertainGeneration): assets.http('POST','test',{})
   self.assertEqual(call.call_count,1)

 def test_authentication_stops_without_secret_output(self):
  error=urllib.error.HTTPError('https://example.test',401,'failure',{},io.BytesIO(b'{"detail":{"status":"invalid_api_key","message":"never echo this secret"}}'))
  with patch.dict(assets.os.environ,{'ELEVENLABS_API_KEY':'test-only'}), patch.object(assets.urllib.request,'urlopen',side_effect=error):
   with self.assertRaises(assets.StopGeneration) as caught: assets.http('POST','test',{})
   self.assertNotIn('secret',str(caught.exception)); self.assertNotIn('test-only',str(caught.exception))

 def test_retry_after_then_success(self):
  error=urllib.error.HTTPError('https://example.test',429,'limit',{'Retry-After':'2'},io.BytesIO(b'{}'))
  response=unittest.mock.MagicMock(); response.__enter__.return_value.read.return_value=b'audio'; response.__enter__.return_value.headers={'Request-Id':'safe-id'}
  with patch.dict(assets.os.environ,{'ELEVENLABS_API_KEY':'test-only'}), patch.object(assets.urllib.request,'urlopen',side_effect=[error,response]) as call, patch.object(assets.time,'sleep') as sleep:
   audio,_=assets.http('POST','test',{}); self.assertEqual(audio,b'audio'); self.assertEqual(call.call_count,2); sleep.assert_called_once_with(2.0)

 def test_partial_failure_preserves_success_and_resume_uses_cache(self):
  manifest=copy.deepcopy(self.manifest); manifest['units']=[copy.deepcopy(self.unit)]; manifest['units'][0]['events']={'select':manifest['units'][0]['events']['select'][:2]}
  manifest['units'][0]['events']['select'][1]['pilot']=True
  with temporary_folder() as folder, patch.object(assets,'ROOT',Path(folder)), patch.object(assets,'STATE',Path(folder)/'state.json'), patch.object(assets,'ffmpeg_path',return_value='fake'), patch.object(assets,'ensure_voice'):
   def convert(raw,target,settings):
    target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(raw.read_bytes()); return {'duration':1.5,'channels':1,'sample_rate':44100}
   with patch.object(assets,'http',side_effect=[(b'first',{}),assets.ClipFailure('HTTP 422')]), patch.object(assets,'convert',side_effect=convert):
    self.assertFalse(assets.generate(manifest,'pilot'))
   state=assets.load_state(); self.assertEqual(state['clips']['merchant/select_01']['status'],'generated'); self.assertEqual(state['clips']['merchant/select_02']['status'],'failed')
   with patch.object(assets,'http',return_value=(b'second',{})) as call,patch.object(assets,'convert',side_effect=convert):
    self.assertTrue(assets.generate(manifest,'pilot')); self.assertEqual(call.call_count,1)
   with patch.object(assets,'http') as call:
    self.assertTrue(assets.generate(manifest,'pilot')); call.assert_not_called()

 def test_raw_conversion_retry_does_not_rebill(self):
  manifest=copy.deepcopy(self.manifest); manifest['units']=[copy.deepcopy(self.unit)]; manifest['units'][0]['events']={'select':[self.line]}
  with temporary_folder() as folder, patch.object(assets,'ROOT',Path(folder)), patch.object(assets,'STATE',Path(folder)/'state.json'), patch.object(assets,'ffmpeg_path',return_value='fake'), patch.object(assets,'ensure_voice'):
   with patch.object(assets,'http',return_value=(b'raw',{'Request-Id':'id'})), patch.object(assets,'convert',side_effect=assets.ClipFailure('conversion failed')):
    self.assertFalse(assets.generate(manifest,'pilot'))
   record=assets.load_state()['clips']['merchant/select_01']; self.assertEqual(record['request_id'],'id'); self.assertEqual(record['raw_sha256'],assets.digest(b'raw'))
   def convert(raw,target,settings):
    target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(b'ogg'); return {'duration':1.0}
   with patch.object(assets,'http') as call,patch.object(assets,'convert',side_effect=convert):
    self.assertTrue(assets.generate(manifest,'pilot')); call.assert_not_called()

 def test_state_lock_does_not_repeat_synthesis(self):
  manifest=copy.deepcopy(self.manifest); manifest['units']=[copy.deepcopy(self.unit)]; manifest['units'][0]['events']={'select':[self.line]}
  original_replace=Path.replace
  attempts={'failures':2}
  def transient_lock(path,target):
   if path.name=='state.tmp' and attempts['failures']:
    attempts['failures']-=1; raise PermissionError('transient scanner lock')
   return original_replace(path,target)
  def convert(raw,target,settings):
   target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(b'ogg'); return {'duration':1.0}
  with temporary_folder() as folder, patch.object(assets,'ROOT',Path(folder)), patch.object(assets,'STATE',Path(folder)/'state.json'), patch.object(assets,'ffmpeg_path',return_value='fake'), patch.object(assets,'ensure_voice'), patch.object(assets.Path,'replace',autospec=True,side_effect=transient_lock), patch.object(assets.time,'sleep'), patch.object(assets,'http',return_value=(b'raw',{})) as call, patch.object(assets,'convert',side_effect=convert):
   self.assertTrue(assets.generate(manifest,'pilot'))
   self.assertEqual(call.call_count,1)
   self.assertEqual(assets.load_state()['clips']['merchant/select_01']['status'],'generated')

if __name__=='__main__': unittest.main()
