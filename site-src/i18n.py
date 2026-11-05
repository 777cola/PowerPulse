# -*- coding: utf-8 -*-
"""PowerPulse 官网四语内容（简 / 繁 / 粵 / EN）。"""

K = {}

def add(key, zh=None, hant=None, yue=None, en=None, alt=None):
    K[key] = {"zh": zh, "hant": hant, "yue": yue, "en": en, "alt": alt}

# ── 通用 ──
add("skip", "跳到主要内容", "跳到主要內容", "跳去主要內容", "Skip to content")
add("nav_panels", "面板", "面板", "面板", "Panels")
add("nav_anatomy", "解剖图", "解剖圖", "解剖圖", "Anatomy")
add("nav_features", "特性", "特性", "特性", "Features")
add("nav_inside", "实现", "實作", "原理", "Inside")
add("nav_dl", "下载", "下載", "下載", "Download")
add("foot_feedback", "反馈", "回報問題", "回報問題", "Issues")

# ── Hero ──
add("title", "PowerPulse — macOS 菜单栏工具 · 2.1.7",
    "PowerPulse — macOS 選單列工具 · 2.1.7",
    "PowerPulse — macOS 選單列工具 · 2.1.7",
    "PowerPulse — a macOS menu bar utility · 2.1.7")
add("meta_desc",
    "每秒采样一次，把墙插输出、系统功耗、电池充电功率拆开显示。插上充电器那一刻，就知道这套充电套装到底跑了多少。",
    "每秒取樣一次，把牆插輸出、系統功耗、電池充電功率拆開顯示。插上充電器那一刻，就知道這套充電組合到底跑了多少。",
    "每秒取樣一次，將牆插輸出、系統功耗、電池充電功率分開顯示。插上充電器嗰一刻，就知呢套充電組合實際跑咗幾多。",
    "One sample a second: wall power, system draw and charge power shown apart. The moment you plug in, you can see what the whole setup is really pulling.")
add("eyebrow", "macOS 菜单栏工具 · 2.1.7", "macOS 選單列工具 · 2.1.7",
    "macOS 選單列工具 · 2.1.7", "macOS menu bar utility · 2.1.7")
add("h1_1", "菜单栏里，", "選單列裡，", "選單列入面，", "Every watt,")
add("h1_2", "看清每一瓦。", "看清每一瓦。", "每一瓦都睇得清。", "right in the menu bar.")
add("hero_sub",
    "每秒采样一次，把墙插输出、系统功耗、电池充电功率拆开显示。插上充电器那一刻，就知道这套充电套装到底跑了多少。",
    "每秒取樣一次，把牆插輸出、系統功耗、電池充電功率拆開顯示。插上充電器那一刻，就知道這套充電組合到底跑了多少。",
    "每秒取樣一次，將牆插輸出、系統功耗、電池充電功率分開顯示。一插上充電器，就知成套充電組合實際跑緊幾多。",
    "One sample a second. Wall power, system draw and charge power kept as three numbers that have to add up — so you can see what your charger is really delivering.")
add("cta_dl", "下载 macOS 版", "下載 macOS 版", "下載 macOS 版", "Download for macOS")
add("cta_src", "查看源码", "檢視原始碼", "睇原始碼", "View source")
add("chip1", "MIT 开源", "MIT 開源", "MIT 開源", "MIT licensed")
add("chip2", "无账号、无上传", "無帳號、不上傳", "唔使帳號、唔會上傳", "No account, no uploads")
add("chip3", "macOS 14+", "macOS 14+", "macOS 14+", "macOS 14+")
add("cap_left", "实时 · 每秒采样", "即時 · 每秒取樣", "即時 · 每秒取樣", "Live · 1 s sampling")
add("cap_right", "Apple Silicon", "Apple Silicon", "Apple Silicon", "Apple Silicon · macOS 14+")

# ── 01 面板 ──
add("s1_h2", "五个面板，只回答一件事：这些数字对不对得上。",
    "五個面板，只回答一件事：這些數字對不對得上。",
    "五個面板，只答一個問題：啲數對唔對得上。",
    "Five panels. One question: do the numbers add up?")
