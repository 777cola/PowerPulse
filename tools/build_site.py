#!/usr/bin/env python3
"""生成 PowerPulse 官网（中文 / English 两个静态页）。

一份模板 → docs/index.html + docs/en/index.html，两边样式与结构完全一致，
只有文案不同。跑法：python3 tools/build_site.py
"""
import io, os, pathlib

# 版本与包体积只在这里改一处
SITE_VER = "2.1.0"
ZIP_KB = "658"

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"

CSS = r"""
*,*::before,*::after{box-sizing:border-box}
:root{
  --paper:#f5f8fc; --paper2:#eaf1fa; --surface:#fff;
  --ink:#0b1a2b; --ink2:#2f4359; --muted:#64748b;
  --blue:#1A4B8C; --blue-deep:#123a6e; --blue-soft:#e7effa;
  --orange:#E86C00; --green:#0f8a4a;
  --line:rgba(11,26,43,.10); --line-soft:rgba(11,26,43,.06);
  --shadow-s:0 1px 2px rgba(11,26,43,.05);
  --shadow-m:0 20px 46px -26px rgba(12,38,80,.34);
  --shadow-l:0 46px 96px -48px rgba(12,38,80,.46);
  --r-s:10px; --r-m:16px; --r-l:24px;
  --mono:ui-monospace,"SF Mono",SFMono-Regular,Menlo,monospace;
  --sans:-apple-system,BlinkMacSystemFont,"SF Pro Text","PingFang SC","Noto Sans SC","Helvetica Neue",Arial,sans-serif;
}
html{-webkit-text-size-adjust:100%}
body{
  margin:0;background:var(--paper);color:var(--ink);font-family:var(--sans);
  font-size:16px;line-height:1.6;-webkit-font-smoothing:antialiased;
  text-rendering:optimizeLegibility;
}
img{max-width:100%;display:block}
a{color:inherit;text-decoration:none}
::selection{background:#cfe0f5}
:focus-visible{outline:2px solid var(--blue);outline-offset:3px;border-radius:6px}
.skip{position:absolute;left:-9999px}
.skip:focus{left:18px;top:14px;z-index:90;background:#fff;padding:9px 15px;border-radius:var(--r-s);box-shadow:var(--shadow-m)}
.wrap{width:min(1120px,calc(100% - 44px));margin-inline:auto}

/* ---------- nav ---------- */
.nav{position:sticky;top:0;z-index:50;background:rgba(245,248,252,.82);
  backdrop-filter:saturate(180%) blur(14px);border-bottom:1px solid var(--line-soft)}
.nav-in{display:flex;align-items:center;gap:26px;height:62px}
.brand{display:flex;align-items:center;gap:9px;font-weight:650;letter-spacing:-.015em;font-size:15px}
.brand img{width:24px;height:24px;border-radius:6px}
.nav-links{display:flex;gap:22px;margin-left:auto;font-size:14px;color:var(--ink2)}
.nav-links a{position:relative;padding:4px 0;transition:color .16s ease}
.nav-links a:hover{color:var(--blue)}
.nav-links a::after{content:"";position:absolute;left:0;right:100%;bottom:0;height:1.5px;
  background:var(--blue);transition:right .22s cubic-bezier(.22,.7,.3,1)}
.nav-links a:hover::after{right:0}
.nav-actions{display:flex;align-items:center;gap:12px;margin-left:20px}
.lang{display:flex;align-items:center;border:1px solid var(--line);border-radius:999px;
  padding:2px;background:#fff;font-size:12.5px;box-shadow:var(--shadow-s)}
.lang a{padding:4px 10px;border-radius:999px;color:var(--muted);transition:.16s ease;line-height:1.3}
.lang a.on{background:var(--blue);color:#fff;font-weight:600}
.btn{display:inline-flex;align-items:center;gap:8px;border-radius:999px;font-weight:600;
  font-size:14px;padding:9px 18px;border:1px solid transparent;transition:transform .15s ease,box-shadow .18s ease,background .16s ease}
.btn:active{transform:translateY(1px)}
.btn-primary{background:var(--blue);color:#fff;box-shadow:0 10px 26px -14px rgba(26,75,140,.9)}
.btn-primary:hover{background:var(--blue-deep);box-shadow:0 16px 32px -16px rgba(26,75,140,.95)}
.btn-ghost{background:#fff;border-color:var(--line);color:var(--ink);box-shadow:var(--shadow-s)}
.btn-ghost:hover{border-color:rgba(26,75,140,.32);color:var(--blue)}

/* ---------- hero ---------- */
.hero{display:grid;grid-template-columns:minmax(0,1.04fr) minmax(0,1fr);
  gap:clamp(30px,4.6vw,64px);align-items:center;
  padding:clamp(44px,6vw,84px) 0 clamp(38px,5vw,66px)}
.eyebrow{display:inline-flex;align-items:center;gap:8px;font-size:12.5px;color:var(--ink2);
  background:#fff;border:1px solid var(--line);border-radius:999px;padding:5px 12px 5px 9px;
  box-shadow:var(--shadow-s);letter-spacing:.01em}
.dot{width:6px;height:6px;border-radius:50%;background:var(--green);box-shadow:0 0 0 3px rgba(15,138,74,.14)}
h1{margin:20px 0 0;font-size:clamp(38px,4.6vw,60px);line-height:1.02;letter-spacing:-.036em;
  font-weight:680;text-wrap:balance}
h1 em{font-style:normal;color:var(--blue)}
h1 .ln{display:block}
html[lang="zh-CN"] h1 .ln{white-space:nowrap}
html[lang=en] h1{font-size:clamp(32px,3.9vw,50px)}
.nav-dl{padding:7px 15px;font-size:13.5px}
.hero-sub{margin:18px 0 0;max-width:31em;color:var(--ink2);font-size:clamp(15px,1.15vw,16.5px);line-height:1.68}
.hero-cta{display:flex;gap:12px;margin-top:26px;flex-wrap:wrap}
.hero-cta .btn{padding:11px 22px;font-size:14.5px}
.chips{display:flex;gap:18px;margin-top:26px;flex-wrap:wrap;font-size:13px;color:var(--muted)}
.chips span{display:inline-flex;align-items:center;gap:6px}
.chips svg{width:13px;height:13px;color:var(--green);flex:none}

/* 右侧：菜单栏 + 弹窗 */
.visual{position:relative}
.menubar{display:flex;align-items:center;gap:14px;padding:0 14px;height:34px;
  background:linear-gradient(#fbfcfe,#f1f5fa);border:1px solid var(--line);
  border-radius:var(--r-m) var(--r-m) 0 0;border-bottom:0;color:rgba(11,26,43,.55);font-size:12.5px}
.menubar .apple{font-size:14px;color:rgba(11,26,43,.62)}
.menubar .spacer{margin-left:auto}
.menubar svg{width:15px;height:15px}
.menubar img{height:22px;width:auto}
.shot{position:relative;border:1px solid rgba(11,26,43,.16);border-top:0;border-radius:0 0 var(--r-l) var(--r-l);
  overflow:hidden;background:#0d1117;box-shadow:var(--shadow-l)}
.shot img{width:100%;height:auto}
.visual::after{content:"";position:absolute;top:26px;right:26px;width:18px;height:10px;
  background:#0d1117;clip-path:polygon(50% 0,100% 100%,0 100%);z-index:3;pointer-events:none}
.caption{margin:10px 2px 0;font-size:12px;color:#55677e;display:flex;justify-content:space-between}

/* ---------- section frame ---------- */
.sec{padding:clamp(52px,7vw,96px) 0;border-top:1px solid var(--line-soft)}
.sec-head{display:flex;align-items:baseline;gap:18px;margin-bottom:clamp(24px,3vw,40px)}
.num{font-family:var(--mono);font-size:12px;color:var(--blue);letter-spacing:.14em;padding-top:6px}
.sec-head h2{margin:0;font-size:clamp(25px,2.7vw,36px);line-height:1.14;letter-spacing:-.028em;
  font-weight:660;text-wrap:balance}
.sec-head p{margin:8px 0 0;color:var(--muted);font-size:14.5px;max-width:46em}

/* ---------- 面板切换（纯 CSS，无 JS） ---------- */
.tabs{position:relative}
.tabs input{position:absolute;opacity:0;pointer-events:none}
.tabs-bar{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:22px}
.tabs-bar label{cursor:pointer;font-size:13.5px;color:var(--ink2);padding:8px 15px;border-radius:999px;
  border:1px solid var(--line);background:#fff;transition:.16s ease;user-select:none;box-shadow:var(--shadow-s)}
.tabs-bar label:hover{color:var(--blue);border-color:rgba(26,75,140,.3)}
.tab-p{display:none;grid-template-columns:minmax(0,1.08fr) minmax(0,.92fr);
  gap:clamp(24px,3.4vw,52px);align-items:center}
#p1:checked~.tabs-bar label[for=p1],#p2:checked~.tabs-bar label[for=p2],
#p3:checked~.tabs-bar label[for=p3],#p4:checked~.tabs-bar label[for=p4],
#p5:checked~.tabs-bar label[for=p5]{background:var(--blue);color:#fff;border-color:var(--blue);
  box-shadow:0 10px 24px -16px rgba(26,75,140,.9)}
#p1:checked~.tabs-body .tab-p[data-i="1"],#p2:checked~.tabs-body .tab-p[data-i="2"],
#p3:checked~.tabs-body .tab-p[data-i="3"],#p4:checked~.tabs-body .tab-p[data-i="4"],
#p5:checked~.tabs-body .tab-p[data-i="5"]{display:grid}
.tab-shot{margin:0;border-radius:var(--r-m);overflow:hidden;background:#0d1117;
  border:1px solid rgba(11,26,43,.14);box-shadow:var(--shadow-m)}
.tab-shot img{width:100%;height:auto}
.tab-copy h3{margin:0;font-size:20px;letter-spacing:-.02em;font-weight:640}
.tab-copy p{margin:9px 0 0;color:var(--ink2);font-size:14.5px;line-height:1.7}
.facts{list-style:none;margin:18px 0 0;padding:0;display:grid;gap:9px}
.facts li{display:flex;gap:9px;font-size:13.5px;color:var(--ink2);line-height:1.55}
.facts li::before{content:"";flex:none;width:5px;height:5px;margin-top:8px;border-radius:50%;background:var(--blue);opacity:.5}

/* ---------- 解剖图（嵌入） ---------- */
.anatomy{border:1px solid var(--line);border-radius:var(--r-l);background:#fff;
  box-shadow:var(--shadow-m);overflow:hidden}
.anatomy iframe{display:block;width:100%;height:880px;border:0;background:#fff}
.anatomy-foot{display:flex;justify-content:space-between;gap:20px;padding:14px 20px;
  border-top:1px solid var(--line-soft);font-size:12.5px;color:var(--muted);background:linear-gradient(#fff,#fafcfe)}
.anatomy-foot a{color:var(--blue);font-weight:600}
.keys{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin-top:20px}
.key{display:flex;gap:10px;font-size:13px;color:var(--ink2);line-height:1.55}
.key i{flex:none;width:9px;height:9px;margin-top:7px;border-radius:2px}
.key i.k1{background:var(--orange)}
.key i.k2{background:var(--blue)}
.key i.k3{background:#b9c9dc}

/* ---------- bento ---------- */
.bento{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:14px}
.cell{background:#fff;border:1px solid var(--line);border-radius:var(--r-m);padding:22px;
  box-shadow:var(--shadow-s);display:flex;flex-direction:column;gap:8px}
.cell h3{margin:0;font-size:15.5px;font-weight:640;letter-spacing:-.012em}
.cell p{margin:0;color:var(--muted);font-size:13.5px;line-height:1.62}
.cell.w3{grid-column:span 3}
.cell.w2{grid-column:span 2}
.cell.tint{background:linear-gradient(160deg,#fbfdff,#eef4fc);border-color:rgba(26,75,140,.16)}
.pill-row{display:flex;gap:6px;flex-wrap:wrap;margin-top:auto;padding-top:12px}
.pill{font-family:var(--mono);font-size:11.5px;color:var(--blue);background:var(--blue-soft);
  border-radius:6px;padding:3px 7px}
.pill.now{background:var(--green);color:#fff}
.tick{display:flex;align-items:center;gap:8px;margin-top:auto;padding-top:12px;font-size:12.5px;color:var(--ink2)}
.tick b{font-weight:640;color:var(--ink)}
.bar{height:5px;border-radius:99px;background:var(--paper2);overflow:hidden;margin-top:auto}
.bar i{display:block;height:100%;width:92.9%;border-radius:99px;
  background:linear-gradient(90deg,var(--blue),#3f7fc4)}

/* ---------- 数据表 ---------- */
.specs{display:grid;grid-template-columns:minmax(0,1.25fr) minmax(0,.75fr);gap:clamp(24px,3.4vw,56px)}
.rows{margin:0;border-top:1px solid var(--line-soft)}
.rows div{display:grid;grid-template-columns:132px minmax(0,1fr);gap:16px;padding:13px 0;
  border-bottom:1px solid var(--line-soft);align-items:baseline}
.rows dt{margin:0;font-size:13px;color:var(--muted)}
.rows dd{margin:0;font-size:13.5px;color:var(--ink2);line-height:1.62}
code{font-family:var(--mono);font-size:.92em;background:var(--blue-soft);color:var(--blue-deep);
  padding:1.5px 5px;border-radius:5px}
.side{padding:22px;background:#fff;border:1px solid var(--line);border-radius:var(--r-m);box-shadow:var(--shadow-s)}
.side h3{margin:0 0 10px;font-size:14px;letter-spacing:.01em;color:var(--muted);font-weight:600}
.side dl{margin:0;display:grid;gap:11px}
.side dl div{display:flex;justify-content:space-between;gap:12px;font-size:13.5px}
.side dt{color:var(--muted)}
.side dd{margin:0;font-weight:620;font-variant-numeric:tabular-nums}
.side .note{margin:14px 0 0;font-size:12.5px;color:var(--muted);line-height:1.6}
.rows-wrap{border-top:1px solid var(--line)}
.rows-head{display:grid;grid-template-columns:132px minmax(0,1fr);gap:16px;padding:10px 0;
  font-size:11.5px;letter-spacing:.08em;text-transform:uppercase;color:#8395a8;
  border-bottom:1px solid var(--line-soft)}
.rows{border-top:0}
.build{margin-top:14px;background:#fff;border:1px solid var(--line);border-radius:var(--r-m);
  box-shadow:var(--shadow-s);overflow:hidden}
.build summary{cursor:pointer;padding:13px 18px;font-size:13.5px;font-weight:600;color:var(--ink2);
  list-style:none;display:flex;align-items:center;gap:8px}
.build summary::-webkit-details-marker{display:none}
.build summary::before{content:"›";font-size:16px;color:var(--muted);transition:transform .18s ease}
.build[open] summary::before{transform:rotate(90deg)}
.build summary:hover{color:var(--blue)}
.build pre{margin:0;border-radius:0;font-size:12px;padding:14px 18px}
pre{margin:14px 0 0;padding:14px 16px;background:#0d1522;color:#dbe7f5;border-radius:var(--r-s);
  overflow-x:auto;font-family:var(--mono);font-size:12px;line-height:1.75}
pre .u{color:#9fc2ea}
pre .c{color:#7f93ad}

/* ---------- 下载 ---------- */
.dl{display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:26px;align-items:center;
  padding:clamp(24px,3vw,34px) clamp(24px,3vw,34px) calc(clamp(24px,3vw,34px) + 6px);
  background:#fff;border:1px solid var(--line);border-radius:var(--r-l);
  box-shadow:var(--shadow-m)}
.dl img{width:76px;height:76px;border-radius:18px;box-shadow:var(--shadow-m)}
.dl h2{margin:0;font-size:clamp(20px,2.2vw,26px);letter-spacing:-.022em;font-weight:650}
.dl p{margin:7px 0 0;color:var(--muted);font-size:13.5px;line-height:1.6;max-width:44em}
.dl-note{margin-top:9px!important;font-size:12.5px!important;color:var(--muted);opacity:.85}
.dl-cmd{margin-top:11px;display:grid;gap:5px}
.dl-cmd span{font-size:12.5px;color:var(--muted)}
.dl-cmd code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;line-height:1.55;
  color:var(--ink2);background:var(--paper2);border:1px solid var(--line);border-radius:7px;
  padding:8px 10px;overflow-wrap:anywhere;user-select:all}
.meta{display:flex;gap:9px;flex-wrap:wrap;margin-top:12px;font-size:12px;color:#5b6d82;font-family:var(--mono)}
.meta .sep{opacity:.45}
.dl-cta{min-width:0}
.dl-cta{display:flex;flex-direction:column;gap:9px;min-width:186px}
.dl-cta .btn{justify-content:center}

/* ---------- footer ---------- */
.foot{border-top:1px solid var(--line-soft);padding:26px 0 40px;color:var(--muted);font-size:12.5px}
.foot-in{display:flex;align-items:center;gap:16px;flex-wrap:wrap}
.foot-in .brand{font-size:13.5px;color:var(--ink2)}
.foot-links{display:flex;gap:18px;margin-left:auto}
.foot-links a:hover{color:var(--blue)}

/* ---------- 响应式 ---------- */
@media (max-width:900px){
  .hero{grid-template-columns:minmax(0,1fr);gap:34px;padding-top:36px}
  .tab-p{grid-template-columns:minmax(0,1fr);gap:20px}
  .specs{grid-template-columns:minmax(0,1fr)}
  .keys{grid-template-columns:minmax(0,1fr)}
  .cell.w3,.cell.w2{grid-column:span 6}
  .dl{grid-template-columns:auto minmax(0,1fr);gap:18px}
  .dl-cta{grid-column:1/-1;flex-direction:row}
  .dl-cta .btn{flex:1}
  .nav-links{display:none}
  .anatomy iframe{height:760px}
}
@media (max-width:560px){
  .wrap{width:calc(100% - 32px)}
  h1{font-size:clamp(32px,8.4vw,40px)}
  .hero-sub{font-size:15px}
  .tabs-bar{flex-wrap:nowrap;overflow-x:auto;padding-bottom:4px;-webkit-overflow-scrolling:touch;
    scrollbar-width:none;mask-image:linear-gradient(90deg,#000 88%,transparent)}
  .tabs-bar::-webkit-scrollbar{display:none}
  .tabs-bar label{flex:none}
  .rows div{grid-template-columns:minmax(0,1fr);gap:3px}
  .anatomy iframe{height:720px}
  .anatomy-foot{flex-direction:column;gap:6px}
  .dl{grid-template-columns:minmax(0,1fr);text-align:left}
  .dl img{width:60px;height:60px}
  .dl-cta{flex-direction:column}
}
@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
@keyframes rise{from{transform:translateY(10px)}to{transform:none}}
.hero>*{animation:rise .7s cubic-bezier(.22,.7,.3,1) both}
.hero.visual-arm{animation-delay:.08s}
"""

