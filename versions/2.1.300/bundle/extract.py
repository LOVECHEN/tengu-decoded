import hashlib
import mmap
import struct
import sys
from compression import zstd
from pathlib import Path

SECTION_NAME = b".bun"
SECTION_LENGTH_PREFIX = 8
TRAILER = b"\n---- Bun! ----\n"
OFFSETS_STRUCT_SIZE = 32
RECORD_SIZE = 52
POINTER_COUNT = 6
ROOT_PREFIX = "/$bunfs/root/"
VENDORED_STANDALONE_JS = {"mermaid.min.js", "chart.umd.min.js", "hljsBundle.generated.min.js"}
JS_EXTENSIONS = (".js", ".mjs", ".cjs")


def read_pointer(buffer: bytes, position: int) -> tuple[int, int]:
    return struct.unpack_from("<II", buffer, position)


def find_elf_section_offset(image: mmap.mmap, wanted: bytes) -> int:
    if image[:4] != b"\x7fELF" or image[4] != 2 or image[5] != 1:
        raise SystemExit("not a little-endian ELF64 binary")
    section_table, = struct.unpack_from("<Q", image, 0x28)
    entry_size, entry_count, names_index = struct.unpack_from("<HHH", image, 0x3A)
    names_offset, = struct.unpack_from("<Q", image, section_table + names_index * entry_size + 0x18)
    for index in range(entry_count):
        entry = section_table + index * entry_size
        name_at, = struct.unpack_from("<I", image, entry)
        name_start = names_offset + name_at
        name = image[name_start:image.find(b"\0", name_start)]
        if name == wanted:
            offset, = struct.unpack_from("<Q", image, entry + 0x18)
            return offset
    raise SystemExit(f"ELF section {wanted!r} not found")


def main(binary_path: str, output_dir: str) -> None:
    out = Path(output_dir)
    modules_dir = out / "modules"
    modules_dir.mkdir(parents=True, exist_ok=True)

    with open(binary_path, "rb") as handle:
        mm = mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ)

    section_offset = find_elf_section_offset(mm, SECTION_NAME)
    payload_length = struct.unpack_from("<Q", mm, section_offset)[0]
    base = section_offset + SECTION_LENGTH_PREFIX
    trailer_at = mm.rfind(TRAILER, base, base + payload_length)
    if trailer_at - base + len(TRAILER) != payload_length:
        raise SystemExit(f"trailer not at end of payload: {trailer_at=} {payload_length=}")

    offsets = mm[trailer_at - OFFSETS_STRUCT_SIZE:trailer_at]
    byte_count = struct.unpack_from("<Q", offsets, 0)[0]
    table_offset, table_length = read_pointer(offsets, 8)
    entry_point_id = struct.unpack_from("<I", offsets, 16)[0]
    if byte_count != trailer_at - OFFSETS_STRUCT_SIZE - base or table_length % RECORD_SIZE:
        raise SystemExit(f"offsets struct mismatch: {byte_count=} {table_length=}")

    def slice_of(pointer: tuple[int, int]) -> bytes:
        offset, length = pointer
        if offset + length > payload_length:
            raise SystemExit(f"pointer out of range: {pointer}")
        return mm[base + offset:base + offset + length]

    manifest_rows = ["id\tname\tcontents_bytes\tbytecode_bytes\tflags\tsha256\tin_concat"]
    concat_parts: list[bytes] = []
    record_count = table_length // RECORD_SIZE

    for module_id in range(record_count):
        record = mm[base + table_offset + module_id * RECORD_SIZE:base + table_offset + (module_id + 1) * RECORD_SIZE]
        pointers = [read_pointer(record, index * 8) for index in range(POINTER_COUNT)]
        name = slice_of(pointers[0]).decode("utf-8")
        contents = slice_of(pointers[1])
        flags = record[POINTER_COUNT * 8:RECORD_SIZE].hex()
        relative = name.removeprefix(ROOT_PREFIX)
        is_app_js = relative.endswith(JS_EXTENSIONS) and relative not in VENDORED_STANDALONE_JS
        is_entry = module_id == entry_point_id

        if is_app_js or is_entry:
            concat_parts.append(f"\n//// ===== MODULE {module_id} {relative} ({len(contents)} bytes) =====\n".encode())
            concat_parts.append(contents)
        else:
            target = modules_dir / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(contents)
            if relative.endswith(".zst"):
                target.with_suffix("").write_bytes(zstd.decompress(contents))

        manifest_rows.append(
            f"{module_id}\t{relative}\t{len(contents)}\t{pointers[3][1]}\t{flags}\t"
            f"{hashlib.sha256(contents).hexdigest()}\t{'yes' if is_app_js or is_entry else 'no'}"
        )

    (out / "cli.min.js").write_bytes(b"".join(concat_parts))
    (out / "manifest.tsv").write_text("\n".join(manifest_rows) + "\n")
    print(f"section_offset={section_offset:#x} payload={payload_length} table_offset={table_offset} records={record_count} entry_point_id={entry_point_id}")
    print(f"concatenated modules={sum(1 for row in manifest_rows[1:] if row.endswith('yes'))} bytes={sum(len(part) for part in concat_parts)}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
