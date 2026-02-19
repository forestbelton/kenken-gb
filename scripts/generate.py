import enum
import dataclasses
import random


class CageOperator(enum.Enum):
    ADD = "ADD"
    SUB = "SUB"
    MUL = "MUL"
    DIV = "DIV"


OPERATOR_CHARS: dict[CageOperator, str] = {
    CageOperator.ADD: "+",
    CageOperator.SUB: "-",
    CageOperator.MUL: "*",
    CageOperator.DIV: "/",
}


@dataclasses.dataclass
class GroupCage:
    op: CageOperator
    target: int
    tiles: list[tuple[int, int]]

    def key(self) -> str:
        return f"{self.target}{OPERATOR_CHARS[self.op]}"


@dataclasses.dataclass
class SingletonCage:
    target: int
    x: int
    y: int

    def key(self) -> str:
        return str(self.target)


Cage = SingletonCage | GroupCage


@dataclasses.dataclass
class Puzzle:
    cages: list[Cage]
    values: list[list[int]]
    edges: list[int]


def generate_latin_square(n: int = 4) -> list[list[int]]:
    """Generate a random valid n x n Latin square with values 1..n."""
    base = list(range(1, n + 1))
    grid: list[list[int]] = []
    for r in range(n):
        row = base[r:] + base[:r]
        grid.append(row)

    # Shuffle rows within top/bottom halves, then shuffle columns
    top = grid[: n // 2]
    bottom = grid[n // 2 :]
    random.shuffle(top)
    random.shuffle(bottom)
    grid = top + bottom

    # Shuffle columns
    col_order = list(range(n))
    random.shuffle(col_order)
    grid = [[row[c] for c in col_order] for row in grid]

    # Randomly permute the values
    perm = list(range(1, n + 1))
    random.shuffle(perm)
    mapping = {i + 1: perm[i] for i in range(n)}
    grid = [[mapping[v] for v in row] for row in grid]

    return grid


def get_neighbors(x: int, y: int, n: int = 4) -> list[tuple[int, int]]:
    neighbors: list[tuple[int, int]] = []
    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        nx, ny = x + dx, y + dy
        if 0 <= nx < n and 0 <= ny < n:
            neighbors.append((nx, ny))
    return neighbors


def partition_into_cages(n: int = 4) -> list[list[tuple[int, int]]]:
    """Partition an n x n grid into connected cages of size 1-4."""
    all_cells = {(r, c) for r in range(n) for c in range(n)}
    assigned: set[tuple[int, int]] = set()
    cages: list[list[tuple[int, int]]] = []

    cells_list = list(all_cells)
    random.shuffle(cells_list)

    for start in cells_list:
        if start in assigned:
            continue

        # Grow a cage using BFS/random expansion
        cage = [start]
        assigned.add(start)

        # Decide target size: 1, 2, or 3 cells (occasionally 4)
        max_size = random.choices([1, 2, 3, 4], weights=[1, 4, 3, 1])[0]

        frontier = [nb for nb in get_neighbors(*start, n) if nb not in assigned]

        while len(cage) < max_size and frontier:
            random.shuffle(frontier)
            next_cell = frontier.pop(0)
            if next_cell in assigned:
                continue
            cage.append(next_cell)
            assigned.add(next_cell)
            for nb in get_neighbors(next_cell[0], next_cell[1], n):
                if nb not in assigned and nb not in frontier:
                    frontier.append(nb)

        cages.append(cage)

    return cages


def assign_cage_operator(
    cage_cells: list[tuple[int, int]], grid: list[list[int]]
) -> Cage:
    """Assign an operator and compute the target for a cage."""
    values = [grid[r][c] for r, c in cage_cells]

    if len(cage_cells) == 1:
        r, c = cage_cells[0]
        return SingletonCage(target=grid[r][c], x=c, y=r)

    if len(cage_cells) == 2:
        a, b = values[0], values[1]
        # Possible ops: ADD, SUB, MUL, DIV
        possible_ops = [CageOperator.ADD, CageOperator.MUL]

        # SUB: |a - b|
        possible_ops.append(CageOperator.SUB)

        # DIV: only if one divides the other evenly
        big, small = max(a, b), min(a, b)
        if big % small == 0:
            possible_ops.append(CageOperator.DIV)

        op = random.choice(possible_ops)

        if op == CageOperator.ADD:
            target = a + b
        elif op == CageOperator.SUB:
            target = abs(a - b)
        elif op == CageOperator.MUL:
            target = a * b
        else:  # DIV
            target = big // small

        return GroupCage(op=op, target=target, tiles=[(c, r) for r, c in cage_cells])

    # 3+ cells: ADD or MUL
    op = random.choice([CageOperator.ADD, CageOperator.MUL])
    if op == CageOperator.ADD:
        target = sum(values)
    else:
        target = 1
        for v in values:
            target *= v

    return GroupCage(op=op, target=target, tiles=[(c, r) for r, c in cage_cells])


def get_cage_for_tile(cages: list[Cage], x: int, y: int) -> Cage:
    for cage in cages:
        if isinstance(cage, SingletonCage) and cage.x == x and cage.y == y:
            return cage
        elif isinstance(cage, GroupCage) and (x, y) in cage.tiles:
            return cage
    raise Exception(f"no cage for {x=}, {y=} found")


def calculate_edges(cages: list[Cage]) -> list[int]:
    edges: list[int] = []
    for y in range(4):
        row: list[int] = []
        for x in range(4):
            pos_cage = get_cage_for_tile(cages, x, y)
            left = 0
            if x > 0 and pos_cage != get_cage_for_tile(cages, x - 1, y):
                left = 1
            row.append(left)
            bottom = 0
            if y < 3 and pos_cage != get_cage_for_tile(cages, x, y + 1):
                bottom = 1
            row.append(bottom)
        row_mask = 0
        for bit in row[::-1]:
            row_mask <<= 1
            row_mask |= bit
        edges.append(row_mask)
    return edges


def generate_puzzle() -> Puzzle:
    """Generate a random 4x4 KenKen puzzle."""
    grid = generate_latin_square(4)
    cage_cells_list = partition_into_cages(4)
    cages = [assign_cage_operator(cells, grid) for cells in cage_cells_list]
    edges = calculate_edges(cages)
    return Puzzle(cages=cages, values=grid, edges=edges)
