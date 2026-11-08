#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""模板 + 三语文案 → 三个页面（简 / 繁 / EN）。

繁体页 = 繁體書面語（不是粤语口语），切换器只写「繁 繁體中文」。
用法：python3 site-src/render.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from i18n import K  # noqa: E402

DOCS = os.path.normpath(os.path.join(HERE, "..", "docs"))
tpl = open(os.path.join(HERE, "template.html"), encoding="utf-8").read()

PAGES = {
    "zh":   dict(html_lang="zh-CN", content="zh", prefix="", home="index.html", out="index.html",
                 urls=dict(zh="index.html", hant="zh-hant/index.html", en="en/index.html")),
    "hant": dict(html_lang="zh-Hant", content="hant", prefix="../", home="../index.html", out="zh-hant/index.html",
                 urls=dict(zh="../index.html", hant="index.html", en="../en/index.html")),
    "en":   dict(html_lang="en", content="en", prefix="../", home="../index.html", out="en/index.html",
                 urls=dict(zh="../index.html", hant="../zh-hant/index.html", en="index.html")),
}

SWITCH = [("zh", "简", "简体中文", 'lang="zh-CN"'),
          ("hant", "繁", "繁體中文", 'lang="zh-Hant"'),
          ("en", "EN", "English", 'lang="en"')]


def lang_switch(lang, urls):
    items = []
    for code, abbr, full, attr in SWITCH:
        cls = "on" if code == lang else ""
        cur = ' aria-current="page"' if code == lang else ""
        items.append(
            f'<a class="{cls}" href="{urls[code]}" {attr}{cur}>'
            f'<span class="abbr">{abbr}</span><span class="full"><span>{full}</span></span></a>'
        )
    return '<div class="lang">' + "".join(items) + "</div>"


for lang, cfg in PAGES.items():
    out = tpl
    out = out.replace("{{html_lang}}", cfg["html_lang"])
    out = out.replace("{{prefix}}", cfg["prefix"])
    out = out.replace("{{home}}", cfg["home"])
    out = out.replace("{{img_suffix}}", "" if lang == "zh" else "-en")
    out = out.replace("{{lang_switch}}", lang_switch(lang, cfg["urls"]))
    for key in re.findall(r"\{\{t:([a-z0-9_]+)\}\}", out):
        out = out.replace("{{t:%s}}" % key, K[key][cfg["content"]])
    assert "{{" not in out, [m for m in re.findall(r"\{\{[^}]*\}\}", out)][:5]
    path = os.path.join(DOCS, cfg["out"])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write(out)
    print("wrote", cfg["out"], len(out))