add("s1_p",
    "墙插给了多少、系统吃了多少、电池进了多少，三笔必须能互相加减。对不上，就说明有地方在偷偷耗电。",
    "牆插給了多少、系統吃了多少、電池進了多少，三筆必須能互相加減。對不上，就代表有地方在偷偷耗電。",
    "牆插俾咗幾多、系統食咗幾多、電池入咗幾多，三筆數一定要加得埋。對唔上，即係有嘢喺背後偷偷食電。",
    "What the wall gives, what the system takes, what the battery gets — three figures that have to reconcile. When they don't, something is quietly drawing power.")
add("tab_a", "功率流", "功率流", "功率流", "Power flow")
add("tab_b", "系统监控", "系統監控", "系統監控", "System")
add("tab_c", "充电历史", "充電歷史", "充電歷史", "History")
add("tab_d", "充电器", "充電器", "充電器", "Charger")
add("tab_e", "设置", "設定", "設定", "Settings")

add("t1_h3", "功率流", "功率流", "功率流", "Power flow")
add("t1_p",
    "从墙插到电池，一条带子说清楚。粗细跟着瓦数走：充电时充电器分成系统与电池两路；充电器不够用时，充电器和电池一起喂系统。",
    "從牆插到電池，一條帶子說清楚。粗細跟著瓦數走：充電時充電器分成系統與電池兩路；充電器不夠用時，充電器和電池一起餵系統。",
    "由牆插到電池，一條帶睇晒。粗細跟住瓦數走：充電嗰陣充電器分兩路，一路餵系統一路餵電池；充電器唔夠力，就同電池一齊餵系統。",
    "A single band from the wall to the battery tells the whole story, and its thickness tracks the wattage. While charging it splits two ways, system and battery; when the charger can't keep up, the battery helps feed the system.")
add("t1_f1", "三个节点：墙插、系统、电池", "三個節點：牆插、系統、電池", "三個節點：牆插、系統、電池",
    "Three nodes: wall, system, battery")
add("t1_f2", "带子粗细按 0.7 次方压缩，低功率也看得出差别",
    "帶子粗細按 0.7 次方壓縮，低功率也看得出差別", "帶嘅粗細用 0.7 次方壓縮，低功率都分得出",
    "Band width uses a 0.7 power curve, so low wattages still read")
add("t1_f3", "末端的箭头标明能量方向", "末端的箭頭標明能量方向", "末端嘅箭嘴標明能量方向",
    "Arrows at either end show which way the power flows")

add("t2_h3", "系统监控", "系統監控", "系統監控", "System")
add("t2_p",
    "CPU、GPU、内存占用，加上一份按能耗排序的进程榜。",
    "CPU、GPU、記憶體佔用，加上一份依能耗排序的程序榜。",
    "CPU、GPU、記憶體佔用，再加一份按能耗排嘅程序榜。",
    "CPU, GPU and memory load, plus a process list ranked by energy.")
add("t2_f1", "CPU / GPU / 内存三项实时曲线", "CPU / GPU / 記憶體三項即時曲線", "CPU / GPU / 記憶體三條即時曲線",
    "Live curves for CPU, GPU and memory")
add("t2_f2", "进程榜读 rusage_info_v6，不需要 root", "程序榜讀 rusage_info_v6，不需要 root",
    "程序榜讀 rusage_info_v6，唔使 root", "The process list reads rusage_info_v6 — no root")
add("t2_f3", "能耗按差分成瓦显示", "能耗以差分換算成瓦數顯示", "能耗用差分計，直接出瓦數",
    "Energy differenced into watts")

add("t3_h3", "充电历史", "充電歷史", "充電歷史", "History")
add("t3_p",
    "最近一次充进去多少 Wh，近一周每天多少，一条 CSV 导出。",
    "最近一次充進去多少 Wh、近一週每天多少，一鍵匯出 CSV。",
    "上次充咗幾多 Wh、呢個禮拜每日幾多，仲有一鍵匯出 CSV。",
    "How much went in last time in Wh, how much each day this week, and a one-click CSV export.")
