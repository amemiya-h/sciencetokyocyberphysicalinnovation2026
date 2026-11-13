"""JIS-style A3 drawings for the stepper turntable rig.
Sheet 1: assembly (組立図), third-angle projection, scale 1:2.
Sheet 2: electrical connection diagram (電気接続図), JIS C 0617 symbols.
Output: DXF (CAD), PDF and PNG per sheet.
"""
import math
import ezdxf
from ezdxf.enums import TextEntityAlignment as TA
from ezdxf.addons.drawing import RenderContext, Frontend
from ezdxf.addons.drawing.matplotlib import MatplotlibBackend
from ezdxf.addons.drawing.config import Configuration, ColorPolicy, BackgroundPolicy
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

DATE = "2026-11-13"
AUTHOR = "雨宮"
ORG = "東京科学大学 サイバーフィジカルイノベーション"
FONT = "NotoSansCJK-Regular.ttc"


# ---------------------------------------------------------------- setup
def new_doc():
    doc = ezdxf.new("R2010", setup=True, units=4)  # mm
    doc.header["$LTSCALE"] = 0.25
    doc.header["$PSLTSCALE"] = 0
    doc.styles.add("JP", font=FONT)
    lay = doc.layers
    lay.add("OUTLINE", color=7, lineweight=50)          # 太線 外形線
    lay.add("THIN", color=7, lineweight=25)             # 細線
    lay.add("CENTER", color=7, lineweight=25, linetype="CENTER")    # 一点鎖線 中心線
    lay.add("HIDDEN", color=7, lineweight=25, linetype="DASHED")    # 破線 かくれ線
    lay.add("PHANTOM", color=7, lineweight=25, linetype="PHANTOM")  # 二点鎖線 想像線
    lay.add("CUT", color=7, lineweight=25, linetype="CENTER")       # 切断線
    lay.add("HATCH", color=7, lineweight=18)
    lay.add("DIM", color=7, lineweight=18)
    lay.add("TEXT", color=7, lineweight=25)
    lay.add("FRAME", color=7, lineweight=70)
    ds = doc.dimstyles.new("JIS")
    ds.dxf.dimtxsty = "JP"
    ds.dxf.dimtxt = 2.5
    ds.dxf.dimasz = 2.2
    ds.dxf.dimexe = 1.2
    ds.dxf.dimexo = 0.8
    ds.dxf.dimgap = 0.7
    ds.dxf.dimtad = 1
    ds.dxf.dimtih = 0
    ds.dxf.dimtoh = 0
    ds.dxf.dimdec = 0
    ds.dxf.dimlfac = 2.0   # drawing at 1:2, dimensions show real size
    ds.dxf.dimclrd = 7
    ds.dxf.dimclre = 7
    ds.dxf.dimclrt = 7
    ds.dxf.dimlwd = 18
    ds.dxf.dimlwe = 18
    return doc


def L(msp, pts, layer="OUTLINE", close=False):
    msp.add_lwpolyline(pts, close=close, dxfattribs={"layer": layer})


def rect(msp, x0, y0, x1, y1, layer="OUTLINE"):
    L(msp, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], layer, close=True)


def line(msp, a, b, layer="OUTLINE"):
    msp.add_line(a, b, dxfattribs={"layer": layer})


def circ(msp, c, r, layer="OUTLINE"):
    msp.add_circle(c, r, dxfattribs={"layer": layer})


def text(msp, s, p, h=2.5, align=TA.LEFT, layer="TEXT"):
    t = msp.add_text(s, height=h, dxfattribs={"style": "JP", "layer": layer})
    t.set_placement(p, align=align)
    return t


def hatch(msp, pts, angle=45, scale=0.6):
    h = msp.add_hatch(dxfattribs={"layer": "HATCH"})
    h.set_pattern_fill("ANSI31", scale=scale, angle=angle - 45)
    h.paths.add_polyline_path(pts, is_closed=True)


def balloon(msp, n, at, ctr):
    """品番 balloon: leader from `at` (dot) to circle at `ctr`."""
    r = 3.2
    dx, dy = at[0] - ctr[0], at[1] - ctr[1]
    d = math.hypot(dx, dy)
    start = (ctr[0] + dx / d * r, ctr[1] + dy / d * r)
    line(msp, start, at, "THIN")
    msp.add_circle(at, 0.45, dxfattribs={"layer": "THIN"})
    h = msp.add_hatch(dxfattribs={"layer": "THIN"})
    h.paths.add_edge_path().add_arc(at, 0.45, 0, 360)
    circ(msp, ctr, r, "THIN")
    text(msp, str(n), ctr, 3.0, TA.MIDDLE_CENTER)


def dim(msp, p1, p2, base, angle=0, txt="<>", lfac=2.0):
    d = msp.add_linear_dim(base=base, p1=p1, p2=p2, angle=angle, dimstyle="JIS",
                           text=txt, override={"dimlfac": lfac},
                           dxfattribs={"layer": "DIM"})
    d.render()


def third_angle_symbol(msp, x, y, s=1.0):
    """投影法の記号 (第三角法): truncated cone, side view left, end view right."""
    # side (trapezoid) view on the left, circles on the right for third angle
    L(msp, [(x, y - 2.5 * s), (x + 9 * s, y - 4 * s), (x + 9 * s, y + 4 * s), (x, y + 2.5 * s)], "THIN", close=True)
    line(msp, (x - 1.5 * s, y), (x + 10.5 * s, y), "CENTER")
    cx = x + 17 * s
    circ(msp, (cx, y), 4 * s, "THIN")
    circ(msp, (cx, y), 2.5 * s, "THIN")
    line(msp, (cx - 5.5 * s, y), (cx + 5.5 * s, y), "CENTER")
    line(msp, (cx, y - 5.5 * s), (cx, y + 5.5 * s), "CENTER")


