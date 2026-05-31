"""Build a .zip asset bundle for the Godot Asset Store."""

import argparse
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
ASSET_DIR = REPO_ROOT / "c3_openai_client"
LICENSE_FILE = REPO_ROOT / "LICENSE.md"
OUTPUT_DIR = REPO_ROOT / "build"


def build(version: str):
    output_zip = OUTPUT_DIR / f"c3_openai_client_{version}.zip"
    OUTPUT_DIR.mkdir(exist_ok=True)

    with zipfile.ZipFile(output_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for file in sorted(ASSET_DIR.rglob("*")):
            if file.is_file():
                zf.write(file, file.relative_to(ASSET_DIR))

        zf.write(LICENSE_FILE, LICENSE_FILE.name)

    print(f"Built: {output_zip}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("version", help="Version string, e.g. v0.1.0")
    args = parser.parse_args()
    build(args.version)
