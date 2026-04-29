# -*- coding: utf-8 -*-
"""
将图像/音频迁入 assets/资源总库/，并替换全工程 res:// 引用（排除 addons、.git、.godot）。
不移动 .gd / .tscn / .gd.uid（仅移动 png/jpg/svg/mp3/wav/ogg 及同目录 .import）。
运行：python tools/move_media_to_ziyuanku.py
"""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "assets" / "资源总库"
SKIP = {".git", ".godot", "addons", "__pycache__"}
MEDIA_EXT = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".mp3", ".wav", ".ogg"}


def res_url(rel: str) -> str:
    return "res://" + rel.replace("\\", "/")


def collect_media_files(folder: Path) -> list[Path]:
    out: list[Path] = []
    if not folder.exists():
        return out
    for p in folder.rglob("*"):
        if not p.is_file():
            continue
        suf = p.suffix.lower()
        if suf in MEDIA_EXT:
            out.append(p)
            imp = Path(str(p) + ".import")
            if imp.exists():
                out.append(imp)
        # 不单独扫孤立 .import（由上行附带）
    return sorted(set(out), key=lambda x: len(x.as_posix()), reverse=True)


def rel_to(root: Path, p: Path) -> str:
    return p.relative_to(root).as_posix()


def move_file(src: Path, dst: Path) -> tuple[str, str] | None:
    if not src.exists():
        print("MISSING", src)
        return None
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        dst.unlink()
    shutil.move(str(src), str(dst))
    old = res_url(rel_to(ROOT, src))
    new = res_url(rel_to(ROOT, dst))
    print("OK", old, "->", new)
    return (old, new)


