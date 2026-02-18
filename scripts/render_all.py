from generate import generate_puzzle
from render import render_puzzle

TOTAL_PUZZLES = 0xA0


def main() -> None:
    puzzles_asm = open("src/puzzles.asm", "w")
    puzzles_asm.write('SECTION "Puzzles", ROM0\n\n')

    for i in range(TOTAL_PUZZLES):
        puzzle = generate_puzzle()
        render_puzzle(puzzle, f"src/puzzles/{i:03}.bin")
        puzzles_asm.write(f'puzzle{i:03}: INCBIN "src/puzzles/{i:03}.bin"\n')

    puzzles_asm.write('\nSECTION "Puzzle Table", ROM0\n\n')
    puzzles_asm.write("gPuzzleTable:\n")
    for i in range(TOTAL_PUZZLES):
        puzzles_asm.write(f"    DW puzzle{i:03}\n")
    puzzles_asm.write("\nEXPORT gPuzzleTable\n")

    puzzles_asm.close()


if __name__ == "__main__":
    main()
