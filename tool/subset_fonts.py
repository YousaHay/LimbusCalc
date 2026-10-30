"""生成界面使用的子集字体，使中文在 Web / 各平台上无需运行时联网下载。

用法：
    python tool/subset_fonts.py <包含 NotoSansSC-{Regular,Medium,Bold}.otf 的目录>

源字体：https://github.com/notofonts/noto-cjk （Sans/SubsetOTF/SC，SIL OFL 1.1）
依赖：fonttools（pip install fonttools）

收录字符 = 可打印 ASCII + 少量常用符号 + lib/ 下所有 Dart 源文件中出现的非 ASCII 字符。
新增界面文案后需重新运行本脚本；test/font_coverage_test.dart 会检查遗漏。
"""

import pathlib
import sys

from fontTools import subset
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts"
WEIGHTS = ("Regular", "Medium", "Bold")
EXTRA = "×−→≤≥～·…“”‘’（）：；，。、！？【】《》％±\u00a0"


def cff_to_truetype(font) -> None:
    """将 CFF 轮廓转换为 TrueType（glyf）轮廓。

    Flutter Web 的 CanvasKit 未能使用 CFF 轮廓的 OTF（实测会回退到联网字体），
    转为 TrueType 后各平台均可直接使用。改编自 fontTools 的 otf2ttf 示例。
    """
    # 保存时重新计算 glyf 边界、head 包围盒与 maxp 统计。
    font.recalcBBoxes = True
    glyph_order = font.getGlyphOrder()
    glyph_set = font.getGlyphSet()
    font["loca"] = newTable("loca")
    font["glyf"] = glyf = newTable("glyf")
    glyf.glyphOrder = glyph_order
    glyf.glyphs = {}
    for name in glyph_order:
        tt_pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(tt_pen, 1.0, reverse_direction=True))
        glyf.glyphs[name] = tt_pen.glyph()
    del font["CFF "]
    if "VORG" in font:
        del font["VORG"]
    for glyph in glyf.glyphs.values():
        glyph.recalcBounds(glyf)
    hmtx = font["hmtx"]
    for name, glyph in glyf.glyphs.items():
        if hasattr(glyph, "xMin"):
            hmtx[name] = (hmtx[name][0], glyph.xMin)
    font["maxp"] = maxp = newTable("maxp")
    maxp.tableVersion = 0x00010000
    for attr in (
        "maxZones",
        "maxTwilightPoints",
        "maxStorage",
        "maxFunctionDefs",
        "maxInstructionDefs",
        "maxStackElements",
        "maxSizeOfInstructions",
        "maxComponentElements",
    ):
        setattr(maxp, attr, 1 if attr == "maxZones" else 0)
    post = font["post"]
    post.formatType = 3.0
    font.sfntVersion = "\x00\x01\x00\x00"


def collect_chars() -> str:
    chars = {chr(c) for c in range(0x20, 0x7F)}
    chars.update(EXTRA)
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        chars.update(ch for ch in path.read_text(encoding="utf-8") if ord(ch) > 0x7E)
    chars.discard("\n")
    chars.discard("\r")
    return "".join(sorted(chars))


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = pathlib.Path(sys.argv[1])
    text = collect_chars()
    OUT.mkdir(parents=True, exist_ok=True)
    for weight in WEIGHTS:
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        font = subset.load_font(source / f"NotoSansSC-{weight}.otf", options)
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
        cff_to_truetype(font)
        target = OUT / f"NotoSansSC-{weight}.subset.ttf"
        subset.save_font(font, target, options)
        print(f"{target.relative_to(ROOT)}: {target.stat().st_size} bytes")
    (OUT / "charset.txt").write_text(text, encoding="utf-8")
    print(f"{len(text)} characters")


if __name__ == "__main__":
    main()