add("t3_f1", "SQLite 落盘，跨天不丢", "SQLite 寫入磁碟，跨日不遺失", "SQLite 寫落磁碟，過咗午夜都唔會唔見",
    "Written straight to SQLite — nothing lost at midnight")
add("t3_f2", "最近一次充电结束后仍然保留", "最近一次充電結束後仍然保留", "拔咗線之後，上次充電紀錄照樣留住",
    "The last session stays after you unplug")
add("t3_f3", "导出失败会直接说原因，不会假装成功", "匯出失敗會直接說明原因，不會假裝成功",
    "匯出失敗會講明原因，唔會扮成功", "A failed export says why — it never fakes success")

add("t4_h3", "充电器", "充電器", "充電器", "Charger")
add("t4_p",
    "协商到几伏几安、支持哪些 PD 档位、为什么没跑满。",
    "協商到幾伏幾安、支援哪些 PD 檔位、為什麼沒跑滿。",
    "傾到幾多伏幾多安、支援邊幾個 PD 檔位、點解跑唔滿。",
    "The volts and amps it negotiated, which PD tiers it offers, and why it isn't running flat out.")
add("t4_f1", "读出厂商与型号（部分充电器不上报）", "讀出廠商與型號（部分充電器不上報）",
    "讀到廠商同型號（有啲充電器唔上報）", "Vendor and model (not every charger reports them)")
add("t4_f2", "PD 档位表标出当前使用的那一档", "PD 檔位表標出目前使用的那一檔", "PD 檔位表會標出而家用緊邊一檔",
    "The PD table marks the tier in use")
add("t4_f3", "跑不满时给结论：涓流、温控、还是线材", "跑不滿時給結論：涓流、溫控，還是線材",
    "跑唔滿會俾結論：涓流、過熱保護，定係線材問題", "When it falls short you get a reason: trickle, thermal, or the cable")

add("t5_h3", "设置", "設定", "設定", "Settings")
add("t5_p",
    "采样间隔、历史保留、通知阈值、菜单栏显示与语言。",
    "取樣間隔、歷史保留、通知閾值、選單列顯示與語言。",
    "取樣間隔、歷史保留、通知門檻、選單列顯示同語言。",
    "Sample interval, history retention, alert thresholds, what the menu bar shows, and language.")
add("t5_f1", "菜单栏可显示图标 + 百分比 + 功率", "選單列可顯示圖示 + 百分比 + 功率",
    "選單列可以顯示圖示 + 百分比 + 功率", "The menu bar can show icon, percentage and wattage")
add("t5_f2", "低电量、充满、高温、慢充四类通知", "低電量、充滿、高溫、慢充四類通知",
    "低電量、充滿、高溫、慢充四類通知", "Four kinds of alert: low, full, hot, slow")
add("t5_f3", "简体 / 繁體 / English", "簡體 / 繁體 / English", "簡體 / 繁體 / English", "简体 / 繁體 / English")

# ── 02 解剖图 ──
add("s2_h2", "把软件拆成一台机器", "把軟體拆成一台機器", "將個軟件拆開做一部機器", "The software, drawn as a machine")
add("s2_p",
    "测电流的分流器、读数的指针表、走纸记录曲线、每秒跳一格的棘轮、报信的铜铃——每个模块都对应这台仪器上的一个零件。可以直接在图上拖动。",
    "量電流的分流器、讀數的指針錶、走紙記錄曲線、每秒跳一格的棘輪、報信的銅鈴——每個模組都對應這台儀器上的一個零件。可以直接在圖上拖動。",
    "量電流嘅分流器、讀數嘅指針錶、行紙畫曲線嘅記錄儀、每秒跳一格嘅棘輪、有事就響嘅銅鈴——每個模組都對應儀器上面一個零件。圖上面可以直接拖。",
    "A shunt that turns current into a voltage, a needle dial that reads it, a paper recorder that draws the curve, a ratchet that steps once a second, a bell that rings when something is wrong. Every module maps to a part on the bench — and you can drag the load around.")
