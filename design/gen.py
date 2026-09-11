# 테마 목업(.dc.html) 생성기 — SVG 본문을 한 번만 적고 1x(실제 48px)·3x 확대 두 벌로 뽑는다.
# 좌표는 themes\*.ps1 의 GDI+ 좌표와 1:1 — 목업이 곧 스펙.
# 실행: python gen.py  → 같은 폴더에 Main/Cars/Text/Battery/Rings.dc.html + canvas.json
import json, pathlib

OUT = pathlib.Path(__file__).parent
F = "font-family: 'Segoe UI', system-ui, sans-serif"
FONT = "'Segoe UI', system-ui, sans-serif"
LBL11 = f"font: 700 11px {FONT}; fill: #a0a0a0"
LBL9  = f"font: 700 9px {FONT}; fill: #a0a0a0"
L5, L7 = "2:21/5h", "1/7d"     # 남은시간/창 라벨 — 목업은 고정 표본 (위젯은 실시간 계산)

# 모든 아트보드가 같은 로직을 쓴다 — 슬라이더(s5h·s7d) → 색·폭·좌표 계산
LOGIC = """
class Component extends DCLogic {
  renderVals() {
    const clamp = v => Math.max(0, Math.min(100, Math.round(v)));
    const s5 = clamp(this.props.s5h ?? 38), s7 = clamp(this.props.s7d ?? 72);
    const col = p => p < 60 ? '#50e678' : p < 85 ? '#ffd700' : '#ff6347';
    return {
      s5, s7, c5: col(s5), c7: col(s7), cd: col(Math.max(s5, s7)),
      b5: 108 * s5 / 100, b7: 108 * s7 / 100,
      carX: 44 + 170 * s5 / 100, truckX: 44 + 162 * s7 / 100,
      f5: 39 * (100 - s5) / 100, f7: 39 * (100 - s7) / 100,
      d5: 87.96 * s5 / 100, d7: 87.96 * s7 / 100
    };
  }
}
"""
PROPS = json.dumps({
    "s5h": {"editor": "range", "default": 38, "min": 0, "max": 100, "step": 1, "unit": "%", "section": "사용률"},
    "s7d": {"editor": "range", "default": 72, "min": 0, "max": 100, "step": 1, "unit": "%", "section": "사용률"},
    "$preview": {"width": 760, "height": 340},
}, ensure_ascii=False)


def svg_bars():
    def row(lbl, y, b, c, s):
        return f"""
<text x="56" y="{y+9}" style="{LBL11}; text-anchor: end">{lbl}</text>
<rect x="62" y="{y}" width="108" height="9" rx="2" fill="#3a3a3a"></rect>
<rect x="62" y="{y}" width="{{{{{b}}}}}" height="9" rx="2" fill="{{{{{c}}}}}"></rect>
<text x="178" y="{y+9}" style="font: 700 11px {FONT}; fill: {{{{{c}}}}}">{{{{{s}}}}}%</text>"""
    return row(L5, 11, "b5", "c5", "s5") + row(L7, 28, "b7", "c7", "s7")


def svg_cars(pid): return f"""
<defs><pattern id="{pid}" width="8" height="8" patternUnits="userSpaceOnUse">
  <rect width="4" height="4" fill="#e8e8e8"></rect><rect x="4" y="4" width="4" height="4" fill="#e8e8e8"></rect>
</pattern></defs>
<rect x="0" y="2" width="254" height="44" rx="4" fill="#2c2c2c"></rect>
<line x1="42" y1="24" x2="242" y2="24" stroke="#5a5a5a" style="stroke-width: 1.5; stroke-dasharray: 7 6"></line>
<rect x="244" y="4" width="8" height="40" fill="url(#{pid})"></rect>
<text x="4" y="17" style="font: 700 9px {FONT}; fill: #8a8a8a">{L5}</text>
<text x="4" y="39" style="font: 700 9px {FONT}; fill: #8a8a8a">{L7}</text>
<g transform="translate({{{{carX}}}} 0)">
  <rect x="6" y="4" width="13" height="6" rx="2" fill="{{{{c5}}}}"></rect>
  <rect x="0" y="9" width="26" height="8" rx="2" fill="{{{{c5}}}}"></rect>
  <rect x="8" y="5" width="9" height="4" rx="1" fill="#1a1a1a" opacity="0.55"></rect>
  <rect x="24" y="11" width="2" height="3" fill="#fff8c0"></rect>
  <circle cx="6" cy="18" r="2.8" fill="#111"></circle><circle cx="6" cy="18" r="1.1" fill="#888"></circle>
  <circle cx="20" cy="18" r="2.8" fill="#111"></circle><circle cx="20" cy="18" r="1.1" fill="#888"></circle>
</g>
<g transform="translate({{{{truckX}}}} 0)">
  <rect x="0" y="27" width="22" height="13" rx="1.5" fill="{{{{c7}}}}"></rect>
  <rect x="23" y="31" width="11" height="9" rx="2" fill="{{{{c7}}}}"></rect>
  <rect x="27" y="32.5" width="5.5" height="4" rx="1" fill="#1a1a1a" opacity="0.55"></rect>
  <rect x="33" y="35" width="1.5" height="3" fill="#fff8c0"></rect>
  <circle cx="5" cy="41" r="2.8" fill="#111"></circle><circle cx="5" cy="41" r="1.1" fill="#888"></circle>
  <circle cx="14" cy="41" r="2.8" fill="#111"></circle><circle cx="14" cy="41" r="1.1" fill="#888"></circle>
  <circle cx="29" cy="41" r="2.8" fill="#111"></circle><circle cx="29" cy="41" r="1.1" fill="#888"></circle>
</g>"""


