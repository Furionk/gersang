# 兵種語音製作與試音

**Malfory新聲線**：使用者選英語女聲，Lily – Velvety Actress（英式、成熟、絲絨感），選取／移動／查看資料帶魅惑，攻擊帶自信威勢。12段已接入正常倉庫招募與出戰。聲音庫現為34份配置／258段；其他待定新角色不因此自動配音。角色數值、技能、立繪及原隊伍保持原樣，測試用隔離存檔。

**新增忍者（本輪僅此兵種）**：Callum低沉英文男聲，指定四句原文保留；SELECT與INSPECT各2段、MOVE2段、ATTACK3段，共9段。戰鬥F2→新兵試玩→忍者，關閉視窗後點忍者／右鍵移動或攻擊可聽。永久七人隊不變，這個試兵不寫入存檔。湖衣姬、鐵炮手與新敵人／召喚物尚未配音；新總量為33份配置／246段。

**最新更正**：雷術師為日語女性Yuki，道術師為日語女性Yuko，兩人24段已重製。角色點選／資料查看每次都立即重播下一個變化，打斷上句但不疊音；同角色連點不再受0.8s／2s冷卻限制。一次世界肖像操作只申請一段，資料頁內同角色按鈕也每次回應。以下初版性別、語言及冷卻敘述屬歷史，最新契約以specs/unit_voices.md為準。

**全量已完成**：使用者確認第二版後，32種兵／237段本地OGG全部生成並接入Godot。七人隊各12段、箭魂9段、24種敵方／召喚物各6段。語音451/451、真實音訊入口199/199、工具14/14通過，缺失／過期檔案皆0。試音頁可按兵種播放全部語音；歷史審閱與試音階段說明保留在下文。遊戲正在執行時，重新執行F5以載入完整新資產。

**目前第二輪**：商人改Qiao Feng，方向為年輕有為、朝氣、自信；鐵衛改MyungIn，符咒師改Yui。9段人聲已重製，2段怪物聲效沿用。所有人語配置取消人工音高處理與speaker boost；表演指示已記錄並納入生成hash。原試音頁刷新可聽新版，第一版在頁面的「第一版對比」。新版商人三句1.47–2.01秒；符咒師attack_01約3.53秒仍待聽感審閱。生成工具13/13、語音193/193通過。後文的第一批聲線與較長句子記錄是V1歷史。

先開 `artifacts/unit-voices/preview.html`，預設顯示11段試音；每段旁有母語台詞、中文意思、聲線與個性。可切換到全部237個台詞／聲效槽位。語音的原始MP3和SHA-256記錄保留在artifacts；遊戲只引用art/voices內的OGG。

第一批：商人（Arthur）、鐵衛（Kevin）、符咒師（Izayoi）各SELECT/MOVE/ATTACK一段，租霸豬接敵／死亡各一段。這些公開聲線已用於試音；其餘聲線為待審建議，不代表完成全量聽感確認。

```powershell
python tools/unit_voice_assets.py preview
python tools/unit_voice_assets.py generate --scope pilot
python tools/unit_voice_assets.py resume --scope pilot
python tools/unit_voice_assets.py validate --scope pilot --require-complete
python -m unittest discover -s tests -p test_unit_voice_assets.py -v
```

生成僅使用ELEVENLABS_API_KEY環境變數；不要把key放進JSON、腳本、Godot或報告。FFmpeg從PATH尋找，亦支援本機既有路徑。Creator權限已於規劃時及首次生成確認，不保證後續帳戶額度不變。

改台詞、voice_id、模型或聲線／轉檔設定會使該段hash失效；未改段落不重製。翻譯修正不扣生成額度。成功段落保留，單段400/422不阻止其他段落；認證／額度／429重試耗盡會停止。原始音訊已收到而轉檔失敗，resume只重新轉檔。

連線中斷可能已在服務端扣額度，所以標記uncertain，不自動再POST。先查看ElevenLabs生成歷史；確認可重試後才使用`--retry-uncertain`。不要為修復狀態而刪除其他成功段落。

試音批准後，代理依使用者確認更新manifest的full_generation_approved，再`generate --scope all`。`prepare_unit_voices.py`是一次性原始台詞建立工具，已有manifest時拒絕覆寫；後續直接編輯manifest及對應原生profile，不要重跑bootstrap覆寫作者修改。

試聽重點：母語口音、角色個性、句頭是否乾淨、句尾是否完整、攻擊力度及連點是否煩躁。鐵衛move_01约3.02s、商人move_01约3.27s超過目標3s，保留原檔等待審閱。其餘9段約1.28–2.12s。OGG為44.1kHz單聲道，以-18 LUFS／-2dBTP為轉檔目標；局部音色偏移已記錄於postprocess，不代表新的獨立演員聲線。

遊戲測試：戰鬥點選／框選／肖像／編隊、右鍵移動／攻擊、A攻擊移動、Shift排隊、快速連點、怪群接敵／死亡；世界點肖像／開背包／開能力頁／切換角色。未生成的INSPECT與其他變化目前靜音，這是試音階段的明確限制。

現有養成、地圖、移動、技能和存檔不修改。原始修改檔案在artifacts/unit-voices/originals，驗證及完成報告在同一artifacts目錄。完整回歸若遇到舊fixture或地圖內容問題，報告實際失敗，不為語音更動遊戲內容去迎合舊測試。