def main() -> int:
    os.chdir(ROOT)
    replacements: list[tuple[str, str]] = []

    for sub in (
        "01_图像_背景", "02_图像_地图", "03_图像_UI", "04_图像_玩家", "05_图像_NPC商鞅",
        "06_图像_World3/bosses", "06_图像_World3/props", "06_图像_World3/random_pieces",
        "06_图像_World3", "07_图像_World2", "08_图像_机关", "09_图像_系统",
        "10_音频", "11_字体", "12_Dialogic工程/Dialogic", "12_Dialogic工程",
        "99_工具",
    ):
        (LIB / sub).mkdir(parents=True, exist_ok=True)

    # --- 整体目录（仅含资源或 Dialogic 工程）---
    for src_rel, dst_rel in (
        ("assets/background", "01_图像_背景"),
        ("assets/map", "02_图像_地图"),
        ("assets/字体", "11_字体"),
        ("assets/Dialogic", "12_Dialogic工程/Dialogic"),
    ):
        src = ROOT / src_rel
        dst = LIB / dst_rel
        if src.exists():
            if dst.exists():
                shutil.rmtree(dst)
            shutil.move(str(src), str(dst))
            replacements.append((res_url(src_rel) + "/", res_url(f"assets/资源总库/{dst_rel}") + "/"))

    # assets 根散装
    ASSET_ROOT = ROOT / "assets"
    for name in (
        "咔擦，门窗.mp3", "咔擦，门窗.wav", "商鞅的小曲.mp3", "开关.mp3", "开关.wav",
        "破空.mp3", "破空.wav", "水滴.mp3", "水滴.wav", "walk.mp3", "walk.wav",
        "jump.mp3", "jump.wav", "draw.mp3", "draw.wav", "跳跃.mp3", "跳跃.wav",
    ):
        p = ASSET_ROOT / name
        r = move_file(p, LIB / "10_音频" / name)
        if r:
            replacements.append(r)

    for name in (
        "哈哈，我逃走了.dtl", "teacher_intro.dtl", "student_intro.dtl", "tip_开关与门1.dtl",
        "什么？！.dtl", "bubble.tres", "New_File.tres", "气泡-sheet.png",
    ):
        p = ASSET_ROOT / name
        r = move_file(p, LIB / "12_Dialogic工程" / name)
        if r:
            replacements.append(r)
    for uid in ASSET_ROOT.glob("*.uid"):
        if uid.name.startswith(("哈哈", "teacher_", "student_", "tip_", "什么", "bubble", "New_File", "气泡", "timeline")):
            r = move_file(uid, LIB / "12_Dialogic工程" / uid.name)
            if r:
                replacements.append(r)

    apy = ASSET_ROOT / "audio_changer.py"
    r = move_file(apy, LIB / "99_工具" / "audio_changer.py")
    if r:
        replacements.append(r)

    # --- 混合目录：只搬媒体 ---
    # entities/npc 根目录仅商鞅立绘一张
    for name in ("商鞅.png",):
        p = ROOT / "entities" / "npc" / name
        ip = Path(str(p) + ".import")
        dst = LIB / "05_图像_NPC商鞅" / name
        for f in (p, ip):
            if f.exists():
                r = move_file(f, dst if f == p else Path(str(dst) + ".import"))
                if r:
                    replacements.append(r)

    move_specs: list[tuple[Path, Path]] = [
        (ROOT / "entities" / "npc" / "商鞅", LIB / "05_图像_NPC商鞅" / "商鞅"),
        (ROOT / "entities" / "enemy" / "teacher", LIB / "06_图像_敌人" / "teacher"),
        (ROOT / "entities" / "enemy" / "bullet", LIB / "06_图像_敌人" / "bullet"),
        (ROOT / "entities" / "player" / "bullet", LIB / "04_图像_玩家" / "bullet"),
        (ROOT / "entities" / "player" / "real player", LIB / "04_图像_玩家" / "real player"),
        (ROOT / "system" / "ui", LIB / "03_图像_UI"),
        (ROOT / "system" / "scene", LIB / "09_图像_系统"),
        (ROOT / "system" / "可交互物", LIB / "08_图像_机关"),
        (ROOT / "system" / "levels" / "world2", LIB / "07_图像_World2"),
        (ROOT / "system" / "levels" / "world3" / "bosses", LIB / "06_图像_World3" / "bosses"),
        (ROOT / "system" / "levels" / "world3" / "props", LIB / "06_图像_World3" / "props"),
        (ROOT / "system" / "levels" / "world3" / "random_pieces", LIB / "06_图像_World3" / "random_pieces"),
    ]
    for src_dir, dst_root in move_specs:
        for p in collect_media_files(src_dir):
            rel_inside = p.relative_to(src_dir)
            dst = dst_root / rel_inside
            r = move_file(p, dst)
            if r:
                replacements.append(r)

    for png in ("马场中.png", "马场后.png"):
        p = ROOT / "system" / "levels" / "world3" / png
        ip = Path(str(p) + ".import")
        for f in (p, ip):
            if f.exists():
                r = move_file(f, LIB / "06_图像_World3" / f.name)
                if r:
                    replacements.append(r)

    replacements.sort(key=lambda x: len(x[0]), reverse=True)

    patched = 0
    for dirpath, _dirs, files in os.walk(ROOT):
        dp = Path(dirpath)
        try:
            rel = dp.relative_to(ROOT)
        except ValueError:
            continue
        if rel.parts and rel.parts[0] in SKIP:
            continue
        if ".godot" in rel.parts:
            continue
        for name in files:
            p = dp / name
            if p.suffix.lower() not in {".gd", ".tscn", ".tres", ".import", ".dch", ".dtl", ".cfg", ".godot", ".md", ".cs", ".shader"}:
                continue
            try:
                text = p.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            orig = text
            for o, n in replacements:
                text = text.replace(o, n)
            if p.suffix == ".import":
                for o, n in replacements:
                    text = text.replace(f'source_file="{o}"', f'source_file="{n}"')
            if text != orig:
                p.write_text(text, encoding="utf-8", newline="\n")
                patched += 1
    print("Text files patched:", patched)
    return 0


if __name__ == "__main__":
    sys.exit(main())