add("fig_cap", "Fig 1 · 功率实验台 · 可直接交互", "Fig 1 · 功率實驗台 · 可直接互動",
    "Fig 1 · 功率實驗台 · 可以直接玩", "Fig 1 · Power bench · interactive")
add("fig_open", "单独打开 ↗", "單獨開啟 ↗", "自己開嚟睇 ↗", "Open on its own ↗")
add("key1", "橙色的零件在动：指针、笔、锤、每秒一格的棘轮",
    "橘色的零件在動：指針、筆、錘、每秒一格的棘輪",
    "橙色嘅零件喺度郁：指針、筆、錘、每秒跳一格嘅棘輪",
    "Orange parts move: the needle, the pen, the hammer, the ratchet stepping once a second")
add("key2", "分流器和采样线圈：把电流变成毫伏信号送进表盘",
    "分流器與取樣線圈：把電流變成毫伏訊號送進錶盤",
    "分流器同取樣線圈：將電流變成毫伏訊號送入錶盤",
    "Shunt and sampling coil: current becomes millivolts, then a reading")
add("key3", "铸铁台面、支脚、刻度尺与铭牌", "鑄鐵檯面、支腳、刻度尺與銘牌",
    "鑄鐵枱面、腳架、刻度尺同銘牌", "Cast bench plate, feet, rule and name plate")

# ── 03 特性 ──
add("s3_h2", "该有的都有，多的一个不放。", "該有的都有，多的一個不放。",
    "應有嘅都有，多餘嘅一樣都唔要。", "Everything it needs. Nothing it doesn't.")
add("s3_p", "没有账号、没有云同步、没有「猜你喜欢」。数据全部留在本机。",
    "沒有帳號、沒有雲端同步、沒有「猜你喜歡」。資料全部留在本機。",
    "冇帳號、冇雲端同步、冇「猜你喜歡」。啲數據全部留喺部機度。",
    "No account, no cloud sync, no \"you might also like\". The data stays on this Mac.")
add("b1_h3", "一秒一次", "一秒一次", "一秒一次", "Once a second")
add("b1_p", "采样、菜单栏、小组件同一节拍。插拔电源立刻响应，不用等下一个刷新周期。",
    "取樣、選單列、小工具同一個節拍。插拔電源立刻反應，不用等下一個更新週期。",
    "取樣、選單列、小工具同一個節拍。一插一拔即刻有反應，唔使等下一輪。",
    "Sampling, menu bar and widget share one clock. Plug in and it shows up right away, not on the next tick.")
add("b1_tick", "sampling clock", "sampling clock", "sampling clock", "sampling clock")
add("b2_h3", "充电器体检", "充電器體檢", "充電器體檢", "Charger check-up")
add("b2_p", "读得到协商电压电流、PD 档位表、厂商与型号。跑不满时给结论，不给原始码。",
    "讀得到協商電壓電流、PD 檔位表、廠商與型號。跑不滿時給結論，不給原始錯誤碼。",
    "讀得到協商電壓電流、PD 檔位表、廠商同型號。跑唔滿會俾結論，唔會掉個原始錯誤碼你。",
    "Negotiated volts and amps, the PD tier table, vendor and model. When it falls short you get a conclusion, not a raw error code.")
add("b3_h3", "电池健康", "電池健康", "電池健康", "Battery health")
add("b3_p", "循环次数、实际满容量、设计容量、当前温度。", "循環次數、實際滿容量、設計容量、目前溫度。",
    "循環次數、實際滿容量、設計容量、而家嘅溫度。",
    "Cycle count, real full capacity, design capacity, current temperature.")
add("b3_tick", "design capacity", "design capacity", "design capacity", "design capacity")
add("b4_h3", "30 天历史", "30 天歷史", "30 天歷史", "30-day history")
add("b4_p", "SQLite + WAL，按采样间隔逐条记录，定期合并日志。",
    "SQLite + WAL，依取樣間隔逐條記錄，定期合併日誌。",
    "SQLite + WAL，按取樣間隔逐條記，定期合併日誌。",
    "SQLite with WAL, one row per sample, older entries rolled up periodically.")
