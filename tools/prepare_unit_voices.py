"""One-shot authored initial voice data. Refuses to overwrite an existing manifest."""
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'features/audio/data/unit_voices.json'

# Original native-language short dialogue; translations are for review, never spoken.
PARTY = {
 'merchant': ('zh', '中國', 'male', 'young', '機靈、自信、愛冒險', {
  'select': ['遠路才有好買賣！', '嘿，找我做哪筆生意？', '見識可比銀子值錢！'],
  'move': ['這條路，我來探！', '收好行囊，出發！', '好地方可不等人！'],
  'attack': ['敢擋我的財路？', '這回可不講價！', '讓你見識我的本事！'],
  'inspect': ['看看，我的家當都在這！', '行走四方，靠的是真本事！', '別急，好東西慢慢看！']}),
 'guard': ('ko', '朝鮮', 'male', 'middle_aged', '沉穩、厚實、忠誠', {
  'select': [('제가 지키겠습니다.', '由我守護。'), ('방패는 굳건합니다.', '盾牌依然堅固。'), ('명령을 기다립니다.', '等候您的命令。')],
  'move': [('앞장서겠습니다.', '我來走在前面。'), ('대열을 지키십시오.', '請保持隊形。'), ('굳건히 나아갑니다.', '堅定向前。')],
  'attack': [('제 뒤에 서십시오!', '站到我身後！'), ('물러서지 않겠습니다!', '我絕不退讓！'), ('방패로 길을 열겠습니다!', '以盾開路！')],
  'inspect': [('갑옷은 늘 살펴야 합니다.', '盔甲須時常檢查。'), ('상처는 견딜 수 있습니다.', '這些傷我承受得住。'), ('믿고 등을 맡기십시오.', '放心把後背交給我。')]}),
 'gunner': ('ja', '日本', 'male', 'young', '爽朗、俐落、愛惜武器', {
  'select': [('火薬は乾いてるぜ。', '火藥可乾爽得很。'), ('狙いなら任せな！', '瞄準就交給我！'), ('手入れは済んでるぜ。', '保養早就做好了。')],
  'move': [('いい射場を探そうぜ。', '找個好射擊位置吧。'), ('筒を担いで、出発だ！', '扛起火銃，出發！'), ('おう、そこまで走るぜ。', '好，我跑到那裡。')],
  'attack': [('一発、決めてやる！', '這一發要打個漂亮！'), ('射線を空けてくれ！', '讓開射擊路線！'), ('その隙、もらった！', '這個破綻，我收下了！')],
  'inspect': [('火薬袋には触るなよ。', '別亂碰火藥袋喔。'), ('こいつは頼れる相棒さ。', '它可是可靠的夥伴。'), ('腕は錆びちゃいねえぜ。', '我的本事可沒生鏽。')]}),
 'mage': ('ko', '朝鮮', 'male', 'young', '高傲、精準、威勢', {
  'select': [('천둥이 들리는가?', '聽見雷聲了嗎？'), ('하늘의 기운을 읽는다.', '我洞察天之氣。'), ('내 솜씨를 의심하나?', '你懷疑我的本領？')],
  'move': [('바람을 따라가겠다.', '我將循風而去。'), ('그곳에 기운이 모인다.', '氣息正匯聚在那裡。'), ('길은 내가 밝히겠다.', '由我照亮道路。')],
  'attack': [('벼락을 받아라!', '接下這道雷！'), ('하늘의 노여움이다!', '這是天之怒！'), ('한 줄기면 충분하다!', '一道便足夠！')],
  'inspect': [('기운을 흐트러뜨리지 마라.', '別擾亂氣息。'), ('내 힘은 아직 넘친다.', '我的力量仍然充沛。'), ('번개는 망설이지 않는다.', '閃電從不猶豫。')]}),
 'healer': ('zh', '中國', 'female', 'middle_aged', '溫和、可靠', {
  'select': ['哪裡不舒服？', '有我在，安心些。', '藥箱一直備著呢。'],
  'move': ['慢些，我跟得上。', '前面的路要當心。', '好，我帶上藥箱。'],
  'attack': ['別逼醫者動手！', '休想傷我的同伴！', '先制住這個禍患！'],
  'inspect': ['藥材都分好了。', '身子好，才走得遠。', '傷口可不能硬撐。']}),
 'supplier': ('zh', '中國', 'male', 'old', '灑脫、從容', {
  'select': ['道在腳下，不在天邊。', '呵呵，何事勞神？', '一壺清茶，便是自在。'],
  'move': ['且隨清風走一程。', '這條路，頗有意思。', '好，貧道去也。'],
  'attack': ['莫把慈悲當軟弱。', '借天地之氣一用！', '此處容不得你作亂！'],
  'inspect': ['行囊雖小，乾坤不小。', '氣息平順，諸事皆安。', '符紙可要收乾爽些。']}),
 'controller': ('ja', '日本', 'female', 'young', '冷靜、神祕、簡潔', {
  'select': [('札が呼んでいます。', '符紙正在呼喚。'), ('気配を感じます。', '我感覺到了氣息。'), ('静かに、お話を。', '請輕聲說吧。')],
  'move': [('影に沿って進みます。', '我將循影而行。'), ('その先を確かめます。', '我去探明前方。'), ('承知しました。', '明白了。')],
  'attack': [('その魂、縛ります。', '我要束縛那靈魂。'), ('逃げ道はありません。', '你無路可逃。'), ('札よ、封じなさい。', '符紙啊，封住它。')],
  'inspect': [('札の順は変えないで。', '請別改動符紙的次序。'), ('見えぬものも、ここに。', '看不見之物，也在此處。'), ('まだ、力は残っています。', '力量尚未耗盡。')]})
}
ENEMIES = {
 'archer': ('山寨弓兵', '攔路、貪財、狡猾', ['過路錢拿來！','敢闖咱們的地盤？','我的箭可不長眼！'], ['這筆買賣……虧了。','我的弓……斷了。','兄弟們，快走！']),
 'ember_raider': ('赤焰劫匪','兇悍、急躁、劫掠', ['火裡也得把你劫下！','把值錢的都留下！','燒光你的退路！'], ['火怎麼……熄了？','這回……失手了。','我的戰利品……']),
 'boss': ('赤魂獄使','威嚴、殘酷、獄吏', ['此門只進不出！','亡魂，歸我管束！','你的名字，記下了！'], ['獄門……竟然開了。','我的鎖鏈……碎了。','誰敢……逆我判令？']),
 'lake_guardian': ('千年湖守','古老、陰冷、守湖', ['千年湖底，容不得生人。','水面已記住你的倒影。','沉入我的湖吧！'], ['湖水……帶我回去。','千年的誓言……散了。','我的倒影……消失了。']),
 'shaolin_guardian': ('銅棍護院','戒律、堅毅、守院', ['止步，此院不可擅闖！','銅棍不容邪祟！','先過我這一關！'], ['護院之責……未盡。','這一棍……失了分寸。','師兄……守住院門。']),
 'shaolin_iron_disciple': ('鐵棍武僧','剛直、勤練、勇猛', ['請教高招！','鐵棍之下，見真章！','休想亂我陣腳！'], ['今日……技不如人。','我的棍……握不住了。','這身功夫……還欠火候。']),
 'shaolin_swift_disciple': ('疾影棍僧','敏捷、機警、輕快', ['你追得上這道影嗎？','棍影已到！','莫眨眼！'], ['這一次……慢了。','腳下……再無力了。','影子……也散了。']),
 'shaolin_shadow_captain': ('疾影統領','嚴整、敏銳、統領', ['收緊陣線！','隨我截住來敵！','疾影陣，合！'], ['陣眼……失守。','眾弟子……莫亂。','此陣……交給你們。']),
 'shaolin_flame_keeper': ('赤燈護法','莊重、執著、守燈', ['赤燈未滅，爾等休進！','燈火照破邪念！','退到燈影之外！'], ['燈芯……護不住了。','這盞燈……莫熄。','火光……遠了。']),
 'shaolin_thunder_warden': ('震地護法','威猛、篤定、震地', ['大地亦有雷聲！','站穩了！','這一擊，震碎邪障！'], ['大地……接住我。','雷聲……止了。','護法之身……亦有盡時。']),
 'shaolin_copper_master': ('銅人陣師','老練、精確、布陣', ['銅人列陣！','你的步法，我看穿了。','陣中無退路！'], ['陣勢……斷了。','銅人……失去呼應。','終是……棋差一著。']),
 'shaolin_elite_copper': ('金剛陣師','堅定、威嚴、精通陣法', ['金剛之陣，不動如山！','破陣之前，先問我！','萬邪難入此陣！'], ['金剛陣……竟破了。','不動之心……動了。','此身……守到盡頭。']),
 'shaolin_grandmaster': ('金身羅漢','莊嚴、慈悲、強大', ['回頭，尚有餘地。','金身護法，伏邪！','你的執念，該放下了。'], ['金身……亦歸塵土。','放下……便無所懼。','這一程……到此為止。']),
 'well_pyromancer': ('古井燃燈巫','陰森、巫術、燃燈', ['井火為你點起了！','來做我的燈芯吧。','別躲，火已聞見你！'], ['燈油……乾了。','井火……棄我而去。','誰把……燈吹滅了？']),
 'well_blood_wraith': ('古井血侍','怨恨、嗜血、侍從', ['井底還缺一份血。','聽，血在呼喚。','把你的熱血留下！'], ['血……流盡了。','井主……救我。','這口井……太冷了。']),
 'deep_well_pyromancer': ('深井焚魂祭司','狂熱、祭祀、焚魂', ['你的魂，正合此祭！','深井之火，醒來！','祭壇已為你留位！'], ['祭火……反噬了。','供奉……竟是我自己。','深井……不再應我。']),
 'deep_well_blood_wraith': ('深井嗜血刑鬼','殘酷、暴戾、刑罰', ['刑期，才剛開始！','深井吞得下你的哭聲。','這一刑，你逃不掉！'], ['誰來……替我受刑？','枷鎖……勒住了我。','原來……我也會痛。']),
 'deep_well_shock_guard': ('深井裂焰鬼將','兇猛、軍威、鬼將', ['裂焰軍令，斬！','此井由我鎮守！','踏碎你們的陣線！'], ['軍旗……倒了。','深井的火……冷了。','此將……敗於此地。'])
}
NONVERBAL = {
 'beast': ('租霸豬','boar','A large wild boar, rough snorts and throaty squeals'),
 'bloodfang': ('噬血山魈','mandrill demon','A predatory mountain mandrill demon, feral chattering snarls'),
 'earth_brute': ('裂地石妖','stone demon','A huge living stone demon, deep gravel grinding groans'),
 'elite': ('黑甲石衛','stone guardian','An armored stone guardian, hollow resonant stone rumbling'),
 'well_earth_sentinel': ('古井震地鬼衛','ghost sentinel','An ancient well sentinel, eerie low metallic spectral moaning'),
 'copper_reinforcement': ('金身銅人','copper construct','A living copper monk construct, resonant bronze chest vibration')
}
VOICES = {
 'zh_male': {'voice_id':'xQsp9uyB3OResmXFYuFx','name':'Arthur - Chinese Male','source':'ElevenLabs public Voice Library','public_owner_id':'63d2922605db2bfb04f15808540e9bc0a1564a43e41fb5d86e8c0f8ab0aa6613','native_language':'zh','notice_period':730},
 'zh_female': {'voice_id':'8uceOSflAGVvQuMt4HPh','name':'Shasha - Clear, Friendly, Posh & Poised','source':'ElevenLabs public Voice Library','public_owner_id':'1e34bbf401beda95647818ae64974dc9257a21f0bd593c0c869f054872aea982','native_language':'zh','notice_period':730},
 'zh_old': {'voice_id':'TOqw2KMUcZIpRjRBCzgG','name':'Xiao Fan - Natural Chinese','source':'ElevenLabs public Voice Library','public_owner_id':'04c352fa80bff9e3ff985b7497b2a007f319d0b966cafe889f5d815f2386fb35','native_language':'zh','notice_period':730},
 'ko_guard': {'voice_id':'UGyzuK2FVKdr7ri5KDh8','name':'Kevin - Deep, Trustworthy & Professional','source':'ElevenLabs public Voice Library','public_owner_id':'70b268e69a86d7ceb1e5a3450f6db1d97e4c7a38aaeae704de2ba63385bb5c1e','native_language':'ko','notice_period':730},
 'ko_mage': {'voice_id':'TYtEXo4iveDrHtI090z1','name':'Yang Seon-woo - Korean male','source':'ElevenLabs public Voice Library','public_owner_id':'cadb6d598033a16907a5bfe88d0e1f48fafea195bfe43f35493ba154f25709ca','native_language':'ko','notice_period':730},
 'ja_male': {'voice_id':'MvMFbhzZT2zcr5QsG1xY','name':'Masa - Warm Japanese Radio Host','source':'ElevenLabs public Voice Library','public_owner_id':'469f77eb3a1f26b0a3655c0a6731a9748b89001feb4d09c80a7cbe3dacf4c82e','native_language':'ja','notice_period':730},
 'ja_female': {'voice_id':'cpUQFbEcX3tjJdSSiDPb','name':'Izayoi - Serene, Soft & Whispery','source':'ElevenLabs public Voice Library','public_owner_id':'8fe76c89025cddf67b6a09aff76625a87bc3713479ca81afc47c420d18291842','native_language':'ja','notice_period':730}
}