def sheet_frame(msp, title_jp, title_en, dwg_no, scale_txt, sheet_txt):
    """A3 landscape, 10 mm margins, centring marks, JIS-style title block."""
    rect(msp, 0, 0, 420, 297, "THIN")              # trimmed sheet edge
    rect(msp, 10, 10, 410, 287, "FRAME")           # 輪郭線
    for (a, b) in [((210, 287), (210, 297)), ((210, 0), (210, 10)),
                   ((0, 148.5), (10, 148.5)), ((410, 148.5), (420, 148.5))]:
        line(msp, a, b, "FRAME")                   # 中心マーク
    # 表題欄 170 x 40 at lower right
    x0, x1, y0, y1 = 240, 410, 10, 50
    rect(msp, x0, y0, x1, y1, "FRAME")
    # rows
    for y in (20, 30, 40):
        line(msp, (x0, y), (x1, y), "THIN")
    line(msp, (300, y0), (300, 40), "THIN")
    line(msp, (355, y0), (355, 40), "THIN")
    line(msp, (270, 40), (270, 50), "THIN")
    # labels (small) + values
    def cell(lbl, val, x, y, w, vh=3.0):
        text(msp, lbl, (x + 1, y + 7.2), 1.8)
        text(msp, val, (x + w / 2, y + 3.4), vh, TA.MIDDLE_CENTER)
    text(msp, "図名 TITLE", (x0 + 1, 47.6), 1.8)
    text(msp, title_jp, (x0 + 32 + 70, 46.2), 3.5, TA.MIDDLE_CENTER)
    text(msp, title_en, (x0 + 32 + 70, 42.0), 2.2, TA.MIDDLE_CENTER)
    cell("図番 DWG No.", dwg_no, x0, 30, 60, 3.2)
    cell("尺度 SCALE", scale_txt, 300, 30, 55)
    cell("枚数 SHEET", sheet_txt, 355, 30, 55)
    cell("作成 DRAWN", AUTHOR, x0, 20, 60)
    cell("日付 DATE", DATE, 300, 20, 55, 2.8)
    cell("単位 UNIT", "mm", 355, 20, 55)
    cell("検図 CHECKED", "", x0, 10, 60)
    text(msp, "投影法 PROJECTION", (301, 17.2), 1.8)
    third_angle_symbol(msp, 316, 13.6, 0.55)
    text(msp, "第三角法", (337, 13.4), 2.2, TA.MIDDLE_LEFT)
    text(msp, "所属 ORG.", (356, 17.2), 1.8)
    text(msp, "東京科学大学", (382.5, 13.4), 2.6, TA.MIDDLE_CENTER)


# ------------------------------------------------------------ sheet 1
from shapely.geometry import box as sbox, Polygon as SPoly
from shapely.ops import unary_union

S = 1.0                 # 1:1
OXF, OYF = 100, 90      # front view: shaft axis, chassis underside (z=0)
OXP, OYP = 100, 222     # plan view: shaft axis


def F(x, z):
    return (OXF + x, OYF + z)


def P(x, y):
    return (OXP + x, OYP + y)


def shp_section(msp, geom, angle=45, scale=0.5):
    """outline + hatch a shapely (Multi)Polygon given in front-view real coords."""
    polys = [geom] if geom.geom_type == "Polygon" else list(geom.geoms)
    for pg in polys:
        ext = [F(x, z) for x, z in list(pg.exterior.coords)[:-1]]
        L(msp, ext, close=True)
        h = msp.add_hatch(dxfattribs={"layer": "HATCH"})
        h.set_pattern_fill("ANSI31", scale=scale, angle=angle - 45)
        h.paths.add_polyline_path(ext, is_closed=True, flags=1)
        for ring in pg.interiors:
            ip = [F(x, z) for x, z in list(ring.coords)[:-1]]
            L(msp, ip, close=True)
            h.paths.add_polyline_path(ip, is_closed=True, flags=0)


def R(x0, z0, x1, z1):
    return sbox(min(x0, x1), min(z0, z1), max(x0, x1), max(z0, z1))


def sym(prof):
    """union of a right-half profile (list of rects r0,z0,r1,z1) mirrored about x=0."""
    return unary_union([R(a, b, c, d) for a, b, c, d in prof] + [R(-a, b, -c, d) for a, b, c, d in prof])


def obround(msp, cx, cy, length, w, view=P):
    a, b = view(cx - length / 2, cy - w / 2), view(cx + length / 2, cy + w / 2)
    r = w / 2
    msp.add_lwpolyline([(a[0] + r, a[1], 0, 0, 0), (b[0] - r, a[1], 0, 0, 1),
                        (b[0] - r, b[1], 0, 0, 0), (a[0] + r, b[1], 0, 0, 1)],
                       format="xyseb", close=True, dxfattribs={"layer": "OUTLINE"})


def zigzag_break(msp, x, z0, z1):
    m = (z0 + z1) / 2
    L(msp, [F(x, z0 - 1.5), F(x, m - 1), F(x + 1.5, m - 0.3), F(x - 1.5, m + 0.3), F(x, m + 1), F(x, z1 + 1.5)], "THIN")


