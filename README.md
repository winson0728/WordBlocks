# 字根工坊 WordBlocks

把枯燥的英文單字拆成「字首 + 字根 + 字尾」積木，讓記憶變成直覺、圖像化、可遊戲化的體驗。
同一份資料同時供 **網頁版（深度學習、系統化瀏覽）** 與 **Android App（碎片化複習、即時查閱）** 使用。

**線上版：https://winson0728.github.io/WordBlocks/**

目前收錄：54 個字首、215 個字根、47 個字尾，1,488 個單字，分成 10 個主題區。每個單字都有人工校對的拆解、字面義、中文釋義與例句，並依常用程度分成三級：基礎 641、進階 601、高階 246。

## 專案結構

```
index.html               網頁版（單一檔案，無需建置；資料已內嵌）
flutter_app/             Android App（Flutter）
data/
  categories.txt         主題區
  morphemes.txt          字首／字根／字尾
  words.txt              單字與拆解
  stories.txt            字源故事、聯想插圖提示
  levels.txt             每個單字的程度（由 assign_levels.py 產生）
  wordblocks.json        由上面四個檔案產生，網頁與 App 共用（勿手動修改）
  candidates.tsv         待審的高頻候選單字（由匯入腳本產生）
  candidate-roots.tsv    尚未收錄、但能解鎖最多常用字的字根
config/sync.json         帳號同步設定（Supabase 專案網址與 publishable key）
supabase/schema.sql      同步用的資料表與權限規則
tools/
  build-data.mjs         驗證資料並產生 wordblocks.json、更新 index.html 與 App 資料
  import_candidates.py   從開源字根資料集找出高頻候選單字
  assign_levels.py       依英文詞頻把單字分成基礎／進階／高階
```

## 網頁版

直接用瀏覽器開啟 `index.html`。視窗寬度 ≥ 1180px 是三欄的網頁版布局，≤ 820px 自動切換成手機版單欄＋底部分頁列。

| 功能 | 內容 |
| --- | --- |
| 字根地圖 | 以字根為中心的放射狀關聯圖；點單字看積木拆解，點積木跳到該字首／字根／字尾 |
| 字源故事 | 神話與歷史典故（panic ← 牧神 Pan、mortgage ← 死亡的誓約等），附 AI 插圖提示 |
| 拆解實驗室 | 詞庫收錄字顯示人工校對拆法；未收錄字自動比對字首／字根／字尾表推測 |
| 瀏覽器外掛預覽 | 模擬在英文新聞頁點選單字，就地彈出拆解 |
| 今日複習 | 間隔重複（SM-2 簡化版）：字根字義、選出含某字根的單字、拼出否定形單字 |
| 字根積木 | 給中文字義，拖拉或點選積木拼出單字 |
| 解鎖地圖 | 各主題區銅／銀／金牌與成就勳章 |

右上角的「基礎／＋進階／全部」決定字根地圖、複習和積木要出現哪些程度的單字（預設：基礎＋進階）；拆解查詢不受影響。手機 App 在「設定」裡調整。

學習進度存在瀏覽器 `localStorage`；第一次開啟會載入示範進度，可按右上角「從零開始」清除。登入同步後，示範進度會被捨棄，不會上傳到帳號。

### 用 GitHub Pages 發布

到 repo 的 **Settings → Pages**，Source 選 **Deploy from a branch**，Branch 選 `main`、資料夾選 `/ (root)`，按 Save。
約一分鐘後網址會是 `https://winson0728.github.io/WordBlocks/`。

## Android App

在 `flutter_app/`，詳見該資料夾的 README。

- 五個分頁：字根地圖、拆解、複習、積木、成就（解鎖地圖與勳章）
- 右上角「設定」：帳號同步、每日複習提醒（可選時間）、桌面小工具說明
- 桌面小工具「今日字根」：長按桌面 → 小工具 → 字根工坊。每天午夜後自動換字根，不必開 App
- 複習進度存在手機上；登入後與網頁版同步

每次推送到 `main`，GitHub Actions（`.github/workflows/android.yml`）會檢查資料、跑分析與測試，並建置 APK。
到 repo 的 **Actions** 分頁點最新一次執行，在 Artifacts 下載 `wordblocks-apk`，解壓縮後即可安裝到手機（需允許安裝未知來源 App）。

本機開發：

