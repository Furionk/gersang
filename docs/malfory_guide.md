# Malfory 使用與調整

F2 → 傭兵倉庫 → 選「女魔法師・Malfory」→「Lv1 加入倉庫」。不會自動換走舊兵。可先把一名傭兵存入倉庫，再取出Malfory；主角固定，最多7人。

戰鬥選取她：Q咒咒虐／W啊哇呾喀呾啦 → 左鍵點指定範圍。兩技冷卻0，但消耗MP20／50，可在Resource更改。

- Q：智慧100時每秒150傷害，減速35%，持續12秒；智慧減速最多80%。敵人離開範圍仍受詛咒。
- W：0.5秒前搖（全局施法倍率照常），智慧0為50%最大HP、智慧100為100%最大HP的原始傷害；法抗仍有效。短暫綠色染屏，綠色骷髏閃電與暴擊文字。智慧更高可以超過100%；不是按照當前剩餘HP。

調整能力／技能配給：features/units/data/mercenaries/malfory.tres。
調整Q公式、半徑、耗魔、減速上限與持續：features/skills/data/crucio.tres，展開Effect Data。
調整W百分比公式、前搖、半徑與綠色染屏：features/skills/data/avada_kedavra.tres，展開Effect Data。
快捷鍵：兩技的Default Key；若玩家已有自訂覆蓋，先按「跟隨資源」。

立繪／頭像／眼部橫幅都是同一PNG的原生AtlasTexture，在malfory.tres展開Standee／Portrait／Eyes Texture的Region即可改裁切。外部Sprite Layout：features/units/data/layouts/malfory_layout.tres，修改Frame Rects與Source Pivots。這不是在程式按兵種名稱特判。

之後新增可招募兵種：在features/progression/data/additional_mercenaries.tres的Definitions陣列拖入新UnitDefinition。不要改Catalog名字陣列或依賴一次性生成工具；舊初始七人清單保留作兼容。