add("b5_h3", "桌面小组件", "桌面小工具", "桌面小工具", "Desktop widget")
add("b5_p", "不打开面板也能看到当前功率与电量。", "不打開面板也能看到目前功率與電量。",
    "唔開面板都睇到而家嘅功率同電量。", "Current wattage and charge level without opening the panel.")

# ── 04 数据来源 ──
add("s4_h2", "数据从哪来", "資料從哪來", "啲數據邊度嚟", "Where the numbers come from")
add("s4_p", "不猜、不估算，全部读系统自己的寄存器。", "不猜、不估算，全部讀系統自己的暫存器。",
    "唔估、唔靠推算，全部讀系統自己嘅寄存器。",
    "No estimates. Everything is read from the system's own registers.")
add("rows_h1", "模块", "模組", "模組", "Module")
add("rows_h2", "怎么读到的", "怎麼讀到的", "點讀返嚟", "How it's read")
add("r1_dt", "电源与电池", "電源與電池", "電源同電池", "Power &amp; battery")
add("r1_dd", "IOKit 的 <code>AppleSmartBattery</code>：瞬时功率、电压电流、循环次数、温度",
    "IOKit 的 <code>AppleSmartBattery</code>：瞬時功率、電壓電流、循環次數、溫度",
    "IOKit 嘅 <code>AppleSmartBattery</code>：瞬時功率、電壓電流、循環次數、溫度",
    "IOKit's <code>AppleSmartBattery</code>: instantaneous power, volts and amps, cycle count, temperature")
add("r2_dt", "充电器", "充電器", "充電器", "Charger")
add("r2_dd", "<code>AdapterDetails</code> 与 <code>UsbHvcMenu</code>：协商档位、PD 能力表、厂商型号",
    "<code>AdapterDetails</code> 與 <code>UsbHvcMenu</code>：協商檔位、PD 能力表、廠商型號",
    "<code>AdapterDetails</code> 同 <code>UsbHvcMenu</code>：協商檔位、PD 能力表、廠商型號",
    "<code>AdapterDetails</code> and <code>UsbHvcMenu</code>: negotiated tier, PD capability list, vendor and model")
add("r3_dt", "进程能耗", "程序能耗", "程序能耗", "Per-process energy")
add("r3_dd", "<code>rusage_info_v6</code> 的 <code>ri_energy_nj</code> 差分，不需要 root",
    "<code>rusage_info_v6</code> 的 <code>ri_energy_nj</code> 差分，不需要 root",
    "<code>rusage_info_v6</code> 嘅 <code>ri_energy_nj</code> 差分，唔使 root",
    "<code>ri_energy_nj</code> from <code>rusage_info_v6</code>, differenced — no root needed")
add("r4_dt", "历史", "歷史", "歷史", "History")
add("r4_dd", "SQLite + WAL，按采样间隔逐条记录，启动时合并日志",
    "SQLite + WAL，依取樣間隔逐條記錄，啟動時合併日誌",
    "SQLite + WAL，按取樣間隔逐條記，開機時合併日誌",
    "SQLite with WAL, one row per sample, logs merged on launch")
add("r5_dt", "界面", "介面", "介面", "Rendering")
add("r5_dd", "纯 AppKit 手绘，玻璃弹窗和功率流都是 <code>draw(_:)</code> 画的",
    "純 AppKit 手繪，玻璃彈窗和功率流都是 <code>draw(_:)</code> 畫的",
    "純 AppKit 手繪，玻璃彈出視窗同功率流都係 <code>draw(_:)</code> 畫",
    "Pure AppKit. The glass popover and the flow diagram are both drawn in <code>draw(_:)</code>")
add("r6_dt", "小组件", "小工具", "小工具", "Widget")
add("r6_dd", "WidgetKit，通过 App Group 读主程序写下的快照",
    "WidgetKit，透過 App Group 讀主程式寫下的快照",
    "WidgetKit，經 App Group 讀主程式寫落嘅快照",
    "WidgetKit, reading a snapshot the app writes into an App Group")