```bash
cd flutter_app
flutter test
flutter run
```

## 帳號同步（網頁 ↔ 手機）

同步用 [Supabase](https://supabase.com)（免費方案即可）。設定一次：

1. 在 Supabase 建立專案。
2. 打開 **SQL Editor**，貼上 `supabase/schema.sql` 全部內容並執行。這會建立 `progress` 資料表，並設定「每個人只能讀寫自己的資料」。
3. 到 **Authentication → URL Configuration**，把 **Site URL** 設成 `https://winson0728.github.io/WordBlocks/`（確認信裡的連結會回到這裡）。
4. 到 **Project Settings → API Keys**，把 Project URL 和 **Publishable key**（舊專案叫 anon public key）填進 `config/sync.json`：
   ```json
   { "supabaseUrl": "https://xxxx.supabase.co", "supabaseKey": "sb_publishable_..." }
   ```
   這兩個值本來就是公開的，安全由第 2 步的資料庫規則保護。**絕對不要**放 `service_role` 或 `sb_secret_` 開頭的金鑰，建置腳本也會拒絕。
5. 執行 `node tools/build-data.mjs` 後推送。網頁版右上角會出現「登入同步」，App 的設定頁也會出現登入表單。

同步規則：每張卡片保留最近一次複習的版本，學習日期合併，成就計數取較大值。每次複習後約 3 秒自動同步，開啟 App 或網頁時也會同步。

## 新增單字與字根

1. 編輯 `data/words.txt`（或 `morphemes.txt`、`stories.txt`），一行一筆，欄位用 `|` 分隔。
   拆解寫成字根 id，拼法不同時寫 `id=拼法`，例如：
   `destroy|de struct=stroy|摧毀|反轉 + 建造：把蓋好的拆掉|The storm destroyed several houses.`
2. 執行 `python3 tools/assign_levels.py`（需要 `pip install wordfreq`）替新單字標上程度；想手動指定程度，寫在 `data/level-overrides.txt`（格式 `word|1`）。
3. 執行 `node tools/build-data.mjs`。它會檢查每個拆解是否正好拼出單字、每個 id 是否存在，
   再更新 `data/wordblocks.json`、`index.html` 與 App 的資料。有錯誤時不會寫入任何檔案。

### 從開源資料集找高頻字

```bash
pip install wordfreq
python3 tools/import_candidates.py --min-zipf 3.5
```

腳本會從兩個 MIT 授權的開源字根資料集取出範例單字，以英文詞頻篩選出生活與商業常用字，
用現有的字首／字根／字尾自動拆解，寫到 `data/candidates.tsv`（status 為 `ready` 的可直接拆解）。
另外 `data/candidate-roots.tsv` 列出還沒收錄、但能解鎖最多常用字的字根。

**候選字一定要人工審核**：自動拆解只看拼法，會出現看似合理但字源錯誤的結果，例如
`portion` 來自 portio「份」而非 port「搬運」，`division` 來自 dividere「分」而非 vid「看」，
`protect` 的 tect（遮蓋）和 `contact` 的 tact（接觸）也常被資料集混為一談。
審核後補上中文釋義、字面義與例句，再貼進 `words.txt`。

## 建議的正式版架構

- **資料表**：`morphemes`、`words`、`word_parts(word_id, position, morpheme_id, surface_text)`、
  `morpheme_links(a_id, b_id, relation)`（變體、易混淆、同義）、`review_cards`、`review_logs`。
- **平台功能**：網頁版做成瀏覽器擴充功能（反白查詢）；Android 加上桌面小工具與每日複習推播。

## 資料來源與授權

- 字根、單字拆解、中文釋義、例句與字源故事：本專案自行整理。
- 候選字來源（僅供 `tools/import_candidates.py` 在本機下載使用，不隨 App 發布）：
  - [colingoldberg/morphemes](https://github.com/colingoldberg/morphemes)，MIT License，© 2019 Colin Goldberg
  - [WithEnglishWeCan/generated-english-roots-list](https://github.com/WithEnglishWeCan/generated-english-roots-list)，MIT License
- 詞頻：[wordfreq](https://github.com/rspeer/wordfreq)（Robyn Speer 等，資料為 CC BY-SA 4.0）。用來篩選候選字，並把單字分成三個程度；隨 App 發布的只有每個單字的程度（1–3），沒有詞頻數值。