def sheet1(path):
    doc = new_doc()
    doc.dimstyles.get("JIS").dxf.dimlfac = 1.0
    msp = doc.modelspace()
    sheet_frame(msp, "コンパクトターンテーブル組立図", "COMPACT STEPPER TURNTABLE - ASSEMBLY",
                "CPI-TT-001 E", "1 : 1", "1 / 3")
    MX = -46

    # ======================= FRONT VIEW, section A-A ======================
    # 1 chassis (printed, one piece)
    ch = unary_union([R(-76, 0, 40, 4), R(-18, 0, 18, 50), R(-76, 40, 0, 46), R(-76, 0, -70, 40), R(12, 0, 40, 8)])
    cuts = unary_union([R(-68, -1, -24, 5), R(-11.075, -1, 11.075, 15),
                        R(-9, -1, 9, 51), R(-11.075, 43, 11.075, 51),
                        R(MX - 11.5, 39, MX + 11.5, 47),
                        R(23.25, -1, 28.75, 9), R(33.25, -1, 38.75, 9), R(21.25, -1, 30.75, 4), R(31.25, -1, 40.75, 4), R(-77, 8, -69, 18)])
    shp_section(msp, ch.difference(cuts), 45, 0.6)
    # 2 bearings 608ZZ (simplified, JIS B 0005)
    for z0 in (8, 43):
        for sg in (1, -1):
            xa, xb = sorted((sg * 4, sg * 11))
            rect(msp, *F(xa, z0), *F(xb, z0 + 7))
            c = F((xa + xb) / 2, z0 + 3.5)
            line(msp, (c[0] - 1.6, c[1]), (c[0] + 1.6, c[1])); line(msp, (c[0], c[1] - 1.6), (c[0], c[1] + 1.6))
    # 3 shaft (not sectioned)
    rect(msp, *F(-4, 0), *F(4, 78))
    # 4 collar (printed, boss on the inner race)
    shp_section(msp, sym([(4, 0, 10, 7), (4, 7, 5.75, 8)]), 135, 0.35)
    # 6 GT2 80T pulley (printed): boss, hub d20, 45 deg flange, teeth, flange
    p80 = unary_union([sym([(4, 50, 5.75, 51), (4, 51, 10, 55.4), (4, 57, 25.2, 63), (4, 63, 26.8, 64)])] +
                      [SPoly(pts) for pts in
                       ([(4, 55.4), (26.8, 55.4), (25.4, 57), (4, 57)], [(-4, 55.4), (-26.8, 55.4), (-25.4, 57), (-4, 57)])])
    shp_section(msp, p80, 0, 0.35)
    # 8 platter with integral clamp hub (printed) + flag; 5 spindle pin (printed)
    plat = unary_union([sym([(4, 66, 10, 78), (0, 78, 45, 83)]), R(31, 70, 39, 78)])
    plat = plat.difference(R(-2.5, 79, 2.5, 83.01))
    shp_section(msp, plat, 45, 0.6)
    shp_section(msp, sym([(0, 79, 2.5, 83), (0, 83, 3.55, 92)]), 135, 0.25)
    line(msp, F(0, 70), F(0, 98), "CENTER")
    # record (phantom), broken both ends
    L(msp, [F(-80, 83), F(125, 83)], "PHANTOM"); L(msp, [F(-80, 85), F(125, 85)], "PHANTOM")
    zigzag_break(msp, -80, 83, 85); zigzag_break(msp, 125, 83, 85)
    # 9 clamp puck
    clamp = sym([(3.8, 86.6, 40, 89), (15, 85, 40, 86.6), (32, 89, 40, 97), (3.8, 89, 32, 89.001)])
    clamp = unary_union([sym([(15, 85, 40, 86.6)]), sym([(3.8, 86.6, 40, 89)]), sym([(32, 89, 40, 97)]),
                         sym([(3.8, 89, 32, 89.0)])]) if False else \
        R(-40, 85, 40, 97).difference(unary_union([R(-3.8, 84, 3.8, 93), R(-32, 89, 32, 98), R(-15, 84, 15, 86.6)]))
    shp_section(msp, clamp, 135, 0.6)
    # 10 motor (not sectioned)
    rect(msp, *F(MX - 21, 6), *F(MX + 21, 40))
    rect(msp, *F(MX - 11, 40), *F(MX + 11, 42))
    rect(msp, *F(MX - 2.5, 42), *F(MX + 2.5, 64))
    for xx in (MX - 15.5, MX + 15.5):
        line(msp, F(xx, 34), F(xx, 50), "CENTER")
    line(msp, F(MX, 0), F(MX, 70), "CENTER")
    # 11 GT2 20T pulley
    shp_section(msp, unary_union([R(MX + a, b, MX + c, d) for a, b, c, d in
                                  [(2.5, 49, 8, 55.1), (2.5, 55.1, 8, 57), (2.5, 57, 6.1, 63), (2.5, 63, 8, 64)]] +
                                 [R(MX - a, b, MX - c, d) for a, b, c, d in
                                  [(2.5, 49, 8, 55.1), (2.5, 55.1, 8, 57), (2.5, 57, 6.1, 63), (2.5, 63, 8, 64)]]), 0, 0.3)
    # 12 belt (beyond the section plane)
    line(msp, F(MX + 6.1, 57.5), F(-25.2, 57.5)); line(msp, F(MX + 6.1, 62.5), F(-25.2, 62.5))
    # 13 rubber feet (beyond plane)
    for x0 in (-77, 27):
        rect(msp, *F(x0, -8), *F(x0 + 14, 0))
    # 15 skid arm on the pad (optional, phantom) + PTFE-tipped M4 screw
    L(msp, [F(20, 8), F(113, 8), F(113, 75), F(127, 75), F(127, 8), F(127, 8), F(127, 16), F(127, 8)], "PHANTOM")
    L(msp, [F(20, 8), F(20, 16), F(113, 16)], "PHANTOM")
    L(msp, [F(118, 75), F(118, 83), F(122, 83), F(122, 75)], "PHANTOM")
    for xb in (26, 36):                                    # M5 interface holes
        line(msp, F(xb, -3), F(xb, 20), "CENTER")
    # VHX lens (reference)
    rect(msp, *F(95, 98), *F(125, 116), "PHANTOM")
    line(msp, F(110, 94), F(110, 119), "CENTER")
    text(msp, "VHX レンズ (参考)", F(92, 108), 2.2, TA.MIDDLE_RIGHT)
    # shaft centre line
    line(msp, F(0, -6), F(0, 102), "CENTER")
    text(msp, "A - A", F(-60, 112), 3.5, TA.MIDDLE_CENTER)

    # front dimensions
    dim(msp, F(-45, 78), F(45, 78), F(0, 103), 0, "φ<>", lfac=1)               # platter
    dim(msp, F(-40, 97), F(40, 97), F(0, 109), 0, "φ<>", lfac=1)               # clamp
    dim(msp, F(-76, -8), F(40, -8), F(0, -16), 0, lfac=1)                      # 116
    dim(msp, F(40, 0), F(40, 4), F(150, 0), 90, lfac=1) if False else None
    for zt, xb, lab in ((50, 150, None), (60, 160, None), (83, 170, None), (97, 180, None)):
        pass
    dim(msp, F(18, 50), F(40, 0), F(56, 0), 90, lfac=1)                        # housing 50
    dim(msp, F(25.2, 60), F(40, 0), F(66, 0), 90, lfac=1)                      # belt 60
    dim(msp, F(45, 83), F(40, 0), F(76, 0), 90, lfac=1)                        # record underside 83
    dim(msp, F(40, 97), F(40, 0), F(86, 0), 90, lfac=1)                        # top of clamp 97
    line(msp, F(42.5, 60), F(68, 60), "THIN")
    line(msp, F(46, 83), F(78, 83), "THIN")
    line(msp, F(41, 97), F(88, 97), "THIN")
    line(msp, F(41, 0), F(88, 0), "THIN")
    dim(msp, F(-11, 11.5), F(-11, 46.5), F(-30, 0), 90, lfac=1)                # bearing pitch 35

    # balloons front
    for n, at, c in [(1, F(-73, 30), F(-90, 30)),
                     (2, F(7.5, 46), F(22, 32)),
                     (3, F(2, 30), F(22, 22)),
                     (4, F(-6, 2), F(-14, -26)),
                     (5, F(-1.5, 88), F(-22, 104)),
                     (6, F(-20, 60), F(-30, 79)),
                     (7, F(9, 70), F(22, 70)) ,
                     (8, F(30, 81), F(60, 92)),
                     (9, F(-30, 92), F(-50, 100)),
                     (10, F(-60, 20), F(-90, 18)),
                     (11, F(MX - 6, 60), F(-90, 60)),
                     (12, F(-34, 62.5), F(-90, 70)),
                     (13, F(34, -4), F(52, -26)),
                     (15, F(113, 50), F(132, 50))]:
        balloon(msp, n, at, c)

    # ============================ PARTS LIST ==============================
    parts = [
        (1, "シャーシ Chassis", "PETG (3Dプリント)", 1, "tt_parts.scad"),
        (2, "深溝玉軸受 608ZZ", "軸受鋼", 2, "購入 MISUMI"),
        (3, "軸 Shaft φ8×78", "SUJ2 硬質クロム", 1, "購入 PSFJ8-78"),
        (4, "シャフトカラー (ボス付)", "PETG (3Dプリント)", 1, "ボスが内輪に接触"),
        (5, "スピンドルピン φ7.1", "PETG (3Dプリント)", 1, "円板に圧入"),
        (6, "GT2プーリ 80T (ボス付)", "PETG (3Dプリント)", 1, "穴径8 止めねじ"),
        (7, "止めねじ M3 + ナット", "SUS", 4, "品番4,6,8,11"),
        (8, "円板 Platter φ90 (ハブ一体)", "PETG (3Dプリント)", 1, "軸端に着座"),
        (9, "レコードクランプ φ80", "PETG+錘", 1, "約100 g"),
        (10, "ステッピングモータ NEMA17", "—", 1, "42×34"),
        (11, "GT2プーリ 20T", "PETG (3Dプリント)", 1, "穴径5 止めねじ"),
        (12, "タイミングベルト 2GT 200", "ゴム", 1, "購入 GBN200 2GT 60"),
        (13, "脚 Foot", "TPU (3Dプリント)", 5, "M4穴に圧入"),
        (14, "センサポスト+フラグ", "PETG (3Dプリント)", 1, "任意 センサ別"),
        (15, "支持アーム+フェルト", "PETG/フェルト", 1, "任意 M5×2"),
        (16, "電装カバー Cover", "PETG (3Dプリント)", 1, "M3×8 ×2"),
        (17, "Arduino Uno + CNCシールドV3", "—", 1, "CPI-TT-002"),
    ]
    tx0, tx1 = 240, 410
    cols = [tx0, 250, 314, 352, 362, tx1]
    rh = 5.6
    ytop = 50 + rh * (len(parts) + 1)
    rect(msp, tx0, 50, tx1, ytop, "FRAME")
    for c in cols[1:-1]:
        line(msp, (c, 50), (c, ytop), "THIN")
    for i in range(1, len(parts) + 1):
        line(msp, (tx0, 50 + rh * i), (tx1, 50 + rh * i), "THIN")
    for j, hname in enumerate(["品番", "品名 PART", "材質 MATERIAL", "個数", "備考 NOTE"]):
        text(msp, hname, ((cols[j] + cols[j + 1]) / 2, 50 + rh * 0.5), 2.0, TA.MIDDLE_CENTER)
    for i, (n, nm, mat, q, note) in enumerate(parts):
        y = 50 + rh * (i + 1.5)
        text(msp, str(n), ((cols[0] + cols[1]) / 2, y), 2.2, TA.MIDDLE_CENTER)
        text(msp, nm, (cols[1] + 1, y), 1.9, TA.MIDDLE_LEFT)
        text(msp, mat, (cols[2] + 1, y), 1.8, TA.MIDDLE_LEFT)
        text(msp, str(q), ((cols[3] + cols[4]) / 2, y), 2.2, TA.MIDDLE_CENTER)
        text(msp, note, (cols[4] + 1, y), 1.8, TA.MIDDLE_LEFT)
    notes = ["注記 NOTES",
             "1. 3Dプリント部品の形状は tt_parts.scad による (P1S, PETG, サポート不要)。",
             "2. 軸受は下側・上側から圧入。カラーを押し上げ軸方向すきまを除くこと。",
             "3. ベルト張力はモータ取付長穴で調整 (±2)。",
             "4. 制御基板はシャーシ+y側トレイに搭載 (平面図 2/3)。",
             "5. +x端パッドのM5穴2個が取付面: 支持アーム、将来はスパイン (想像線)。",
             "6. ( ) 内は参考寸法。指示なき角は R3 / C1、ベッド面 C0.5。"]
    for i, s in enumerate(notes):
        text(msp, s, (244, 278 - i * 5), 2.2 if i else 2.6)
    return doc