ZH = dict(
    code="zh", other="en", other_label="EN", home="index.html",
    nav=[("panels", "面板"), ("anatomy", "解剖图"), ("features", "特性"), ("specs", "实现")],
    cta="下载",
    eyebrow=f"macOS 菜单栏工具 · {SITE_VER}",
    h1=("菜单栏里，", "看清每一瓦。"),
    sub="每秒采样一次，把墙插输出、系统功耗、电池充电功率拆开显示。插上充电器那一刻，就知道这套充电套装到底跑了多少。",
    cta1="下载 macOS 版", cta2="查看源码",
    chips=["MIT 开源", "无账号、无上传", "macOS 14+"],
    p_title="五个面板，只回答一件事：这些数字对不对得上。",
    p_lead="墙插给了多少、系统吃了多少、电池进了多少，三笔必须能互相加减。对不上，就说明有地方在偷偷耗电。",
    panels=[
        ("功率流", "从墙插到电池，一条带子说清楚。粗细跟着瓦数走，充电时自动分成系统与电池两条。",
         ["三个节点：墙插、系统、电池", "带子粗细按 0.7 次方压缩，低功率也看得出差别", "末端的箭头标明能量方向"]),
        ("系统监控", "CPU、GPU、内存占用，加上一份按能耗排序的进程榜。",
         ["CPU / GPU / 内存三项实时曲线", "进程榜读 rusage_info_v6，不需要 root", "能耗按差分成瓦显示"]),
        ("充电历史", "最近一次充进去多少 Wh，近一周每天多少，一条 CSV 导出。",
         ["SQLite 落盘，跨天不丢", "最近一次充电结束后仍然保留", "导出失败会直接说原因，不会假装成功"]),
        ("充电器", "协商到几伏几安、支持哪些 PD 档位、为什么没跑满。",
         ["读出厂商与型号（部分充电器不上报）", "PD 档位表标出当前使用的那一档", "跑不满时给结论：涓流、温控、还是线材"]),
        ("设置", "采样间隔、历史保留、通知阈值、菜单栏显示与语言。",
         ["菜单栏可显示图标 + 百分比 + 功率", "低电量、充满、高温、慢充四类通知", "简体 / 繁體 / English"]),
    ],
    a_title="把软件拆成一台机器",
    a_lead="测电流的分流器、读数的指针表、走纸记录曲线、每秒跳一格的棘轮、报信的铜铃——每个模块都对应这台仪器上的一个零件。可以直接在图上拖动。",
    a_foot_l="Fig 1 · 功率实验台 · 可直接交互",
    a_foot_r="单独打开",
    a_keys=[("橙色的零件在动：指针、笔、锤、每秒一格的棘轮", "k1"),
            ("分流器和采样线圈：把电流变成毫伏信号送进表盘", "k2"),
            ("铸铁台面、支脚、刻度尺与铭牌", "k3")],
    f_title="该有的都有，多的一个不放。",
    f_lead="没有账号、没有云同步、没有「猜你喜欢」。数据全部留在本机。",
    cells=[
        ("w3 tint", "一秒一次", "采样、菜单栏、小组件同一节拍。插拔电源立刻响应，不用等下一个刷新周期。", "tick", "1 s"),
        ("w3", "充电器体检", "读得到协商电压电流、PD 档位表、厂商与型号。跑不满时给结论，不给原始码。", "pills", None),
        ("w2", "电池健康", "循环次数、实际满容量、设计容量、当前温度。", "bar", "92.9%"),
        ("w2", "30 天历史", "SQLite + WAL，按采样间隔逐条记录，定期合并日志。", None, None),
        ("w2", "桌面小组件", "不打开面板也能看到当前功率与电量。", None, None),
    ],
    s_title="数据从哪来",
    s_lead="不猜、不估算，全部读系统自己的寄存器。",
    rows_h1="模块", rows_h2="怎么读到的",
    rows=[("电源与电池", "IOKit 的 <code>AppleSmartBattery</code>：瞬时功率、电压电流、循环次数、温度"),
          ("充电器", "<code>AdapterDetails</code> 与 <code>UsbHvcMenu</code>：协商档位、PD 能力表、厂商型号"),
          ("进程能耗", "<code>rusage_info_v6</code> 的 <code>ri_energy_nj</code> 差分，不需要 root"),
          ("历史", "SQLite + WAL，按采样间隔逐条记录，启动时合并日志"),
          ("界面", "纯 AppKit 手绘，玻璃弹窗和功率流都是 <code>draw(_:)</code> 画的"),
          ("小组件", "WidgetKit，通过 App Group 读主程序写下的快照")],
    perf_title="它自己也得省电",
    perf=[("空闲 CPU", "0.4%"), ("内存", "21 MB"), ("展开功率流", "6%"), ("采样", "1 s")],
    perf_note="纯 AppKit 写成，没有 SwiftUI、没有第三方依赖。一个测电源的软件，自己先不能费电。",
    build_cmd='<span class="c"># 需要 macOS 14+ 与命令行工具</span>\ngit clone https://github.com/777cola/PowerPulse.git\ncd PowerPulse &amp;&amp; ./build_app.sh\n<span class="c"># 产出 PowerPulse.app 与小组件</span>',
    d_title="装上，就一直在菜单栏里",
    d_sub="免安装器，拖进「应用程序」即可。没有 Apple 公证，首次打开会被系统拦一次。",
    d_btn=f"下载 {SITE_VER}", d_src="从源码构建",
    d_note="笔记本看电池与充电；台式机（Mac Studio / mini / Pro）没有电池，只能看系统负载。\nad-hoc 签名、未公证：首次打开若被拦，去「系统设置 → 隐私与安全性 → 仍要打开」。",
    d_cmd_label="或一行装好，终端下载不带隔离标记，不会弹窗：",
    d_cmd='curl -fsSL https://powerpulse.qijunhao.xyz/install.sh | bash',
    d_meta=[f"v{SITE_VER}", ".zip", f"{ZIP_KB} KB", "macOS 14.0+", "Apple Silicon", "MIT"],
    foot="© 2026 AutumnPants · PowerPulse",
    foot_links=[("https://github.com/777cola/PowerPulse", "GitHub"),
                ("https://github.com/777cola/PowerPulse/issues", "反馈"),
                ("https://github.com/777cola/PowerPulse/blob/main/LICENSE", "MIT")],
    facts_head="这个面板看什么",
)