add("side_h3", "它自己也得省电", "它自己也得省電", "佢自己都要慳電", "It has to be frugal too")
add("side_dt1", "空闲 CPU", "閒置 CPU", "閒置 CPU", "Idle CPU")
add("side_dt2", "内存", "記憶體", "記憶體", "Memory")
add("side_dt3", "展开功率流", "展開功率流", "開住功率流", "Flow page open")
add("side_dt4", "采样", "取樣", "取樣", "Sampling")
add("side_note", "纯 AppKit 写成，没有 SwiftUI、没有第三方依赖。一个测电源的软件，自己先不能费电。",
    "純 AppKit 寫成，沒有 SwiftUI、沒有第三方依賴。一個測電源的軟體，自己先不能費電。",
    "純 AppKit 寫成，冇 SwiftUI、冇第三方依賴。一個測電源嘅軟件，自己首先唔可以食電。",
    "Pure AppKit — no SwiftUI, no third-party dependencies. A power monitor shouldn't be the thing draining your battery.")

# ── 下载 ──
add("dl_h2", "装上，就一直在菜单栏里", "裝上，就一直在選單列裡", "裝咗之後，就一直喺選單列",
    "Install once, live in the menu bar")
add("dl_p", "免安装器，拖进「应用程序」即可。没有 Apple 公证，首次打开会被系统拦一次。",
    "免安裝器，拖進「應用程式」即可。沒有 Apple 公證，首次開啟會被系統攔一次。",
    "免安裝器，拖入「應用程式」就得。冇 Apple 公證，第一次開系統會攔你一次。",
    "No installer — drag it into Applications. The build isn't notarized, so macOS blocks the first launch once.")
add("dl_note", "笔记本看电池与充电；台式机（Mac Studio / mini / Pro）没有电池，整机功率从 SMC 读。<br>ad-hoc 签名、未公证：首次打开若被拦，去「系统设置 → 隐私与安全性 → 仍要打开」。",
    "筆電看電池與充電；桌上型（Mac Studio / mini / Pro）沒有電池，整機功率從 SMC 讀。<br>ad-hoc 簽章、未公證：首次開啟若被攔，去「系統設定 → 隱私權與安全性 → 仍要打開」。",
    "筆記本睇電池同充電；桌面機（Mac Studio / mini / Pro）冇電池，整機功率由 SMC 讀。<br>ad-hoc 簽名、未公證：首次打開如果被攔，去「系統設定 → 私隱與安全性 → 仍要開啟」。",
    "Laptops show the battery and charging; desktops (Mac Studio / mini / Pro) have no battery, so total draw comes from the SMC.<br>Ad-hoc signed, not notarized: if the first launch is blocked, allow it in System Settings → Privacy &amp; Security.")
add("dl_cmd", "或一行装好，终端下载不带隔离标记，不会弹窗：",
    "或一行裝好，終端機下載不帶隔離標記，不會彈窗：",
    "或者一行搞好，終端下載唔帶隔離標記，唔會彈窗：",
    "Or install it in one line — Terminal downloads carry no quarantine flag, so nothing pops up:")
add("dl_btn", "下载 2.1.7", "下載 2.1.7", "下載 2.1.7", "Download 2.1.7")
add("build_summary", "从源码构建", "從原始碼建置", "由原始碼建置", "Build from source")
add("build_c1", "# 需要 macOS 14+ 与命令行工具", "# 需要 macOS 14+ 與命令列工具",
    "# 需要 macOS 14+ 同命令列工具", "# needs macOS 14+ and the command line tools")
add("build_c2", "# 产出 PowerPulse.app 与小组件", "# 產出 PowerPulse.app 與小工具",
    "# 產出 PowerPulse.app 同小工具", "# produces PowerPulse.app and the widget")

# 台湾说法：墙插 → 壁插
for _v in K.values():
    _v["hant"] = _v["hant"].replace("牆插", "壁插")

LANGS = ["zh", "hant", "yue", "en"]
for key, val in K.items():
    for lang in LANGS:
        assert val[lang] is not None, (key, lang)