def sheet1_plan(path):
    global OYP
    OYP = 160
    doc = new_doc()
    doc.dimstyles.get("JIS").dxf.dimlfac = 1.0
    msp = doc.modelspace()
    sheet_frame(msp, "コンパクトターンテーブル組立図 平面図", "COMPACT STEPPER TURNTABLE - PLAN VIEW",
                "CPI-TT-001 E", "1 : 1", "2 / 3")
    MX = -46
    # ============================ PLAN VIEW ===============================
    # base plate (with electronics tray on +y) + deck
    outline = unary_union([sbox(-76, -40, 40, 40), sbox(-76, 20, 8, 99)])
    L(msp, [P(x, y) for x, y in list(outline.exterior.coords)[:-1]], close=True)
    # 16 electronics cover (visible) with tabs; 17 Uno + shield under it (hidden)
    rect(msp, *P(-72, 31), *P(2, 92))
    for ty in (40, 82):
        rect(msp, *P(1, ty - 5), *P(10, ty + 5)); circ(msp, P(5, ty), 1.7)
    for vx in range(-62, -12, 8):
        rect(msp, *P(vx - 1.75, 91.2), *P(vx + 1.75, 92), "HIDDEN")
    rect(msp, *P(-70, 34), *P(-1.42, 87.34), "HIDDEN")
    rect(msp, *P(-76.3, 72), *P(-70, 84), "HIDDEN")          # USB-B
    for hx, hy in [(13.97, 2.54), (15.24, 50.8), (66.04, 7.62), (66.04, 35.56)]:
        circ(msp, P(-70 + hx, 34 + hy), 3.25, "HIDDEN")
    rect(msp, *P(-56, 21), *P(-36, 29), "HIDDEN")           # motor cable slot
    text(msp, "16 電装カバー (通気スリット +y側)", P(-35, 62), 2.4, TA.MIDDLE_CENTER)
    text(msp, "17 Arduino Uno + CNCシールド (破線)", P(-35, 56), 2.0, TA.MIDDLE_CENTER)
    text(msp, "USB・電源端子 → −x側", P(-73, 100), 2.0, TA.BOTTOM_LEFT)
    rect(msp, *P(-76, -28), *P(0, 28))
    # housing (cylinder meets deck): show arc outside deck edge
    msp.add_arc(P(0, 0), 18, -90, 90, dxfattribs={"layer": "OUTLINE"})
    # base holes
    for p in [(-70, -34), (34, -34), (34, 34), (-71, 95), (2, 95)]:
        circ(msp, P(*p), 2.25)
    for p in [(26, 0), (36, 0)]:
        circ(msp, P(*p), 2.75, "HIDDEN")
    # base window (hidden under deck) and motor body (hidden)
    rect(msp, *P(-68, -22), *P(-24, 22), "HIDDEN")
    rect(msp, *P(MX - 21, -21), *P(MX + 21, 21), "HIDDEN")
    # motor slots on deck
    for x in (-15.5, 15.5):
        for y in (-15.5, 15.5):
            obround(msp, MX + x, y, 7.4, 3.4)
    # pulleys + belt
    circ(msp, P(0, 0), 27); circ(msp, P(0, 0), 4)
    circ(msp, P(MX, 0), 8); circ(msp, P(MX, 0), 2.5)
    r1, r2, d = 6.37, 25.47, 46.0
    a = math.asin((r2 - r1) / d)
    for sg in (1, -1):
        line(msp, P(MX - r1 * math.sin(a), sg * r1 * math.cos(a)), P(-r2 * math.sin(a), sg * r2 * math.cos(a)))
    # 14 sensor post + pad on the -y side (slot at r = 35)
    rect(msp, *P(2, -43), *P(20, -19))
    rect(msp, *P(2, -37), *P(14, -25), "HIDDEN")
    # 15 skid arm (optional, phantom)
    L(msp, [P(20, -8), P(113.3, -8)], "PHANTOM"); L(msp, [P(20, 8), P(113.3, 8)], "PHANTOM")
    line(msp, P(20, -8), P(20, 8), "PHANTOM")
    circ(msp, P(120, 0), 7, "PHANTOM")
    # future spine (2020 or batten) on the pad holes (phantom)
    rect(msp, *P(20, -10), *P(270, 10), "PHANTOM")
    # future radial axis (phantom): post at the spine end, arm back over the record, carriage
    rect(msp, *P(250, -10), *P(270, 10), "PHANTOM")
    rect(msp, *P(40, -16), *P(270, 16), "PHANTOM")
    rect(msp, *P(165, -24), *P(205, 24), "PHANTOM")
    text(msp, "将来: スパイン+柱+アーム+顕微鏡キャリッジ", P(208, -24), 2.0, TA.TOP_LEFT)
    circ(msp, P(0, 0), 151, "PHANTOM") if False else None
    msp.add_arc(P(0, 0), 151, -8, 8, dxfattribs={"layer": "PHANTOM"})
    text(msp, "レコード外周 R151", P(153, -30), 2.0)
    # platter / clamp / record: phantom (record arc only)
    circ(msp, P(0, 0), 45, "PHANTOM")
    circ(msp, P(0, 0), 40, "PHANTOM")
    # centre lines
    line(msp, P(-86, 0), P(280, 0), "CENTER")
    line(msp, P(0, -50), P(0, 50), "CENTER")
    line(msp, P(MX, -27), P(MX, 27), "CENTER")
    line(msp, P(120, -14), P(120, 14), "CENTER")
    # cutting plane A-A (view from the front: arrows point +y)
    for xe in (-90, 284):
        q0 = P(xe, 0)
        line(msp, (q0[0] - 2.5, q0[1]), (q0[0] + 2.5, q0[1]))
        line(msp, q0, (q0[0], q0[1] + 6), "THIN")
        msp.add_solid([(q0[0] - 1.1, q0[1] + 4), (q0[0] + 1.1, q0[1] + 4), (q0[0], q0[1] + 6.4)],
                      dxfattribs={"layer": "THIN"})
        text(msp, "A", (q0[0] + (-3 if xe < 0 else 3), q0[1] - 4.5), 3.0, TA.BOTTOM_CENTER)
    # plan dims
    dim(msp, P(-76, 99), P(40, 40), P(0, 108), 0, lfac=1)                      # 116
    dim(msp, P(-76, -40), P(-76, 40), P(-84, 0), 90, lfac=1)                   # 80
    dim(msp, P(-76, -40), P(-76, 99), P(-92, 0), 90, lfac=1)                   # 139
    dim(msp, P(0, 0), P(8, 99), P(54, 0), 90, lfac=1)                           # 99 tray edge from axis
    dim(msp, P(-76, -28), P(-76, 28), P(-79.5, 0), 90, lfac=1) if False else None
    dim(msp, P(0, 99), P(40, 40), P(0, 114), 0, lfac=1)                        # 40
    dim(msp, P(MX, -40), P(0, -40), P(0, -46), 0, lfac=1)                      # 46
    dim(msp, P(20, -10), P(270, -10), P(0, -50), 0, lfac=1, txt="(<>)")         # future spine 250
    dim(msp, P(0, 0), P(270, -10), P(0, -57), 0, lfac=1, txt="(<>)")           # spine end from axis
    text(msp, "円板・クランプ・レコードは想像線", P(-74, -66), 2.0)

    text(msp, "平面図 (断面A-A および部品表は 1/3)", (20, 30), 3.0)
    notes = ["注記 NOTES",
             "1. 電装トレイはレコード外周 (R151) の内側。トレイ角は軸から約125。",
             "2. カバー天面は z58 (レコード下面 z83)。ドライバの熱をレコードから遮る。",
             "3. 指示なき角は R3 / C1、ベッド面 C0.5。"]
    for i, t in enumerate(notes):
        text(msp, t, (244, 85 - i * 5), 2.2 if i else 2.6)
    return doc


