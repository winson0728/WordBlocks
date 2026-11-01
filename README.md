# 字根工坊 Root Workshop

把枯燥的英文單字拆成「字首 + 字根 + 字尾」積木，讓記憶變成直覺、圖像化、可遊戲化的體驗。
同一套資料同時支援 **網頁版（深度學習、系統化瀏覽）** 與 **Android 手機版（碎片化複習、即時查閱）**。

目前這個 repo 是可直接執行的**互動原型**：單一 `index.html`，無需建置，用瀏覽器開啟即可。
視窗寬度 ≥ 1180px 為網頁版三欄布局；≤ 820px 自動切換為手機版單欄卡片 + 底部分頁列。

## 原型功能

| 模組 | 對應設計方向 | 內容 |
| --- | --- | --- |
| 字根地圖 | 字源關聯圖譜 | 以字根為中心的放射狀關聯圖；點單字看拆解，點積木跳到該字首/字根/字尾 |
| 積木拆解 | 樂高式拆解動效 | 字首／字根／字尾以藍／橘／紫積木分開，下方顯示小字義 |
| 字源故事 | 字源故事與圖像記憶 | 神話與歷史典故（panic ← 牧神 Pan、bankrupt ← 斷掉的長凳等），附 AI 插圖提示詞預留位 |
| 拆解實驗室 | 即時查閱 | 詞庫收錄字顯示人工校對拆法；未收錄字用動態規劃比對字首/字根/字尾表自動推測 |
| 瀏覽器外掛預覽 | 網頁版獨特功能 | 模擬在英文新聞頁點選單字，就地彈出拆解 |
| 今日字根小工具 | 手機版 Widget | 每天輪播一個核心字根 |
| 今日複習 | SRS 間隔重複 | SM-2 簡化版；題型包含字根字義、選出含某字根的單字、拼出含字根的否定形單字 |
| 字根積木 | 互動測驗 | 給中文字義（如「預先警告」），拖拉或點選積木拼出 forewarn / premonition |
| 解鎖地圖 | 成就系統 | 六大字根區（時間、方向、感官、動作、生命、關係）銅／銀／金牌與成就勳章 |

內建資料：約 79 個字首／字根／字尾、92 個單字（含拆解、字面義、中文釋義、例句）。
學習進度存在瀏覽器 `localStorage`；首次開啟會載入示範進度，可在右上角「從零開始」清除。

## 建議的正式版架構

- **前端**：Flutter（一套程式碼輸出 Android／iOS／Web），或 React Native + React Web 共用邏輯層。
- **後端與同步**：Supabase（Postgres + Auth + Realtime）或 Firebase，收藏與複習紀錄跨裝置即時同步。
- **資料模型**（關聯式即可表達字根網路，必要時再加圖形資料庫）：

```
morphemes(id, type[pre|root|suf], forms[], meaning_zh, origin, category, story, image_prompt)
words(id, word, meaning_zh, literal_zh, example)
word_parts(word_id, position, morpheme_id, surface_text)   -- 例：destroy = de + stroy(struct)
morpheme_links(a_id, b_id, relation[variant|confusable|same_meaning])  -- 例：pan ↔ Pan（易混淆）
review_cards(user_id, morpheme_id, ease, interval_days, due_at, reps, lapses)
review_logs(user_id, card_id, grade, reviewed_at)
```

- **平台分流**：網頁版加入瀏覽器擴充功能（content script 反白查詢）；Android 版加入桌面 Widget 與個人化推播提醒。

## 本地執行

```bash
open index.html        # macOS；或直接把檔案拖進瀏覽器
```
