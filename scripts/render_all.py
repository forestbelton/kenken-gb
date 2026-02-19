from typing import TextIO

from generate import generate_puzzle
from render import (
    CageEntry,
    render_puzzle_with_dict,
    generate_cage_dict,
    render_cage_constraint,
)

TOTAL_PUZZLES = 0x100


def to_byte(val: int) -> str:
    out = hex(val)[2:]
    if len(out) == 1:
        out = f"0{out}"
    return f"${out}"


def render_dict(cage_dict: dict[str, CageEntry], f: TextIO) -> None:
    f.write('\nSECTION "Puzzle Dictionary", ROM0\n\n')
    f.write("gPuzzleDict:\n")

    for id in range(0x100):
        found_entry: CageEntry | None = None
        for entry in cage_dict.values():
            if id == entry.id:
                found_entry = entry
                break
        if found_entry is None:
            break
        sprite_seq = [to_byte(val) for val in render_cage_constraint(found_entry.cage)]
        f.write(f"    DB {', '.join(sprite_seq)}\n")

    f.write("\nEXPORT gPuzzleDict\n")


def main() -> None:
    puzzles = [generate_puzzle() for _ in range(TOTAL_PUZZLES)]
    cage_dict = generate_cage_dict(puzzles)

    puzzles_asm = open("src/puzzles.asm", "w")
    puzzles_asm.write('SECTION "Puzzle Data", ROM0\n\n')

    for i, puzzle in enumerate(puzzles):
        render_puzzle_with_dict(puzzle, f"src/puzzles/{i:03}.bin", cage_dict)
        puzzles_asm.write(f'puzzle{i:03}: INCBIN "src/puzzles/{i:03}.bin"\n')

    puzzles_asm.write('\nSECTION "Puzzle Table", ROM0\n\n')
    puzzles_asm.write("gPuzzleTable:\n")
    for i in range(TOTAL_PUZZLES):
        puzzles_asm.write(f"    DW puzzle{i:03}\n")
    puzzles_asm.write("\nEXPORT gPuzzleTable\n")

    render_dict(cage_dict, puzzles_asm)

    puzzles_asm.close()


if __name__ == "__main__":
    main()
