# 可選素材與公開版執行方式

## 背景音樂

`art/music/` 不隨 Git 分發。`BackgroundMusic` 只為存在的 MP3 建立播放器，沒有曲目時維持靜音。音效、角色語音、戰鬥及存檔不依賴 BGM。

若你有合法使用權，將自己的 MP3 放入 `art/music/`，並在 `features/audio/background_music.gd` 的 `TRACKS` 指定路徑。重新匯入資源後執行遊戲。Web 的 `web_no_bgm` 匯出仍會停用 BGM。

## EmacEArt 村莊

- 作者：Maciej EmacArt / EmacEArt。
- 素材包：Free Fantasy Medieval Houses。
- [作者下載頁](https://emaceart.itch.io/free-fantasy-medieval-houses-and-props-pack)。
- 作者本機使用的來源檔：`SlavicWorldFree_Godot_2026-09-06.zip`。
- 來源 SHA-256：`fa1617aa00b73a35d08e0e1b2eafc102b2faf6e473a55d100fb66c2a85416374`。

隨附 EmacEArt Asset License 允許遊戲內使用與修改，但禁止將素材作獨立檔案或素材包再分發。因此 Git 排除 `features/monkey/assets/emaceart/` 及 `features/monkey/village_*.tscn`。作者本機的改編場景及素材保留於原位置，不會被清理。

### 使用公開版庭園

不需下載額外素材。`MonkeyProfile.resolved_scene()` 在指定場景不存在時回傳 `features/monkey/garden.tscn`。普通、疾風、狂亂及絕望入口保留各自的時間、數量與 AI 參數，使用內附庭園地形。村莊路線與平衡不適用於這個後備地形。

### 自行安裝村莊素材

1. 從作者頁自行取得素材包，閱讀下載版本的授權。
2. 將素材匯入你自己的 Godot 專案或此專案的本機目錄 `features/monkey/assets/emaceart/`。
3. 以內附 `features/monkey/garden.tscn` 為玩法範本，將合法取得的環境整合至自己的場景。保留 `garden.gd`、`LevelLayout`、出生點、猴子巡邏標記、碰撞與導航。
4. 在 `features/monkey/data/` 的對應 `MonkeyProfile` Resource，將 `scene` 指向已完成的場景，再測試出入口及捕猴。

原包匯入不會自動重現作者已改編的村莊配置。本倉庫不提供受限素材或改編村莊的下載包。若你是原作者工作站，Git 排除的本機 `village_*.tscn` 及素材已存在，程式會繼續優先使用它們。