# ------------------------------------------------------------ sheet 2
def resistor(msp, x, y, horiz=True, w=8, h=3):
    if horiz:
        rect(msp, x - w / 2, y - h / 2, x + w / 2, y + h / 2, "OUTLINE")
    else:
        rect(msp, x - h / 2, y - w / 2, x + h / 2, y + w / 2, "OUTLINE")


def block(msp, x0, y0, x1, y1, title, pins_left=(), pins_right=(), pitch=7, sub=""):
    rect(msp, x0, y0, x1, y1, "OUTLINE")
    text(msp, title, ((x0 + x1) / 2, y1 - 5), 3.0, TA.MIDDLE_CENTER)
    if sub:
        text(msp, sub, ((x0 + x1) / 2, y1 - 9.5), 2.0, TA.MIDDLE_CENTER)
    coords = {}
    for i, p in enumerate(pins_left):
        y = y1 - 16 - i * pitch
        if not p:
            continue
        line(msp, (x0 - 5, y), (x0, y), "OUTLINE")
        text(msp, p, (x0 + 1.5, y), 2.2, TA.MIDDLE_LEFT)
        coords[("L", p)] = (x0 - 5, y)
    for i, p in enumerate(pins_right):
        y = y1 - 16 - i * pitch
        if not p:
            continue
        line(msp, (x1, y), (x1 + 5, y), "OUTLINE")
        text(msp, p, (x1 - 1.5, y), 2.2, TA.MIDDLE_RIGHT)
        coords[("R", p)] = (x1 + 5, y)
    return coords


