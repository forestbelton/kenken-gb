import struct

from generate import (
    Puzzle,
    SingletonCage,
    GroupCage,
    CageOperator,
)


OPERATOR_TILE_OFFSET = 1

CAGE_OPERATOR_TILE_IDX: dict[CageOperator, int] = {
    CageOperator.ADD: 0xA,
    CageOperator.SUB: 0xB,
    CageOperator.MUL: 0xC,
    CageOperator.DIV: 0xD,
}


def validate_puzzle(puzzle: Puzzle):
    for i, row in enumerate(puzzle.values):
        if set(row) != {1, 2, 3, 4}:
            raise Exception(f"row {i} is not valid")
    for i in range(4):
        col = [puzzle.values[i][y] for y in range(4)]
        if set(col) != {1, 2, 3, 4}:
            raise Exception("column {i} is not valid")
    all_tiles = {(x, y) for x in range(4) for y in range(4)}
    for cage in puzzle.cages:
        if isinstance(cage, SingletonCage):
            tile = (cage.x, cage.y)
            if tile not in all_tiles:
                raise Exception(f"tile {tile} defined more than once")
            all_tiles.remove(tile)
        else:
            for tile in cage.tiles:
                if tile not in all_tiles:
                    raise Exception(f"tile {tile} defined more than once")
                all_tiles.remove(tile)
    if len(all_tiles) != 0:
        raise Exception(f"tiles not defined: {list(all_tiles)}")
    for i, cage in enumerate(puzzle.cages):
        if isinstance(cage, SingletonCage):
            if cage.target not in {1, 2, 3, 4}:
                raise Exception(f"invalid target {cage.target} for singleton cage")
        else:
            values = sorted(
                [puzzle.values[y][x] for x, y in cage.tiles], key=lambda x: -x
            )
            match cage.op:
                case CageOperator.ADD:
                    if sum(values) != cage.target:
                        raise Exception(
                            f"invalid cage {i}: values do not sum to {cage.target}"
                        )
                case CageOperator.SUB:
                    result = values[0]
                    for x in values[1:]:
                        result -= x
                    if result != cage.target:
                        raise Exception(
                            f"invalid cage {i}: values do not subtract to {cage.target}"
                        )
                case CageOperator.MUL:
                    result = 1
                    for x in values:
                        result *= x
                    if result != cage.target:
                        raise Exception(
                            f"invalid cage {i}: values do not multiply to {cage.target}"
                        )
                case CageOperator.DIV:
                    result = values[0]
                    for x in values[1:]:
                        if result % x != 0:
                            raise Exception(
                                f"invalid cage{i}: values do not divide to {cage.target}"
                            )
                        result //= x
                    if result != cage.target:
                        raise Exception(
                            f"invalid cage {i}: values do not divide to {cage.target}"
                        )


def get_sprite_x0(x: int) -> int:
    board_x0 = 2 * 8 + 1 - 2
    return board_x0 + x * 32


def get_sprite_y0(y: int) -> int:
    board_y0 = 1 * 8 + 2 - 3
    return board_y0 + y * 32


def find_top_tile(cage: GroupCage | SingletonCage) -> tuple[int, int]:
    if isinstance(cage, SingletonCage):
        return (cage.x, cage.y)

    def compare_tile(p: tuple[int, int]) -> tuple[int, int]:
        return (p[1], p[0])

    tiles = sorted(cage.tiles, key=compare_tile)
    return tiles[0]


def get_digits(x: int) -> list[int]:
    digits: list[int] = []
    while x > 0:
        digits.append(x % 10)
        x //= 10
    digits.reverse()
    return digits


def render_sprite(x: int, y: int, indexes: list[int]) -> bytes:
    out = struct.pack("BB", x + 8, y + 16)
    out += bytes(index + OPERATOR_TILE_OFFSET for index in indexes)
    out += bytes([0xFF])
    return out


def has_left_edge(puzzle: Puzzle, x: int, y: int) -> bool:
    mask = puzzle.edges[y] >> (x * 2)
    return (mask & 1) != 0


def render_sprites(puzzle: Puzzle) -> bytes:
    sprites: list[bytes] = []
    total_sprites = 0
    for cage in puzzle.cages:
        top_tile = find_top_tile(cage)
        x = get_sprite_x0(top_tile[0])
        # Move text 1 pixel left if there is no left edge
        if not has_left_edge(puzzle, top_tile[0], top_tile[1]):
            x -= 1
        y = get_sprite_y0(top_tile[1])
        indexes = get_digits(cage.target)
        if isinstance(cage, GroupCage):
            indexes.append(CAGE_OPERATOR_TILE_IDX[cage.op])
        sprites.append(render_sprite(x, y, indexes))
        total_sprites += len(indexes)
    # 37 = 40 (total sprites) - 3 (cursor sprites)
    assert total_sprites < 37
    out = bytes([len(sprites)])
    for sprite in sprites:
        out += sprite
    return out


def render_values(puzzle: Puzzle) -> bytes:
    packed_values: list[int] = []
    for y in range(4):
        row = 0x00
        for x in range(3, -1, -1):
            row <<= 2
            row |= puzzle.values[y][x] - 1
        packed_values.append(row)
    return bytes(packed_values)


def render_puzzle(puzzle: Puzzle, outfile: str):
    validate_puzzle(puzzle)
    out = render_values(puzzle)
    out += render_sprites(puzzle)
    out += bytes(puzzle.edges)
    with open(outfile, "wb") as outf:
        outf.write(out)
