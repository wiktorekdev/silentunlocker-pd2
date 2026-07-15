import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MOD_FILE = ROOT / "SilentDLCUnlocker" / "mod.txt"
UPDATE_FILE = ROOT / "updates" / "meta.json"
README_FILE = ROOT / "README.md"


def load_json(path: Path):
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def main() -> None:
    mod = load_json(MOD_FILE)
    updates = load_json(UPDATE_FILE)

    if len(updates) != 1:
        raise ValueError("updates/meta.json must contain exactly one update entry")

    update = updates[0]
    configured_updates = mod.get("updates", [])
    if len(configured_updates) != 1:
        raise ValueError("mod.txt must contain exactly one update configuration")

    identifier = configured_updates[0].get("identifier")
    if identifier != update.get("ident"):
        raise ValueError("update identifiers in mod.txt and updates/meta.json do not match")

    version = mod.get("version")
    if version != update.get("version"):
        raise ValueError("versions in mod.txt and updates/meta.json do not match")

    version_pattern = re.escape(version)
    patchnotes_url = update.get("patchnotes_url", "")
    download_url = update.get("download_url", "")
    if not re.search(rf"/tag/v{version_pattern}$", patchnotes_url):
        raise ValueError("patchnotes_url must end with the current v-prefixed version tag")
    if not re.search(rf"/download/v{version_pattern}/SilentDLCUnlocker\.zip$", download_url):
        raise ValueError("download_url must point to SilentDLCUnlocker.zip for the current version")

    readme = README_FILE.read_text(encoding="utf-8")
    if not re.search(rf"version-{version_pattern}-", readme):
        raise ValueError("README version badge does not match mod.txt")

    image_path = mod.get("image")
    if not image_path:
        raise ValueError("mod.txt must define an image for the SuperBLT mod loader")
    if not (MOD_FILE.parent / image_path).is_file():
        raise ValueError(f"mod image does not exist: {image_path}")

    hook_pairs = set()
    for hook in mod.get("hooks", []):
        hook_id = hook.get("hook_id")
        script_path = hook.get("script_path")
        pair = (hook_id, script_path)
        if not hook_id or not script_path:
            raise ValueError("every mod hook needs hook_id and script_path")
        if pair in hook_pairs:
            raise ValueError(f"duplicate hook entry: {hook_id} -> {script_path}")
        hook_pairs.add(pair)

        script_file = MOD_FILE.parent / script_path
        if not script_file.is_file():
            raise ValueError(f"hook script does not exist: {script_path}")

    print(f"Release metadata and {len(hook_pairs)} hooks are consistent for v{version}.")


if __name__ == "__main__":
    main()