def wire(msp, pts, label=None, lp=None):
    L(msp, pts, "OUTLINE")
    if label:
        text(msp, label, lp, 2.0, TA.BOTTOM_LEFT)


def dot(msp, p):
    h = msp.add_hatch(dxfattribs={"layer": "OUTLINE"})
    h.paths.add_edge_path().add_arc(p, 0.7, 0, 360)


def sheet2(path):
    doc = new_doc()
    msp = doc.modelspace()
    sheet_frame(msp, "電気接続図", "ELECTRICAL CONNECTION DIAGRAM",
                "CPI-TT-002", "なし NTS", "3 / 3")

    # --- DC power supply (bench) : JIS C 0617 DC source symbol (long/short plates)
    px, py = 40, 216
    rect(msp, 22, 176, 66, 254, "PHANTOM")
    text(msp, "PS1 直流安定化電源", (44, 249.5), 2.4, TA.MIDDLE_CENTER)
    text(msp, "12 V / 電流制限 1.5 A", (44, 244.5), 2.0, TA.MIDDLE_CENTER)
    # cell symbol vertical: long plate (+) top, short plate (−) bottom
    line(msp, (px - 6, py + 2), (px + 6, py + 2), "OUTLINE")
    line(msp, (px - 3, py - 2), (px + 3, py - 2), "FRAME")
    line(msp, (px, py + 2), (px, py + 18), "OUTLINE")
    line(msp, (px, py - 2), (px, py - 18), "OUTLINE")
    text(msp, "+", (px + 8, py + 4), 3.0)
    text(msp, "−", (px + 8, py - 5), 3.0)
    # output terminals
    for yy in (py + 18, py - 18):
        circ(msp, (px, yy), 1.2, "OUTLINE")
    # wires to shield power terminal
    wire(msp, [(px + 1.2, py + 18), (120, py + 18)], "赤 0.75 mm² (AWG18)", (68, py + 19))
    wire(msp, [(px + 1.2, py - 18), (118, py - 18)], "黒 0.75 mm²", (68, py - 17))
    # bulk capacitor C1 across VMOT/GND at the shield terminal (polarised)
    cx = 96
    dot(msp, (cx, py + 18))
    dot(msp, (cx, py - 18))
    line(msp, (cx, py + 18), (cx, py + 2), "OUTLINE")
    line(msp, (cx - 5, py + 2), (cx + 5, py + 2), "OUTLINE")
    # curved plate approximated by arc (JIS polarised capacitor)
    msp.add_arc((cx, py - 6), 6.4, 51, 129, dxfattribs={"layer": "OUTLINE"})
    line(msp, (cx, py + 0.4 - 1.6), (cx, py - 18), "OUTLINE")
    text(msp, "+", (cx - 6, py + 3.5), 2.5)
    text(msp, "C1", (cx - 4, py + 6), 2.4, TA.BOTTOM_RIGHT)
    text(msp, "470 µF 35 V", (cx - 4, py - 4), 2.0, TA.TOP_RIGHT)

    # --- CNC shield + DRV8825 (U2 on X slot)
    sh = block(msp, 125, 120, 225, 250, "A1 CNCシールド V3",
               pins_left=["VMOT (+12V)", "GND", "", "", "", "X− リミット (D9)", "Y− リミット (D10)", "GND (B1)"],
               pins_right=["X: 2B", "X: 2A", "X: 1A", "X: 1B", "", "Y: (将来)", "", "EN (D8)=L"],
               pitch=9, sub="Arduino Uno に装着 / DRV8825 を X スロットへ")
    # connect supply wires to VMOT/GND
    v = sh[("L", "VMOT (+12V)")]
    g = sh[("L", "GND")]
    L(msp, [(120, py + 18), v], "OUTLINE")
    L(msp, [(118, py - 18), (118, g[1]), g], "OUTLINE")
    # DRV8825 inside (dashed sub-block)
    rect(msp, 160, 168, 207, 226, "HIDDEN")
    text(msp, "U2 DRV8825", (183.5, 222), 2.4, TA.MIDDLE_CENTER)
    text(msp, "M0 M1 M2 = H (1/32)", (183.5, 216), 1.9, TA.MIDDLE_CENTER)
    text(msp, "Vref = 0.5 × I定格", (183.5, 211.5), 1.9, TA.MIDDLE_CENTER)
    text(msp, "STEP D2 / DIR D5", (183.5, 207), 1.9, TA.MIDDLE_CENTER)
    text(msp, "(任意で TMC2209)", (183.5, 202.5), 1.9, TA.MIDDLE_CENTER)

    # --- stepper motor M1 (JIS C 0617: circle + M + step symbol)
    mx, my = 300, 205
    circ(msp, (mx, my), 12, "OUTLINE")
    text(msp, "M", (mx, my + 2.5), 6.0, TA.MIDDLE_CENTER)
    # step symbol (stair) under M
    L(msp, [(mx - 5, my - 5), (mx - 3, my - 5), (mx - 3, my - 3), (mx - 1, my - 3), (mx - 1, my - 1),
            (mx + 1, my - 1), (mx + 1, my - 3), (mx + 3, my - 3), (mx + 3, my - 5), (mx + 5, my - 5)], "OUTLINE")
    text(msp, "M1 ステッピングモータ", (mx, my + 17), 2.4, TA.MIDDLE_CENTER)
    text(msp, "NEMA17 2相バイポーラ", (mx, my - 18), 2.0, TA.MIDDLE_CENTER)
    # coil connections
    labels = [("X: 2B", "B−"), ("X: 2A", "B+"), ("X: 1A", "A+"), ("X: 1B", "A−")]
    for k, (pin, coil) in enumerate(labels):
        s = sh[("R", pin)]
        tx = 270
        ty = my + 7.5 - k * 5
        L(msp, [s, (250 + k * 3, s[1]), (250 + k * 3, ty), (tx, ty)], "OUTLINE")
        ang = math.asin((ty - my) / 12)
        ex = mx - 12 * math.cos(ang)
        L(msp, [(tx, ty), (ex, ty)], "OUTLINE")
        text(msp, coil, (tx + 1, ty + 0.5), 1.9, TA.BOTTOM_LEFT)
    text(msp, "同一コイルの線対を確認 (抵抗 数Ω)", (262, my - 26), 1.9)

    # --- home sensor (photo-interrupter, JIS: LED + phototransistor)
    hx, hy = 70, 120
    rect(msp, 40, 100, 100, 140, "PHANTOM")
    text(msp, "B1 光学式エンドストップ (任意)", (70, 136), 2.2, TA.MIDDLE_CENTER)
    # LED triangle
    L(msp, [(55, 125), (61, 125), (58, 120)], "OUTLINE", close=True)
    line(msp, (55, 120), (61, 120), "OUTLINE")
    line(msp, (58, 125), (58, 128), "OUTLINE"); line(msp, (58, 120), (58, 112), "OUTLINE")
    for dy in (0, 3):
        line(msp, (63, 122 + dy), (68, 122 + dy), "THIN")
        msp.add_solid([(68, 121.3 + dy), (68, 122.7 + dy), (69.5, 122 + dy)], dxfattribs={"layer": "THIN"})
    # phototransistor (simplified: base bar + emitter/collector)
    line(msp, (72, 118), (72, 127), "OUTLINE")
    line(msp, (72, 125), (77, 128), "OUTLINE"); line(msp, (72, 120), (77, 117), "OUTLINE")
    line(msp, (77, 128), (77, 131), "OUTLINE"); line(msp, (77, 117), (77, 112), "OUTLINE")
    text(msp, "VCC  SIG  GND", (70, 104), 2.0, TA.MIDDLE_CENTER)
    xs = sh[("L", "X− リミット (D9)")]
    L(msp, [(100, 120), (110, 120), (110, xs[1]), xs], "OUTLINE")
    text(msp, "SIG", (101, 121), 1.9)
    gg = sh[("L", "GND")]
    gnd2 = [k for k in sh if k[0] == "L" and k[1] == "GND"]

    # --- USB to PC
    rect(msp, 140, 60, 210, 92, "PHANTOM")
    text(msp, "PC (MATLAB / シリアル)", (175, 84), 2.4, TA.MIDDLE_CENTER)
    text(msp, "USB 115200 bps", (175, 78), 2.0, TA.MIDDLE_CENTER)
    L(msp, [(175, 92), (175, 120)], "OUTLINE")
    text(msp, "USB-B (Uno)", (177, 104), 2.0)

    # --- connection table
    tbl = [("端子", "接続先", "線"),
           ("PS1 +", "A1 VMOT (+12V)", "赤 0.75 mm²"),
           ("PS1 −", "A1 GND", "黒 0.75 mm²"),
           ("C1 +/−", "A1 VMOT / GND 端子台", "最短で"),
           ("A1 X 2B,2A,1A,1B", "M1 B−,B+,A+,A−", "モータ付属 4P"),
           ("A1 D9 (X−)", "B1 SIG", "デュポン"),
           ("A1 5V / GND", "B1 VCC / GND", "デュポン"),
           ("A1 USB", "PC", "USB A-B"),
           ("A1 Y スロット/D10", "将来:半径方向軸", "空き")]
    x0, y0 = 252, 60
    widths = [50, 58, 34]
    rh = 5.6
    ytop = y0 + rh * len(tbl)
    rect(msp, x0, y0, x0 + sum(widths), ytop, "FRAME")
    xx = x0
    for w in widths[:-1]:
        xx += w
        line(msp, (xx, y0), (xx, ytop), "THIN")
    for i in range(1, len(tbl)):
        line(msp, (x0, ytop - rh * i), (x0 + sum(widths), ytop - rh * i), "THIN")
    for i, row in enumerate(tbl):
        y = ytop - rh * (i + 0.5)
        xx = x0
        for j, cell in enumerate(row):
            text(msp, cell, (xx + 1.2, y), 2.0 if i else 2.2, TA.MIDDLE_LEFT)
            xx += widths[j]
    text(msp, "接続表 CONNECTION TABLE", (x0, ytop + 3), 2.4)

    notes = ["注記 NOTES",
             "1. 図記号は JIS C 0617 による (簡略)。",
             "2. 電源投入中にモータコネクタを抜き差ししないこと。",
             "3. ドライバ電流: Vref を測定し設定してからモータを接続。",
             "4. 電源は出力OFFの状態で接続し、USB接続後に出力ON。"]
    for i, s in enumerate(notes):
        text(msp, s, (20, 276 - i * 5), 2.2 if i else 2.6)
    return doc


# ------------------------------------------------------------ export
def export(doc, base):
    doc.saveas(base + ".dxf")
    cfg = Configuration(lineweight_scaling=1.0, min_lineweight=0.12,
                        color_policy=ColorPolicy.BLACK, background_policy=BackgroundPolicy.WHITE)
    fig = plt.figure(figsize=(420 / 25.4, 297 / 25.4))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 420); ax.set_ylim(0, 297); ax.set_aspect("equal"); ax.axis("off")
    ctx = RenderContext(doc)
    ctx.current_layout_properties.set_colors("#ffffff")
    Frontend(ctx, MatplotlibBackend(ax), config=cfg).draw_layout(doc.modelspace(), finalize=False)
    ax.set_xlim(0, 420); ax.set_ylim(0, 297)
    fig.savefig(base + ".pdf", facecolor="white")
    fig.savefig(base + ".png", dpi=200, facecolor="white")
    plt.close(fig)


if __name__ == "__main__":
    export(sheet1(None), "CPI-TT-001_assembly")
    export(sheet1_plan(None), "CPI-TT-001_plan")
    export(sheet2(None), "CPI-TT-002_electrical")
    print("done")