EN = dict(
    code="en", other="", other_label="中文", home="../index.html",
    nav=[("panels", "Panels"), ("anatomy", "Anatomy"), ("features", "Features"), ("specs", "Inside")],
    cta="Download",
    eyebrow=f"macOS menu bar utility · {SITE_VER}",
    h1=("Every watt,", "right in the menu bar."),
    sub="One sample per second. Wall power, system draw and charge power, as three values that must add up — so you can tell what your charger is actually delivering.",
    cta1="Download for macOS", cta2="View source",
    chips=["MIT licensed", "No account, no uploads", "macOS 14+"],
    p_title="Five panels. One question: do the numbers add up?",
    p_lead="What the wall gives, what the system takes, what the battery gets — three lines that must reconcile. When they don't, something is drawing power behind your back.",
    panels=[
        ("Power flow", "One strip from wall to battery. Thickness follows wattage, and it splits into system and battery while charging.",
         ["Three nodes: wall, system, battery", "Thickness uses a 0.7 power curve, so low wattages still read", "Arrows at the ends show direction"]),
        ("System", "CPU, GPU and memory load, plus a process list ranked by energy.",
         ["Live curves for CPU, GPU and memory", "Process ranking reads rusage_info_v6 — no root", "Energy shown in watts, by differencing"]),
        ("History", "How many Wh went in last time, how much each day this week, one CSV export.",
         ["SQLite on disk, survives midnight", "The last session is kept after the cable is pulled", "A failed export says why — it never fakes success"]),
        ("Charger", "Negotiated volts and amps, which PD tiers it offers, and why it isn't running full.",
         ["Vendor and model (not every charger reports them)", "The PD table marks the tier in use", "When it underperforms you get a reason: trickle, thermal, or cable"]),
        ("Settings", "Sample interval, history retention, alert thresholds, menu bar content and language.",
         ["Menu bar can show icon, percentage and wattage", "Four alert types: low, full, hot, slow", "简体 / 繁體 / English"]),
    ],
    a_title="The software, drawn as a machine",
    a_lead="A shunt that turns current into a voltage, a needle dial that reads it, a paper recorder that draws the curve, a ratchet that steps once a second, a bell that rings when something is wrong. Every module maps to a part. You can drag the load on the drawing.",
    a_foot_l="Fig 1 · Power bench · interactive",
    a_foot_r="Open on its own",
    a_keys=[("Orange parts move: needle, pen, hammer, the ratchet stepping once a second", "k1"),
            ("Shunt and sampling coil: current becomes millivolts, then a reading", "k2"),
            ("Cast bench plate, feet, rule and name plate", "k3")],
    f_title="Everything it needs. Nothing it doesn't.",
    f_lead="No account, no cloud sync, no recommendations. The data stays on this Mac.",
    cells=[
        ("w3 tint", "Once a second", "Sampling, menu bar and widget share one clock. Plugging in a charger shows up immediately, not on the next tick.", "tick", "1 s"),
        ("w3", "Charger check-up", "Negotiated volts and amps, the PD tier table, vendor and model. When it underperforms you get a conclusion, not a raw code.", "pills", None),
        ("w2", "Battery health", "Cycle count, real full capacity, design capacity, current temperature.", "bar", "92.9%"),
        ("w2", "30-day history", "SQLite with WAL, one row every 2 s, log merged on launch.", None, None),
        ("w2", "Desktop widget", "Current wattage and charge level without opening the panel.", None, None),
    ],
    s_title="Where the numbers come from",
    s_lead="No estimates. Everything is read from the system's own registers.",
    rows_h1="Module", rows_h2="How it is read",
    rows=[("Power & battery", "IOKit <code>AppleSmartBattery</code>: instantaneous power, volts and amps, cycle count, temperature"),
          ("Charger", "<code>AdapterDetails</code> and <code>UsbHvcMenu</code>: negotiated tier, PD capability list, vendor and model"),
          ("Per-process energy", "<code>ri_energy_nj</code> from <code>rusage_info_v6</code>, differenced — no root needed"),
          ("History", "SQLite with WAL, one row every 2 s, log merged on launch"),
          ("Rendering", "Pure AppKit. The glass popover and the flow diagram are both <code>draw(_:)</code>"),
          ("Widget", "WidgetKit, reading a snapshot the app writes into an App Group")],
    perf_title="It has to be frugal too",
    perf=[("Idle CPU", "0.4%"), ("Memory", "21 MB"), ("Flow page open", "6%"), ("Sampling", "1 s")],
    perf_note="Pure AppKit — no SwiftUI, no third-party dependencies. A power monitor should not be the thing draining your battery.",
    build_cmd='<span class="c"># needs macOS 14+ and the command line tools</span>\ngit clone https://github.com/777cola/PowerPulse.git\ncd PowerPulse &amp;&amp; ./build_app.sh\n<span class="c"># produces PowerPulse.app and the widget</span>',
    d_title="Install once, live in the menu bar",
    d_sub="No installer — drag it into Applications. The build isn't notarized, so the first launch is blocked once.",
    d_btn=f"Download {SITE_VER}", d_src="Build from source",
    d_note="Laptops get battery and charging; desktops (Mac Studio / mini / Pro) have no battery, so only system load.\nAd-hoc signed, not notarized: if Gatekeeper blocks the first launch, allow it in System Settings → Privacy & Security.",
    d_cmd_label="Or install with one line — Terminal downloads carry no quarantine flag, so nothing pops up:",
    d_cmd='curl -fsSL https://powerpulse.qijunhao.xyz/install.sh | bash',
    d_meta=[f"v{SITE_VER}", ".zip", f"{ZIP_KB} KB", "macOS 14.0+", "Apple Silicon", "MIT"],
    foot="© 2026 AutumnPants · PowerPulse",
    foot_links=[("https://github.com/777cola/PowerPulse", "GitHub"),
                ("https://github.com/777cola/PowerPulse/issues", "Issues"),
                ("https://github.com/777cola/PowerPulse/blob/main/LICENSE", "MIT")],
)