def svg_battery():
    def cell(x, lbl, f, c, s):
        return f"""
<rect x="{x}" y="9" width="44" height="18" rx="3" fill="none" stroke="#9a9a9a" style="stroke-width: 1.5"></rect>
<rect x="{x+44.5}" y="14" width="3" height="8" rx="1" fill="#9a9a9a"></rect>
<rect x="{x+2.5}" y="11.5" width="{{{{{f}}}}}" height="13" rx="1.5" fill="{{{{{c}}}}}"></rect>
<text x="{x+54}" y="22" style="font: 700 11px {FONT}; fill: {{{{{c}}}}}">{{{{{s}}}}}%</text>
<text x="{x+22}" y="41" style="{LBL9}; text-anchor: middle">{lbl}</text>"""
    return cell(4, L5, "f5", "c5", "s5") + cell(100, L7, "f7", "c7", "s7")


# 채택 3종 (2026-09-11): 기본 = 막대 게이지, 우클릭 전환 = 자동차·배터리. 텍스트·링은 제외.
THEMES = [
    # file stem, 제목, 한 줄 설명, 1x 폭, svg 생성자
    ("Main",    "막대 게이지 (기본)", "남은시간/창 라벨(오른쪽 정렬) + 진행 막대 + 숫자", 215, lambda sfx: svg_bars()),
    ("Cars",    "자동차",     "승용차 = 5시간 · 화물차 = 7일. 결승 깃발까지 달린다. 차선 앞에 남은시간", 260, lambda sfx: svg_cars("chk" + sfx)),
    ("Battery", "배터리",     "잔량 = 남은 한도(비워질수록 소진) · 옆 숫자 = 사용률 · 아래 남은시간", 190, lambda sfx: svg_battery()),
]


def page(stem, title, desc, w, mk):
    svg1 = f'<svg width="{w}" height="48" viewBox="0 0 {w} 48" style="display:block; overflow: visible">{mk("1")}\n</svg>'
    svg3 = f'<svg width="{w*3}" height="144" viewBox="0 0 {w} 48" style="display:block; overflow: visible">{mk("3")}\n</svg>'
    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>
    body {{ margin: 0; {F}; }}
    a {{ color: #b45309; }} a:hover {{ color: #92400e; }}
  </style>
</helmet>
<div style="width: 760px; height: 340px; background: #f4f3ef; padding: 20px 24px; box-sizing: border-box; display: flex; flex-direction: column; gap: 12px; {F}">
  <div style="display: flex; align-items: baseline; gap: 12px">
    <div style="font-size: 18px; font-weight: 700; color: #1a1a1a">{title}</div>
    <div style="font-size: 13px; color: #6b6b6b">{desc}</div>
  </div>
  <div style="height: 48px; background: #202020; border-radius: 4px; display: flex; align-items: center; padding-left: 12px; box-sizing: border-box">
    {svg1}
  </div>
  <div style="font-size: 11px; color: #8a8a8a">↑ 실제 크기(작업표시줄 48px) &nbsp;·&nbsp; ↓ 3배 확대 &nbsp;·&nbsp; 라벨 = 남은시간/창 (5h: H:MM/5h · 7d: N/7d, 24시간 미만 Nh/7d)</div>
  <div style="background: #202020; border-radius: 4px; padding: 8px 14px; align-self: flex-start">
    {svg3}
  </div>
</div>
</x-dc>
<script data-dc-script data-props='{PROPS}'>{LOGIC}</script>
</body>
</html>
"""


for stem, title, desc, w, mk in THEMES:
    (OUT / f"{stem}.dc.html").write_text(page(stem, title, desc, w, mk), encoding="utf-8")

pos = [(0, 0), (860, 0), (0, 480)]
canvas = {
    "artboards": [
        {"file": f"{s}.dc.html", "title": t, "x": x, "y": y, "w": 760, "h": 340}
        for (s, t, _, _, _), (x, y) in zip(THEMES, pos)
    ],
    "annotations": [{
        "id": "howto", "x": 860, "y": 480, "w": 440,
        "text": "채택 3종 — 기본은 막대 게이지, 자동차·배터리는 위젯 우클릭 → 테마로 전환.\n"
                "각 아트보드 위 슬라이더(s5h·s7d)로 사용률을 바꿔가며 비교.\n"
                "색 규칙(공통): 60% 미만 초록 · 85% 미만 노랑 · 이상 빨강.\n"
                "라벨은 남은시간/창 — 5h: H:MM/5h, 7d: N/7d(1일 이상) · Nh/7d(24시간 미만). 목업은 2:21/5h · 1/7d 고정, 위젯은 매 분 갱신.\n"
                "높이는 실제 작업표시줄 48px 고정, 폭은 테마별."
    }],
    "launch": {"view": "canvas"},
}
(OUT / "canvas.json").write_text(json.dumps(canvas, ensure_ascii=False, indent=2), encoding="utf-8")
print("generated:", ", ".join(f"{s}.dc.html" for s, *_ in THEMES), "+ canvas.json")
