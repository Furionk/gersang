# D37 女魔法師 Malfory

使用者2026-10-11指定金髮、黑綠長袍／白襯衫／綠銀領帶的女性法師，三張造型參考不作照片身份複製。新增原創SpriteSheet、立繪及骷髏閃電。F2正式倉庫可招募Lv1，既有主角／編隊／候補進度不改；只招募不自動替換。

已確認係數：Crucio每秒智慧×1.5傷害；減速25%＋智慧×0.1%，最多80%；持續10＋智慧×0.02秒。施法時範圍內敵人（地面及飛行）受附著詛咒，離開仍持續，同一施法者減速刷新，不疊減速；不同施法者取最強。每次施法的傷害效果獨立，不自動取消上次傷害。智慧採釋放快照。Q地面範圍確認、MP20、CD0、範圍150、射程450為可改初始值。

Avada Kedavra使用者確認傷害=目標最大HP×(50%＋施法者智慧×0.5%)，智慧100可達100%原始最大HP傷害，倍率可以超過100%。仍經現有MAGIC法抗，不繞過兩階段王的死亡進化、結算或獎勵保護。「暴擊」為骷髏閃電及暴擊文字呈現，不額外隨機乘2–3倍。W地面範圍確認、0.5s前搖（沿用全局施法倍率）、MP50、CD0、範圍130、射程500為可改初始值。每個施法只命中初始範圍敵人一次，綠色全屏染色0.22s、alpha0.13、不攔輸入、重施刷新、不疊畫面。

Native資料權威：mercenaries/malfory.tres（能力／單一立繪Atlas crops／外部技能及Layout），skills/data/crucio.tres、avada_kedavra.tres（公式／慢速上限／半徑／消耗／前搖／染色），units/data/layouts/malfory_layout.tres（48格原生Atlas／脚底）。沒有以角色名字硬編碼技能，新增Kind只尾部追加。

追加招募清單改為features/progression/data/additional_mercenaries.tres的typed UnitDefinition陣列。倉庫、保存驗證允許清單及試兵按鈕共用它；舊Catalog.NEW_UNIT_IDS僅舊三兵測試相容常量，不再是招募權威。原初七人的PARTY_PATHS與舊v1存檔身份映射保留。新兵沒有敵方版本，勾敵方試兵會給出明確錯誤，不讀缺失檔案。

原圖保留；UI立繪／頭像／眼部共用malfory-standee-v1.png。原創圖集malfory-v1.png、特效malfory-skull-v1.png經內建imagegen生成，提示保存在artifacts/malfory-2026-10-11/image-prompts.json。一次性create_malfory及link工具不准日常重跑覆寫Artist（create會拒絕既有檔）。link僅本次來源接線修正，不是啟動hook。

驗證malfory_suite：正式倉庫保存流程的隔離招募/存取、Lv1、原兵保留、實際正常上場、快照與範圍、空中命中、減速上限／到期、最大HP非當前HP、可致死、前搖／合法公式／不重複傷害、短暫染色／cleanup。原生48格GPU、角色頁／戰鬥截图、舊兵／倉庫／全套與GPU MOVE。正式存檔未讀寫；不是手動Editor鼠標證據。