RELEASE = "https://github.com/777cola/PowerPulse/releases/latest"
SRC = "https://github.com/777cola/PowerPulse"
SHOTS = ["panel-flow", "panel-monitor", "panel-history", "panel-adapter", "panel-settings"]


def render(c, prefix, other_href, shot_suffix=""):
    nav = "".join(f'<a href="#{i}">{t}</a>' for i, t in c["nav"])
    chips = "".join(
        f'<span><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" '
        f'stroke-linecap="round" stroke-linejoin="round"><path d="M3 8.5l3.2 3.2L13 5"/></svg>{t}</span>'
        for t in c["chips"])

    tabs_in = "".join(f'<input type="radio" name="panel" id="p{i+1}"{" checked" if i==0 else ""}>' for i in range(5))
    tabs_bar = "".join(f'<label for="p{i+1}">{p[0]}</label>' for i, p in enumerate(c["panels"]))
    tabs_body = ""
    for i, (name, desc, facts) in enumerate(c["panels"]):
        fl = "".join(f"<li>{f}</li>" for f in facts)
        tabs_body += f'''
        <article class="tab-p" data-i="{i+1}">
          <figure class="tab-shot"><img src="{prefix}img/{SHOTS[i]}{shot_suffix}.png" width="640" height="932"
            alt="{name}" loading="{'eager' if i==0 else 'lazy'}"></figure>
          <div class="tab-copy">
            <h3>{name}</h3>
            <p>{desc}</p>
            <ul class="facts">{fl}</ul>
          </div>
        </article>'''
    keys = "".join(f'<div class="key"><i class="{k}"></i><span>{t}</span></div>' for t, k in c["a_keys"])

    cells = ""
    for cls, h, p, extra, val in c["cells"]:
        inner = ""
        if extra == "tick":
            inner = f'<div class="tick"><b>{val}</b><span>·</span><span>sampling clock</span></div>'
        elif extra == "pills":
            inner = ('<div class="pill-row"><span class="pill">5V · 3A</span><span class="pill">9V · 3A</span>'
                     '<span class="pill">12V · 3A</span><span class="pill">15V · 3A</span>'
                     '<span class="pill now">20V · 3A</span></div>')
        elif extra == "bar":
            inner = f'<div class="bar"><i></i></div><div class="tick"><b>{val}</b><span>·</span><span>design capacity</span></div>'
        cells += f'<div class="cell {cls}"><h3>{h}</h3><p>{p}</p>{inner}</div>'

    rows = "".join(f"<div><dt>{k}</dt><dd>{v}</dd></div>" for k, v in c["rows"])
    perf = "".join(f"<div><dt>{k}</dt><dd>{v}</dd></div>" for k, v in c["perf"])
    meta = "".join(f"<span>{m}</span>" for m in c["d_meta"])
    foot_links = "".join(f'<a href="{u}">{t}</a>' for u, t in c["foot_links"])

    return f"""<!DOCTYPE html>
<html lang="{'zh-CN' if c['code']=='zh' else 'en'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light">
<title>PowerPulse — {c['eyebrow']}</title>
<meta name="description" content="{c['sub']}">
<meta property="og:title" content="PowerPulse — {c['eyebrow']}">
<meta property="og:description" content="{c['sub']}">
<meta property="og:image" content="https://powerpulse.qijunhao.xyz/img/og.png">
<meta property="og:type" content="website">
<link rel="icon" href="{prefix}img/favicon.png" sizes="32x32">
<link rel="apple-touch-icon" href="{prefix}img/appicon.png">
<style>{CSS}</style>
</head>
<body>
<a class="skip" href="#panels">{'跳到主要内容' if c['code']=='zh' else 'Skip to content'}</a>

<nav class="nav"><div class="wrap nav-in">
  <a class="brand" href="{prefix}index.html"><img src="{prefix}img/appicon.png" alt="">PowerPulse</a>
  <div class="nav-links">{nav}</div>
  <div class="nav-actions">
    <div class="lang"><a class="{'on' if c['code']=='zh' else ''}" href="{prefix}index.html">中文</a><a class="{'on' if c['code']=='en' else ''}" href="{prefix}en/index.html">EN</a></div>
    <a class="btn btn-ghost nav-dl" href="{RELEASE}">{c['cta']}</a>
  </div>
</div></nav>

<header class="wrap hero">
  <div>
    <span class="eyebrow"><i class="dot"></i>{c['eyebrow']}</span>
    <h1><span class="ln">{c['h1'][0]}</span><span class="ln"><em>{c['h1'][1]}</em></span></h1>
    <p class="hero-sub">{c['sub']}</p>
    <div class="hero-cta">
      <a class="btn btn-primary" href="{RELEASE}">{c['cta1']}</a>
      <a class="btn btn-ghost" href="{SRC}">
        <svg width="15" height="15" viewBox="0 0 16 16" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.4 7.4 0 0 1 2-.27c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z"/></svg>
        {c['cta2']}</a>
    </div>
    <div class="chips">{chips}</div>
  </div>
  <div class="visual">
    <div class="menubar">
      <span class="apple"></span>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M2 8.8a15 15 0 0 1 20 0"/><path d="M5.5 12.3a10 10 0 0 1 13 0"/><path d="M9 15.8a5 5 0 0 1 6 0"/><circle cx="12" cy="19" r="1.1" fill="currentColor" stroke="none"/></svg>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="2" y="8" width="17" height="8" rx="2"/><path d="M21 11v2"/><rect x="4" y="10" width="12" height="4" rx="1" fill="currentColor" stroke="none"/></svg>
      <span class="spacer"></span>
      <img src="{prefix}img/statusitem.png" alt="PowerPulse menu bar item">
    </div>
    <div class="shot"><img src="{prefix}img/panel-flow{shot_suffix}.png" alt="PowerPulse power flow panel" width="640" height="932"></div>
    <div class="caption"><span>{'实时 · 每秒采样' if c['code']=='zh' else 'Live · 1 s sampling'}</span><span>{'Apple Silicon' if c['code']=='zh' else 'Apple Silicon · macOS 14+'}</span></div>
  </div>
</header>

<main>
<section class="sec" id="panels"><div class="wrap">
  <div class="sec-head"><span class="num">01</span><div><h2>{c['p_title']}</h2><p>{c['p_lead']}</p></div></div>
  <div class="tabs">{tabs_in}
    <div class="tabs-bar">{tabs_bar}</div>
    <div class="tabs-body">{tabs_body}</div>
  </div>
</div></section>

<section class="sec" id="anatomy"><div class="wrap">
  <div class="sec-head"><span class="num">02</span><div><h2>{c['a_title']}</h2><p>{c['a_lead']}</p></div></div>
  <div class="anatomy">
    <iframe id="pb" src="{prefix}assets/powerbench.html?embed=1" title="PowerPulse anatomy" loading="lazy" height="880" scrolling="no"></iframe>
    <div class="anatomy-foot"><span>{c['a_foot_l']}</span><a href="{prefix}assets/powerbench.html">{c['a_foot_r']} ↗</a></div>
  </div>
  <div class="keys">{keys}</div>
</div></section>

<section class="sec" id="features"><div class="wrap">
  <div class="sec-head"><span class="num">03</span><div><h2>{c['f_title']}</h2><p>{c['f_lead']}</p></div></div>
  <div class="bento">{cells}</div>
</div></section>

<section class="sec" id="specs"><div class="wrap">
  <div class="sec-head"><span class="num">04</span><div><h2>{c['s_title']}</h2><p>{c['s_lead']}</p></div></div>
  <div class="specs">
    <div class="rows-wrap"><div class="rows-head"><span>{c['rows_h1']}</span><span>{c['rows_h2']}</span></div><dl class="rows">{rows}</dl></div>
    <div class="side">
      <h3>{c['perf_title']}</h3>
      <dl>{perf}</dl>
      <p class="note">{c['perf_note']}</p>
    </div>
  </div>
</div></section>

<section class="sec" id="download"><div class="wrap">
  <div class="dl">
    <img src="{prefix}img/appicon.png" alt="PowerPulse icon">
    <div><h2>{c['d_title']}</h2><p>{c['d_sub']}</p><div class="meta">{meta}</div><p class="dl-note">{c['d_note'].replace(chr(10), '<br>')}</p>
      <div class="dl-cmd"><span>{c['d_cmd_label']}</span><code>{c['d_cmd']}</code></div></div>
    <div class="dl-cta">
      <a class="btn btn-primary" href="{RELEASE}">{c['d_btn']}</a>
    </div>
  </div>
  <details class="build" id="build" open>
    <summary>{c['d_src']}</summary>
    <pre>{c['build_cmd']}</pre>
  </details>
</div></section>
</main>

<footer class="foot"><div class="wrap foot-in">
  <a class="brand" href="{prefix}index.html"><img src="{prefix}img/appicon.png" alt="">PowerPulse</a>
  <span>{c['foot']}</span>
  <div class="foot-links">{foot_links}</div>
</div></footer>

<script>
(function(){{
  var f=document.getElementById('pb');
  addEventListener('message',function(e){{
    if(!e.data||e.data.type!=='pb-height')return;
    var h=Math.max(420,Math.min(1200,Math.round(e.data.h)+2));
    if(Math.abs(f.getBoundingClientRect().height-h)>3)f.style.height=h+'px';
  }});
}})();
</script>
</body>
</html>
"""


def main():
    zh = render(ZH, "", "en/index.html")
    en = render(EN, "../", "index.html", shot_suffix="-en")
    (DOCS / "en").mkdir(exist_ok=True)
    io.open(DOCS / "index.html", "w", encoding="utf-8").write(zh)
    io.open(DOCS / "en" / "index.html", "w", encoding="utf-8").write(en)
    print("wrote docs/index.html", len(zh), "bytes")
    print("wrote docs/en/index.html", len(en), "bytes")


if __name__ == "__main__":
    main()
