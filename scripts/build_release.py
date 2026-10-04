import argparse
import struct
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MOD_DIR = ROOT / "SilentDLCUnlocker"
LOCAL_HEADER = b"PK\x03\x04"


def local_header_names(path: Path):
    names = []
    with path.open("rb") as archive:
        while archive.read(4) == LOCAL_HEADER:
            header = archive.read(26)
            if len(header) != 26:
                raise ValueError("truncated ZIP local header")

            fields = struct.unpack("<HHHHHIIIHH", header)
            flags = fields[1]
            compression = fields[2]
            compressed_size = fields[6]
            name_length = fields[8]
            extra_length = fields[9]
            name = archive.read(name_length).decode("utf-8")

            if flags & 0x08:
                raise ValueError(f"data descriptors are unsupported by SuperBLT: {name}")
            if flags & 0x01:
                raise ValueError(f"encrypted files are unsupported by SuperBLT: {name}")
            if fields[0] >= 45 or fields[6] == 0xFFFFFFFF or fields[7] == 0xFFFFFFFF:
                raise ValueError(f"ZIP64 is unsupported by SuperBLT: {name}")
            if compression not in (0, 8):
                raise ValueError(f"unsupported compression method {compression}: {name}")

            names.append((name, flags, compression, fields[5], fields[6], fields[7]))
            archive.seek(extra_length + compressed_size, 1)

    return names


def verify_archive(path: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP CRC validation failed")
        central_names = [(info.filename, info.flag_bits, info.compress_type,
                          info.CRC, info.compress_size, info.file_size)
                         for info in archive.infolist()]

    local_names = local_header_names(path)
    if not local_names or local_names != central_names:
        raise ValueError("ZIP local headers do not match the central directory")

    for name, *_ in local_names:
        if "\\" in name:
            raise ValueError(f"SuperBLT-incompatible backslash in ZIP path: {name}")
        if not name.startswith("SilentDLCUnlocker/"):
            raise ValueError(f"file is outside SilentDLCUnlocker/: {name}")
        if any(part in ("", ".", "..") for part in name.rstrip("/").split("/")):
            raise ValueError(f"invalid ZIP path: {name}")
    if "SilentDLCUnlocker/mod.txt" not in [row[0] for row in local_names]:
        raise ValueError("ZIP does not contain SilentDLCUnlocker/mod.txt")


def build_archive(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for source in sorted(MOD_DIR.rglob("*")):
            if not source.is_file():
                continue

            name = source.relative_to(ROOT).as_posix()
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 0
            info.external_attr = 0x20
            archive.writestr(
                info,
                source.read_bytes(),
                compress_type=zipfile.ZIP_DEFLATED,
                compresslevel=9,
            )

    verify_archive(path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build a SuperBLT-compatible release ZIP")
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "SilentDLCUnlocker.zip",
        help="output ZIP path",
    )
    parser.add_argument("--check", type=Path, help="check an existing ZIP without building it")
    args = parser.parse_args()

    if args.check:
        verify_archive(args.check)
        print(f"Verified SuperBLT ZIP headers and CRC: {args.check}")
        return

    output = args.output.resolve()
    build_archive(output)
    print(f"Built and verified {output}")


if __name__ == "__main__":
    main()
