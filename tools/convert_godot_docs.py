"""Convert Godot 4.6 RST class docs to Markdown (2D-relevant only).

Usage: python tools/convert_godot_docs.py
Output: Docs/godot_ref/md/
"""

import subprocess, shutil, os, sys, re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RST_DIR = PROJECT_ROOT / "Docs" / "godot_ref" / "_sources" / "classes"
OUT_DIR = PROJECT_ROOT / "Docs" / "godot_ref" / "md"
PANDOC_PATH = os.environ.get("PANDOC_PATH") or shutil.which("pandoc")
# Try common Windows install locations
if not PANDOC_PATH:
    for p in [
        r"C:\Users\29908\AppData\Local\Pandoc\pandoc.exe",
        r"C:\Program Files\Pandoc\pandoc.exe",
        r"C:\Program Files (x86)\Pandoc\pandoc.exe",
    ]:
        if os.path.isfile(p):
            PANDOC_PATH = p
            break

# ── Classes to EXCLUDE (all 3D excluded by default; plus other non-2D) ──────
EXCLUDE_PREFIXES = (
    # 3D (matched by suffix below)
    # Editor-only
    "class_editor", "class_editornode", "class_editorinspector",
    "class_editorfile", "class_editorinterface", "class_editorresource",
    "class_editorplugin", "class_editorproperty", "class_editorscript",
    "class_editorselection", "class_editorsettings", "class_editorvcs",
    "class_editorundoredomanager", "class_editortranslation",
    "class_editorpaths", "class_editorcommandpalette",
    "class_editorcontextmenuplugin", "class_editornavigationmeshgenerator",
    # XR/AR
    "class_xr", "class_openxr",
    # C#
    "class_csharp", "class_csharp",
    # GDExtension internals
    "class_gdextension", "class_classdb",
    # Low-level rendering device
    "class_rd_", "class_renderingdevice",
    # Physics server extension internals
    "class_physicsdirectbodystate3d",
    "class_physicsdirectspacestate3d",
    "class_physicspointqueryparameters3d",
    "class_physicsrayqueryparameters3d",
    "class_physicsshapequeryparameters3d",
    "class_physicstestmotionresult3d",
    "class_physicstestmotionparameters3d",
    "class_physicsserver3d",
    "class_physicsdirectbodystate2dextension",
    "class_physicsdirectspacestate2dextension",
    "class_physicsserver2dextension",
    "class_physicsserver2dmanager",
    "class_physicsserver3dextension",
    "class_physicsserver3dmanager",
    "class_physicsserver3drenderingserverhandler",
    # Navigation mesh generation (editor tool)
    "class_navigationmeshgenerator",
    # iOS/Android/Web platform specifics (not usually needed at the scripting level)
    "class_engine",  # we keep Engine but exclude platform-specific
    # Misc seldom used
    "class_mutex", "class_semaphore", "class_thread",
    "class_jslobby",
)

# Files to exclude by exact name
EXCLUDE_NAMES = {
    "class_aabb",
    "class_basis",
    "class_plane",
    "class_projection",
    "class_quaternion",
    "class_transform3d",
    "class_aescontext",
    "class_arraymesh",
    "class_audioeffectbandlimitfilter",
    "class_audioeffectbandpassfilter",
    "class_audioeffectcapture",
    "class_audioeffectcompressor",
    "class_audioeffectdelay",
    "class_audioeffectdistortion",
    "class_audioeffecteq",
    "class_audioeffecteq10",
    "class_audioeffecteq21",
    "class_audioeffecteq6",
    "class_audioeffectfilter",
    "class_audioeffecthardlimiter",
    "class_audioeffecthighpassfilter",
    "class_audioeffecthighshelffilter",
    "class_audioeffectinstance",
    "class_audioeffectlimiter",
    "class_audioeffectlowpassfilter",
    "class_audioeffectlowshelffilter",
    "class_audioeffectnotchfilter",
    "class_audioeffectpanner",
    "class_audioeffectphaser",
    "class_audioeffectpitchshift",
    "class_audioeffectrecord",
    "class_audioeffectreverb",
    "class_audioeffectspectrumanalyzer",
    "class_audioeffectspectrumanalyzerinstance",
    "class_audioeffectstereoenhance",
    "class_audioeffectamplify",
    "class_audioeffectchorus",
    "class_audioeffect",
    "class_audiosampleplayback",
    "class_audiosample",
}


def should_include(filename: str) -> bool:
    """Return True if this class doc should be converted."""
    name = filename.replace(".rst.txt", "")

    # Exclude 3D files by suffix pattern
    if re.search(r"3d", name, re.IGNORECASE):
        return False

    # Exclude by prefix
    if name.startswith(EXCLUDE_PREFIXES):
        return False

    # Exclude by exact name
    if name in EXCLUDE_NAMES:
        return False

    return True


def convert_one(rst_path: Path, md_path: Path) -> bool:
    """Convert one RST file to MD using pandoc. Returns True on success."""
    try:
        result = subprocess.run(
            [
                PANDOC_PATH,
                str(rst_path),
                "-f", "rst",
                "-t", "markdown",
                "--wrap=preserve",  # preserve line breaks
                "-o", str(md_path),
                # skip internal Sphinx directives
                "-M", "title=",
            ],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            print(f"  FAIL ({result.returncode}): {rst_path.name}")
            print(f"    {result.stderr[:200]}")
            return False
        return True
    except subprocess.TimeoutExpired:
        print(f"  TIMEOUT: {rst_path.name}")
        return False
    except FileNotFoundError:
        print("ERROR: pandoc not found. Install it first.")
        sys.exit(1)


def main():
    if not PANDOC_PATH or not os.path.isfile(PANDOC_PATH):
        print("Error: pandoc is not installed or not in PATH.")
        print("Install it via: winget install JohnMacFarlane.Pandoc")
        sys.exit(1)

    if not RST_DIR.exists():
        print(f"Error: RST source directory not found: {RST_DIR}")
        sys.exit(1)

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Collect all .rst.txt files
    all_files = sorted(RST_DIR.glob("class_*.rst.txt"))
    print(f"Total RST files: {len(all_files)}")

    # Filter
    included = [f for f in all_files if should_include(f.name)]
    excluded = [f for f in all_files if not should_include(f.name)]

    print(f"Included: {len(included)}")
    print(f"Excluded: {len(excluded)}")

    # Convert
    ok = 0
    fail = 0
    for rst_path in included:
        md_name = rst_path.stem.replace(".rst", "") + ".md"
        md_path = OUT_DIR / md_name

        print(f"  [{ok+fail+1}/{len(included)}] {rst_path.name} → {md_name}")
        if convert_one(rst_path, md_path):
            ok += 1
        else:
            fail += 1

    print(f"\nDone. {ok} converted, {fail} failed.")
    print(f"Output: {OUT_DIR}")


if __name__ == "__main__":
    main()