def build():
 if MANIFEST.exists():
  raise SystemExit('Existing authored manifest preserved; edit it directly instead.')
 definitions = {}
 for group in ('mercenaries','monsters','summons'):
  for path in (ROOT/'features/units/data'/group).glob('*.tres'):
   text = path.read_text(encoding='utf-8-sig')
   uid = re.search(r'^id = &"([^"]+)"', text, re.M)[1]
   name = re.search(r'^display_name = "([^"]+)"', text, re.M)[1]
   definitions[uid] = (path, name)
 assert len(definitions) == 32
 units=[]
 for uid,(path,name) in sorted(definitions.items()):
  gender,age='male','middle_aged'; language,nation='zh','中國'; species='human'
  if uid in PARTY:
   language,nation,gender,age,personality,events=PARTY[uid]
   group='player'; profession=name
   voice_key={'guard':'ko_guard','mage':'ko_mage','gunner':'ja_male','controller':'ja_female','healer':'zh_female','supplier':'zh_old'}.get(uid,'zh_male')
  elif uid=='spirit':
   group='player_summon'; profession='箭魂'; species='ancestral spirit'; personality='忠誠、古雅、果斷'; voice_key='zh_male'
   events={'select':['忠魂仍在。','此箭不負所託。','聽候差遣。'],'move':['魂隨令行。','前路由我探明。','循此路而去。'],'attack':['以此箭，報知遇！','此心不退！','箭至，邪散！']}
  elif uid in NONVERBAL:
   group='enemy'; name,species,character=NONVERBAL[uid]; language=nation=''; profession=name; personality=character; voice_key=None
   events={event:[(f'{character}. One isolated {action}, variation {i}, dry close recording, no speech, no music, no ambience.',meaning) for i in range(1,4)] for event,action,meaning in [('engage','short aggressive challenge vocalization','接敵叫聲'),('death','brief defeated collapsing dying vocalization','死亡叫聲')]}
  else:
   group='enemy'; profession,personality,engage,death=ENEMIES[uid]; voice_key='zh_male'; events={'engage':engage,'death':death}
   if any(x in uid for x in ('wraith','pyromancer','boss','lake_guardian','shock_guard')): species='intelligent spirit'
  settings={'stability':0.5,'similarity_boost':0.75,'style':0.0,'use_speaker_boost':True,'speed':1.0}
  # Keep each identity distinct even when using a shared native speaker: character direction,
  # speaking rate and conservative local tone shift are separately recorded and reviewed.
  pitch={'merchant':1.05,'guard':0.92,'gunner':1.02,'mage':1.08,'healer':1.0,'supplier':0.89,'controller':0.98,'spirit':0.94}.get(uid, 0.88 if 'deep_well' in uid else 0.96 if 'shaolin' in uid else 1.0)
  voice=VOICES[voice_key].copy() if voice_key else {'voice_id':'','name':character,'source':'ElevenLabs Sound Effects API'}
  lines={}
  for event,texts in events.items():
   lines[event]=[]
   for index,item in enumerate(texts,1):
    text,translation=item if isinstance(item,tuple) else (item,item)
    pilot=(uid in ('merchant','guard','controller') and event in ('select','move','attack') and index==1) or (uid=='beast' and index==1)
    lines[event].append({'id':f'{event}_{index:02}','text':text,'translation_zh':translation,'path':f'res://art/voices/{uid}/{event}_{index:02}.ogg','pilot':pilot})
  units.append({'unit_id':uid,'name':name,'definition_path':path.relative_to(ROOT).as_posix(),'group':group,'nationality':nation,'language':language,'species':species,'profession':profession,'personality':personality,'gender':gender,'vocal_age':age,'voice':voice,'model_id':'eleven_v3' if voice_key else 'eleven_text_to_sound_v2','voice_settings':settings if voice_key else {'duration_seconds':2.0,'prompt_influence':0.5},'postprocess':{'sample_rate':44100,'channels':1,'loudness_lufs':-18,'true_peak_db':-2,'vorbis_quality':5,'pitch_ratio':pitch if voice_key else 1.0},'events':lines})
 manifest={'schema':1,'review_status':'awaiting_pilot_review','full_generation_approved':False,'units':units}
 assert sum(len(v) for u in units for v in u['events'].values())==237
 assert sum(l['pilot'] for u in units for v in u['events'].values() for l in v)==11
 MANIFEST.parent.mkdir(parents=True,exist_ok=True)
 MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 for unit in units:
  uid=unit['unit_id']; profile=MANIFEST.parent/f'{uid}.tres'
  events={e:[l['path'] for l in lines] for e,lines in unit['events'].items()}
  fields={'unit_id':uid,'nationality':unit['nationality'],'language':unit['language'],'species':unit['species'],'profession':unit['profession'],'personality':unit['personality'],'voice_id':unit['voice']['voice_id'],'model_id':unit['model_id'],'manifest_path':'res://features/audio/data/unit_voices.json'}
  content='[gd_resource type="Resource" script_class="UnitVoiceProfile" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://features/audio/unit_voice_profile.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\n'
  content+='\n'.join(f'{k} = '+('&' if k=='unit_id' else '')+json.dumps(v,ensure_ascii=False) for k,v in fields.items())+'\nevents = '+json.dumps(events,ensure_ascii=False)+'\n'
  profile.write_text(content,encoding='utf-8')
  source=ROOT/unit['definition_path']; backup=ROOT/'artifacts/unit-voices/originals'/unit['definition_path']; backup.parent.mkdir(parents=True,exist_ok=True)
  if not backup.exists(): shutil.copy2(source,backup)
  text=source.read_text(encoding='utf-8-sig')
  text=text.replace('\n[resource]',f'\n[ext_resource type="Resource" path="res://features/audio/data/{uid}.tres" id="voice_profile"]\n\n[resource]',1)
  text+='\nvoice_profile = ExtResource("voice_profile")\n'
  source.write_text(text,encoding='utf-8',newline='\n')
 print('Prepared 32 profiles, 237 slots, 11 pilot clips; full generation awaits review.')

if __name__ == '__main__': build()
