# const.ts

const CELL_EMPTY = Int8(0)
const CELL_WALL  = Int8(1)
const CELL_LASER = Int8(2)
const CELL_SLASH = Int8(3)  # /
const CELL_BACKS = Int8(4)  # \
const CELL_START = Int8(5)
const CELL_END   = Int8(6)
const CELL_X     = Int8(7)

const CELL_STRING = Dict(
    CELL_EMPTY => " ",
    CELL_WALL  => "#",
    CELL_LASER => "￭",
    CELL_SLASH => "/",
    CELL_BACKS => "\\",
    CELL_START => "s",
    CELL_END   => "e",
    CELL_X     => "x",
)


function println_m(m_m::Matrix{Int8})
    for i in 1:size(m_m,1)
        for j in 1:size(m_m,2)
            cell = m_m[i,j]
            if 0 <= cell <= 7
                print(CELL_STRING[cell])
            else
                print(-cell-1)
            end
            print(" ")
        end
        println()
    end
end

#=
CELL_0 ~ CELL_17は -1 ~ -18までを割り振る
=#
CELL_N(n::Int) = Int8(-n-1)

# 方向のID定義
# x軸: →
# y軸: ↓
const DIR_LEFT  = Int8(1)  # dx = -1, dy =  0
const DIR_UP    = Int8(2)  # dx =  0, dy = -1
const DIR_RIGHT = Int8(3)  # dx =  1, dy =  0
const DIR_DOWN  = Int8(4)  # dx =  0, dy =  1

# IDから実際の (dx, dy) への逆引き表（@inbounds で安全に叩ける具象型のタプル配列）
const DIR_VECTORS = (
    (-Int8(1),  Int8(0)), # 1: LEFT
    ( Int8(0), -Int8(1)), # 2: UP
    ( Int8(1),  Int8(0)), # 3: RIGHT
    ( Int8(0),  Int8(1))  # 4: DOWN
)
# 逆変換
const VECTORS_TO_DIR = Dict(
    (-Int8(1),  Int8(0)) => DIR_LEFT , # 1: LEFT
    ( Int8(0), -Int8(1)) => DIR_UP   , # 2: UP
    ( Int8(1),  Int8(0)) => DIR_RIGHT, # 3: RIGHT
    ( Int8(0),  Int8(1)) => DIR_DOWN   # 4: DOWN
)

# CELL_EMPTY = 0, CELL_WALL = 1
const empty_board = Int8[
    1 1 1 1 1 1 1;
    1 0 0 0 0 0 1;
    1 0 0 0 0 0 1;
    1 0 0 0 0 0 1;
    1 0 0 0 0 0 1;
    1 0 0 0 0 0 1;
    1 1 1 1 1 1 1
]

# 1. x, y を持つ座標の型を定義
struct Point
    x::Int
    y::Int
end

# 2. MinoPattern の型を定義
mutable struct MinoPattern
    protrusion::Vector{Point}   # Pointの可変長配列（TypeScriptの [] に対応）
    offset::Point               # Point型のオブジェクト
    vertex::Vector{Int}         # 整数（Int）の可変長配列
end

# const MINO_PATTERN = MinoPattern[
#     MinoPattern([Point( 0,-2 ), Point( 0,-1 )], Point( 0, 1 ), [  0, -50,  50, -50,  50, 100,   0, 100]),
#     MinoPattern([Point( 0,-2 ), Point( 0,-1 )], Point( 0, 1 ), [  0, -50,  50, -50,  50, 100,   0, 100]),
#     MinoPattern([Point( 0,-1 ), Point( 0, 1 )], Point( 0, 0 ), [  0, -50,  50, -50,  50, 100,   0, 100]),
#     MinoPattern([Point(-2, 0 ), Point(-1, 0 )], Point( 1, 0 ), [-50,   0, 100,   0, 100,  50, -50,  50]),
#     MinoPattern([Point(-1, 0 ), Point( 1, 0 )], Point( 0, 0 ), [-50,   0, 100,   0, 100,  50, -50,  50]),
#     MinoPattern([Point( 1, 0 ), Point( 2, 0 )], Point(-1, 0 ), [-50,   0, 100,   0, 100,  50, -50,  50]),
#     MinoPattern([Point( 0,-1 ), Point(-1, 0 )], Point( 0, 0 ), [  0,   0,   0, -50,  50, -50,  50,  50, -50,  50, -50,   0]),
#     MinoPattern([Point( 0,-1 ), Point( 1, 0 )], Point( 0, 0 ), [  0,  50,   0, -50,  50, -50,  50,   0, 100,   0, 100,  50]),
#     MinoPattern([Point( 1, 0 ), Point( 0, 1 )], Point( 0, 0 ), [  0, 100,   0,   0, 100,   0, 100,  50,  50,  50,  50, 100]),
#     MinoPattern([Point(-1, 0 ), Point( 0, 1 )], Point( 0, 0 ), [-50,   0,  50,   0,  50, 100,   0, 100,   0,  50, -50,  50]),
#     MinoPattern([Point(-1, 1 ), Point( 0, 1 )], Point( 0,-1 ), [  0,   0,   0, -50,  50, -50,  50,  50, -50,  50, -50,   0]),
#     MinoPattern([Point(-1,-1 ), Point(-1, 0 )], Point( 1, 0 ), [  0,  50,   0, -50,  50, -50,  50,   0, 100,   0, 100,  50]),
#     MinoPattern([Point( 0,-1 ), Point( 1,-1 )], Point( 0, 1 ), [  0, 100,   0,   0, 100,   0, 100,  50,  50,  50,  50, 100]),
#     MinoPattern([Point( 1, 0 ), Point( 1, 1 )], Point(-1, 0 ), [-50,   0,  50,   0,  50, 100,   0, 100,   0,  50, -50,  50]),
#     MinoPattern([Point( 0, 1 ), Point( 1, 1 )], Point( 0,-1 ), [  0,  50,   0, -50,  50, -50,  50,   0, 100,   0, 100,  50]),
#     MinoPattern([Point(-1, 0 ), Point(-1, 1 )], Point( 1, 0 ), [  0, 100,   0,   0, 100,   0, 100,  50,  50,  50,  50, 100]),
#     MinoPattern([Point(-1,-1 ), Point( 0,-1 )], Point( 0, 1 ), [-50,   0,  50,   0,  50, 100,   0, 100,   0,  50, -50,  50]),
#     MinoPattern([Point( 1,-1 ), Point( 1, 0 )], Point(-1, 0 ), [  0,   0,   0, -50,  50, -50,  50,  50, -50,  50, -50,   0])
# ]

const MINO_PATTERN = MinoPattern[
    MinoPattern([Point( 0,-2 ), Point( 0,-1 )], Point( 0, 1 ), [  0, -50,  50, -50,  50, 100,   0, 100] ),
    MinoPattern([Point( 0,-1 ), Point( 0, 1 )], Point( 0, 0 ), [  0, -50,  50, -50,  50, 100,   0, 100] ),
    MinoPattern([Point( 0, 1 ), Point( 0, 2 )], Point( 0,-1 ), [  0, -50,  50, -50,  50, 100,   0, 100] ),
    MinoPattern([Point(-2, 0 ), Point(-1, 0 )], Point( 1, 0 ), [-50,   0, 100,   0, 100,  50, -50,  50] ),
    MinoPattern([Point(-1, 0 ), Point( 1, 0 )], Point( 0, 0 ), [-50,   0, 100,   0, 100,  50, -50,  50] ),
    MinoPattern([Point( 1, 0 ), Point( 2, 0 )], Point(-1, 0 ), [-50,   0, 100,   0, 100,  50, -50,  50] ),
    MinoPattern([Point( 0,-1 ), Point(-1, 0 )], Point( 0, 0 ), [  0,   0,   0, -50,  50, -50,  50,  50, -50,  50, -50,   0]),
    MinoPattern([Point( 0,-1 ), Point( 1, 0 )], Point( 0, 0 ), [  0,  50,   0, -50,  50, -50,  50,   0, 100,   0, 100,  50]),
    MinoPattern([Point( 1, 0 ), Point( 0, 1 )], Point( 0, 0 ), [  0, 100,   0,   0, 100,   0, 100,  50,  50,  50,  50, 100]),
    MinoPattern([Point(-1, 0 ), Point( 0, 1 )], Point( 0, 0 ), [-50,   0,  50,   0,  50, 100,   0, 100,   0,  50, -50,  50]),
    MinoPattern([Point(-1, 1 ), Point( 0, 1 )], Point( 0,-1 ), [  0,   0,   0, -50,  50, -50,  50,  50, -50,  50, -50,   0]),
    MinoPattern([Point(-1,-1 ), Point(-1, 0 )], Point( 1, 0 ), [  0,  50,   0, -50,  50, -50,  50,   0, 100,   0, 100,  50]),
    MinoPattern([Point( 0,-1 ), Point( 1,-1 )], Point( 0, 1 ), [  0, 100,   0,   0, 100,   0, 100,  50,  50,  50,  50, 100]),
    MinoPattern([Point( 1, 0 ), Point( 1, 1 )], Point(-1, 0 ), [-50,   0,  50,   0,  50, 100,   0, 100,   0,  50, -50,  50]),
    MinoPattern([Point( 0, 1 ), Point( 1, 1 )], Point( 0,-1 ), [  0,  50,   0, -50,  50, -50,  50,   0, 100,   0, 100,  50]),
    MinoPattern([Point(-1, 0 ), Point(-1, 1 )], Point( 1, 0 ), [  0, 100,   0,   0, 100,   0, 100,  50,  50,  50,  50, 100]),
    MinoPattern([Point(-1,-1 ), Point( 0,-1 )], Point( 0, 1 ), [-50,   0,  50,   0,  50, 100,   0, 100,   0,  50, -50,  50]),
    MinoPattern([Point( 1,-1 ), Point( 1, 0 )], Point(-1, 0 ), [  0,   0,   0, -50,  50, -50,  50,  50, -50,  50, -50,   0])
];

mutable struct CellData
    x::Int
    y::Int
    type::Int8
end

mutable struct MinoData
    cell::Vector{CellData}
    vertex::Vector{Int}
    pos::Union{Point, Nothing}
end

mutable struct LaserData
    start_p::Point
    end_p::Point
    board::Matrix{Int8}
    vertex::Vector{Int}
end

mutable struct PuzzleData
    board::Matrix{Int8}
    mino_data::Vector{MinoData}
    laser::Vector{LaserData}
end

const new_year_2026 = PuzzleData(
    Int8[
        1 1 1 1 1 1 1;
        6 0 0 0 0 0 1;
        6 0 0 0 0 0 1;
        1 0 0 0 0 0 5;
        1 0 0 0 0 0 1;
        1 0 0 0 0 0 1;
        1 1 1 5 1 1 1
    ],
    [
        MinoData( [CellData(-1,  0, CELL_BACKS),CellData( 0,  0, CELL_SLASH),CellData( 1, 0, CELL_BACKS)], [-50,   0, 100,   0, 100,  50, -50,  50                    ], nothing),
        MinoData( [CellData( 0,  1, CELL_LASER),CellData(-1,  0, CELL_LASER),CellData( 0, 0, CELL_SLASH)], [-50,   0,  50,   0,  50, 100,   0, 100,   0,  50, -50,  50], nothing),
        MinoData( [CellData( 0, -1, CELL_LASER),CellData( 0,  0, CELL_BACKS),CellData( 0, 1, CELL_SLASH)], [  0, -50,  50, -50,  50, 100,   0, 100                    ], nothing),
        MinoData( [CellData(-1,  0, CELL_BACKS),CellData( 0,  0, CELL_SLASH),CellData( 1, 0, CELL_SLASH)], [-50,   0, 100,   0, 100,  50, -50,  50                    ], nothing),
        MinoData( [CellData( 0, -1, CELL_LASER),CellData( 0,  0, CELL_LASER),CellData( 0, 1, CELL_SLASH)], [  0, -50,  50, -50,  50, 100,   0, 100                    ], nothing),
        MinoData( [CellData( 1,  0, CELL_BACKS),CellData( 0, -1, CELL_LASER),CellData( 0, 0, CELL_LASER)], [  0,  50,   0, -50,  50, -50,  50,   0, 100,   0, 100,  50], nothing),
        MinoData( [CellData( 0,  0, CELL_LASER),CellData( 0, -1, CELL_SLASH),CellData(-1, 0, CELL_BACKS)], [  0,   0,   0, -50,  50, -50,  50,  50, -50,  50, -50,   0], nothing)
    ],
    [
        LaserData(    
            Point(3, 6),
            Point(0, 1),
            Int8[
                1 1 1 2 1 1 1;
                1 0 0 2 0 0 1;
                1 0 0 2 0 0 1;
                1 0 0 2 0 0 1;
                1 0 0 2 0 0 1;
                1 0 0 2 0 0 1;
                1 1 1 2 1 1 1
            ],
            [125, 275, 125, 225, 125, 175, 125, 125, 125, 75, 125, 25, 125, -25]
        ),
        LaserData(  
            Point(6, 3),
            Point(0, 2),
            Int8[
                1 1 1 1 1 1 1;
                1 0 0 0 0 0 1;
                1 0 0 0 0 0 1;
                2 2 2 2 2 2 2;
                1 0 0 0 0 0 1;
                1 0 0 0 0 0 1;
                1 1 1 1 1 1 1
            ],
            [275, 125, 225, 125, 175, 125, 125, 125, 75, 125, 25, 125, -25, 125]
        )
    ]
)

### fuction.ts
function compose_n(n, f)
    return function(a)
        result = a
        for _ in 1:n
            result = f(result)
        end
        return result
    end
end

function while_f(f, a)
    cont = true
    while cont
        cont, a = f(a)
    end
    return a
end

function replace_array(base::Vector{T}, index::Int, other::T) where T
    new_array = copy(base)     # 元の配列をコピー
    new_array[index] = other   # 指定したインデックス（1始まり）を書き換え
    return new_array
end
function replace_array!(base::Vector{T}, index::Int, other::T) where T
    base[index] = other
    return base
end
function replace_2d_array(base::Matrix{Int8}, x::Int, y::Int, other::Int8)
    new_matrix = copy(base)     # 盤面全体をきれいにコピー（structuredClone相当）
    new_matrix[y, x] = other    # 指定した座標 [行, 列] を直接書き換え（1始まり）
    return new_matrix
end
function replace_2d_array!(base::Matrix{Int8}, x::Int, y::Int, other::Int8)
    base[y, x] = other
    return base
end

### simulate_laser.ts


const REFLECT_DIR_TABLE = (
    (DIR_DOWN , DIR_UP   ), # (1,1)=(←,/) => (↓)    (1,2)=(←,\) => (↑)
    (DIR_RIGHT, DIR_LEFT ), # (2,1)=(↑,/) => (→)    (2,2)=(↑,\) => (←)
    (DIR_UP   , DIR_DOWN ), # (3,1)=(→,/) => (↑)    (3,2)=(→,\) => (↓)
    (DIR_LEFT , DIR_RIGHT)  # (4,1)=(↓,/) => (←)    (4,2)=(↓,\) => (→)
)
# const DIR_VECTORS = (
#     (-Int8(1),  Int8(0)), # 1: LEFT
#     ( Int8(0), -Int8(1)), # 2: UP
#     ( Int8(1),  Int8(0)), # 3: RIGHT
#     ( Int8(0),  Int8(1))  # 4: DOWN
# )
const REFLECT_MOVE_TABLE = Dict(
    (-Int8(1),  Int8(0)) => (( Int8(0),  Int8(1)), ( Int8(0), -Int8(1))), # 1: LEFT
    ( Int8(0), -Int8(1)) => (( Int8(1),  Int8(0)), (-Int8(1),  Int8(0))), # 2: UP
    ( Int8(1),  Int8(0)) => (( Int8(0), -Int8(1)), ( Int8(0),  Int8(1))), # 3: RIGHT
    ( Int8(0),  Int8(1)) => ((-Int8(1),  Int8(0)), ( Int8(1),  Int8(0)))  # 4: DOWN
)

"""
鏡に進んできた方向dir_idに対してどう反射するかを返す関数
"""
function reflect_dir(dir_id::Int8, mirror_type::Int8)::Int8
    #@show dir_id, mirror_type
    if mirror_type == CELL_SLASH
        return REFLECT_DIR_TABLE[dir_id][1]
    elseif mirror_type == CELL_BACKS
        return REFLECT_DIR_TABLE[dir_id][2]
    end
end
function reflect_dir(move::Tuple{Int8, Int8}, mirror_type::Int8)::Tuple{Int8, Int8}
    if mirror_type == CELL_SLASH
        return REFLECT_MOVE_TABLE[move][1]
    elseif mirror_type == CELL_BACKS
        return REFLECT_MOVE_TABLE[move][2]
    end
end


mutable struct LaserState
    board::Matrix{Int8}
    x::Int
    y::Int
    move::Int8
    vertex::Vector{Int}
end

function simulate_laser(board::Matrix{Int8}, start_pos::Point)
    
    function move!(data::LaserState)
        dx, dy = DIR_VECTORS[data.move]
        new_x = data.x + dx
        new_y = data.y + dy
        replace_2d_array!(data.board, new_x + 1, new_y + 1, CELL_LASER)

        look_cell = board[new_y+1, new_x+1]
        new_move = data.move
        if look_cell == CELL_SLASH || look_cell == CELL_BACKS
            new_move = reflect_dir(data.move, look_cell)
        end

        data.x = new_x
        data.y = new_y
        data.move = new_move
        push!(data.vertex, new_x * 50 - 25)
        push!(data.vertex, new_y * 50 - 25)
        return new_move
    end

    init_board = replace_2d_array(empty_board, start_pos.x + 1, start_pos.y + 1, CELL_LASER)
    init_move  = if start_pos.x == 0
        DIR_RIGHT
    elseif start_pos.x == 6
        DIR_LEFT
    elseif start_pos.y == 0
        DIR_DOWN
    else
        DIR_UP
    end
    initial = LaserState(init_board, start_pos.x + 1, start_pos.y + 1, init_move, [start_pos.x * 50 - 25, start_pos.y * 50 - 25])

    return while_f(initial) do s
        move!(s)
        cont = 0 < s.x < 6 && 0 < s.y < 6
        return (cont, s)
    end
end


### generate.ts

mutable struct TSRandom
    x::Int32
    y::Int32
    z::Int32
    w::Int32

    function TSRandom(seed::Int32 = Int32(88675123))
        init_x = Int32(123456789)
        init_y = Int32(362436069)
        init_z = Int32(521288629)
        init_w = seed
        new(init_x, init_y, init_z, init_w)
    end

end
TSRandom(seed::Int64) = TSRandom(Int32(seed))

function next(rnd::TSRandom)
    t = xor(rnd.x,(rnd.x<<11))
    rnd.x = rnd.y
    rnd.y = rnd.z
    rnd.z = rnd.w
    rnd.w = xor(xor(rnd.w,rnd.w >>> 19), xor(t, (t >>> 8)))
    return rnd.w
end

# min ~ max-1 の間の数
function next_int(rnd::TSRandom, min::Int32, max::Int32)::Int32
    #println("\nalarm_int:",rnd)
    r = abs(Int64(next(rnd)))
    #min == max && return 0
    return min + Int32(r % (max - min))
end
next_int(rnd::TSRandom, min::Int64, max::Int64)::Int64 = Int64(next_int(rnd,Int32(min),Int32(max)))

function next_bool(rnd::TSRandom)
    #println("\nalarm_bool:",rnd)
    r = abs(Int64(next(rnd)))
    return (r % 2) != 0
end

### =========================================================================== ###
### generate 関数関係
### =========================================================================== ###


const DIFFICULTY::Int = 3  # 1 2 3 がある (1=normal 2=oni 3=oniplus)
const MINO_MIRROR_TABLE = (
    (4, 6),     # normal
    (5, 8),     # oni
    (7, 13)     # oniplus
)

mutable struct DrawLaser
    board::Matrix{Int8}
    x::Int64
    y::Int64
    move::Tuple{Int8, Int8}
    mirror::Int64   # mirrorの予算
end

# 1マス進んで 進んだマスの座標に boardに書き込む
function inner_draw_laser(data::DrawLaser)::DrawLaser
    x = data.x + data.move[1]
    y = data.y + data.move[2]
    board = replace_2d_array(data.board, x+1, y+1, CELL_LASER)
    return DrawLaser(board, x, y, data.move, data.mirror)
end

# ミラー設置関数
function set_mirror(RND::TSRandom, data::DrawLaser)::DrawLaser
    x = data.x + data.move[1]
    y = data.y + data.move[2]
    board = copy(data.board)

    # どっちのミラーを置くか
    random_turn = next_bool(RND)
    
    # 鏡の消費
    mirror = if board[y+1, x+1] == CELL_EMPTY
        # 目の前がEMPTYなら鏡を置く
        data.mirror - 1
    else
        # 目の前がEMPTYでない(仕様的には"/"もしくは"\"となるはず)
        data.mirror
    end

    if board[y+1, x+1] == CELL_EMPTY
        if random_turn
            # random_turnがtrue (右に曲がる)
            replace_2d_array!(board, x+1, y+1, data.move[1] != 0 ? CELL_BACKS : CELL_SLASH)
            # data.move[1] != 0 つまり横の動きなら"\" 縦の動きなら"/" で右に曲がる
        else
            # random_turnがfalse (左に曲がる)
            replace_2d_array!(board, x+1, y+1, data.move[1] == 0 ? CELL_BACKS : CELL_SLASH)
            # data.move[1] == 0 つまり縦の動きなら"\" 横の動きなら"/" で左に曲がる
        end
    # else # は何もしない
    end
    
    return DrawLaser(board, data.x, data.y, data.move, mirror)  # 座標を進めはしない。
end

#=
    // 反射関数
    const reflection = (data: DrawLaser) => {
        const x = data[1] + data[3][0];
        const y = data[2] + data[3][1];
        const turn_move = (direction: boolean, move: Move): Move => {
            if (direction) {
                switch (move[1]) {
                    case 0: return [0, move[0]];
                    case 1: return [-1, 0];
                    case -1: return [1, 0];
                    // [a, b] => [-b, a] 右折
                }
            }
            else {
                switch (move[0]) {
                    case 0: return [move[1], 0];
                    case 1: return [0, -1];
                    case -1: return [0, 1];
                    // [a, b] => [b, -a] 左折
                }
            }
        };
        const move: Move = (() => {
            if (data[0][y][x] === "/") {
                return turn_move(data[3][0] === 0, data[3])
                # data[3][0] === 0なら縦方向の動き
                # data[3][1]が 1(下方向)なら[-1, 0](左向き)
                # data[3][1]が-1(上方向)なら[ 1, 0](右向き)
                # data[3][0] !== 0なら横方向の向き
                # data[3][0]が 1(右方向)なら[0, -1](上向き)
                # data[3][0]が-1(左方向)なら[0,  1](下向き)
            }
            else if (data[0][y][x] === "\\") {
                return turn_move(data[3][0] !== 0, data[3])
                # data[3][0] !== 0なら横方向の動き
                # data[3][0]が 1(右方向)なら[0,  1](下向き)
                # data[3][0]が-1(左方向)なら[0, -1](上向き)
                # data[3][0] === 0なら縦方向の向き
                # data[3][1]が 1(下方向)なら[ 1, 0](右向き)
                # data[3][1]が-1(上方向)なら[-1, 0](左向き)
            }
            else {
                return data[3]; # そのまま
            }
        })();
        const new_data: DrawLaser = [data[0], x, y, move, data[4]];
        return new_data;
    }
=#

# 反射関数
function reflection(data::DrawLaser)::DrawLaser
    x = data.x + data.move[1]
    y = data.y + data.move[2]

    move = if data.board[y+1, x+1] == CELL_SLASH || data.board[y+1, x+1] == CELL_BACKS
        # 鏡なら曲がる
        reflect_dir(data.move, data.board[y+1, x+1])
    else
        # そうでないならそのままの向きで
        data.move
    end
    return DrawLaser(data.board, x, y, move, data.mirror)   # 座標を進め(鏡の上かも)、向きを変える
end

function move_laser(RND::TSRandom, data::Vector{DrawLaser})::Vector{DrawLaser}
    current = data[end]
    board::Matrix{Int8}     = current.board
    # ここでのx,yは、壁も含めたボード全体での0-indexed座標。
    x::Int64                = current.x
    y::Int64                = current.y
    move::Tuple{Int8, Int8} = current.move      # Tuple{Int8, Int8}の形式
    mirror::Int64           = current.mirror

    #=
    
        
        // 進行方向の軸で取り出す
        const pick: [string, string[], string] = move[0] === 0
            ? [board[3][x - move[1]],   # 中央行の x-move[1]列目
            board.map((a) => a[x]),  # x 列目
            board[3][x + move[1]]]   # 中央行の x+move[1]列目
            : [board[y - move[0]][3],   # 中央列の y-move[0]行目
            board[y],                # y行目
            board[y + move[0]][3]];  # 中央列の y+move[0]行目
        // ソート
        const sort = move[0] + move[1] < 0  # ← moveがどちらかが負の時にひっくり返す(正の向きに直す) 
            ? [...pick[1]].reverse().map(e => e.replace(/u002F/g, "w").replace(/u005C/g, "/").replace(/w/g, "\\"))
            : [...pick[1]];
        // 後ろをトリミング
        const trim_forward = (() => {
            if (move[0] === 0) {
                // Y軸移動
                if (move[1] === 1) { return [...sort].slice(y + 1, sort.length - 1); }     
                    # ↑縦の正方向に移動するとき。 ひっくり返した配列の自分の場所(y)からあと、配列の最後までを取る
                    # sort.length-2番目まで取られるが、sort.length-1番目は壁"#"があるのでよい
                    # つまり壁"#"は配列に含めない
                else { return [...sort].slice(sort.length - y, [...sort].length - 1); }
                    # ↑縦の負の方向に移動するとき。ひっくり返した配列の自分の場所(ひっくり返したのでsort.length - 1 - y)よりあと、配列の最後までを取る。
            }
            else {
                // X軸移動
                if (move[0] === 1) { return [...sort].slice(x + 1, sort.length - 1); }
                    # ↑横の正方向に移動するとき。おなじ。壁"#"は含まない
                else { return [...sort].slice(sort.length - x, [...sort].length - 1); }
                    # 壁"#"は含まない
            }
        })();
        // 最初に衝突するミラーから後をトリミング
        const trim_mirror = (() => {
            const trim_r_mirror = trim_forward.includes("/")
                ? [...trim_forward].slice(0, trim_forward.indexOf("/") + 1)
                    # ↑ "/" が含まれている場合、配列の最初から"/"までを取る。なので配列の最後のみに"/"は含まれる。
                : [...trim_forward];
                    # ↑ "/"が含まれていない場合。そのまま返す。
            const trim_l_mirror = trim_forward.includes("\\")
                ? [...trim_r_mirror].slice(0, trim_forward.indexOf("\\") + 1)
                    # ↑ "\"が含まれている場合、配列の最初から"\"までを取る。なので配列の最後のみに"\"は含まれる。
                : [...trim_r_mirror];
            if (mirror > 0) {
                # 予算がある場合
                const trim_deadend_mirror = (() => {
                    const left_is_wall = [...trim_l_mirror][trim_l_mirror.length - 1] === "/" && pick[0] === "#";
                        # left_is_wallは、配列の最後が "/" だった場合、pick[0]が壁"#"かどうかを見ている
                        # pick[0]は動きが縦なら中央行のx-move[1]+1列目。
                        # move[1]が1なら、moveは下方向に向いている。この向きで"/"にあたると、自分の一つ左の列に行く。
                        # それこそ x-1列目 (=x-move[1]列目)
                        # move[1]が-1なら、moveは上方向に向いている。この向きで"/"にあたると、自分の一つ右の列に行く。
                        # それこそ x+1列目 (=x-move[1]列目)
                        # 動きが横なら中央列のy-move[0]行目
                        # move[0]が1なら、moveは右方向に向いている。この向きで"/"にあたると、自分の一つ上の列に行く。
                        # それこそy-1行目 (=y-move[0]行目)
                        # move[0]が-1なら、moveは左方向に向いている。この向きで"/"にあたると、自分の一つ下の列に行く。
                        # それこそy+1行目 (=y-move[0]行目)
                        # 結果的にpick[0] == "#"は鏡で反射した後が壁かどうかを見ている。
                        # 返す値は true / false
                    const right_is_wall = [...trim_l_mirror][trim_l_mirror.length - 1] === "\\" && pick[2] === "#";
                        # right_is_wallは、配列の最後が "\" だった場合、pick[2]が壁"#"かどうかを見ている
                        # pick[2]は動きが縦なら中央行のx+move[1]+1列目。
                        # move[1]が1なら、moveは下方向に向いている。この向きで"\"にあたると、自分の一つ右の列に行く。
                        # それこそ x+1列目 (=x+move[1]列目)
                        # move[1]が-1なら、moveは上方向に向いている。この向きで"\"にあたると、自分の一つ左の列に行く。
                        # それこそ x-1列目 (=x+move[1]列目)
                        # 動きが横なら中央列のy+move[0]行目
                        # move[0]が1なら、moveは右方向に向いている。この向きで"\"にあたると、自分の一つ下の列に行く。
                        # それこそy+1行目 (=y+move[0]行目)
                        # move[0]が-1なら、moveは左方向に向いている。この向きで"\"にあたると、自分の一つ上の列に行く。
                        # それこそy-1行目 (=y+move[0]行目)
                        # 結果的にpick[2] == "#"は鏡で反射した後が壁かどうかを見ている。
                        # 返す値は true / false
                    return left_is_wall || right_is_wall
                        # もし、行き先に壁があった場合
                        ? [...trim_l_mirror].slice(0, trim_l_mirror.length - 1)
                        # 配列を最初からtrim_l_mirror.length-2まで。つまり最後の要素を切り取る。
                        : [...trim_l_mirror];
                        # そうでないならそのまま。
                })();
                return trim_deadend_mirror;     # => trim_mirrorに返している
            }
            else {
                # 鏡の予算が無い場合、配列の最後が鏡で、その先ですぐに壁に当たってもよい(そこをゴールにできる)
                return [...trim_l_mirror];  # => trim_mirrorに返している
            }
        })();

        結果的に、trim_mirrorしかこの後は使っていない。そしてそれは、鏡を置けるマスのインデックスの配列。
        鏡を置ける場所というのはつまり、moveの方向に進んだ先の(今のマスは含まず)"￭"以外のマスを候補に入れ、
        最初に現れた"/"もしくは"\"の後を候補から消す。(一番最初の"/"または"\"は候補に入れる)
        "/"または"\"の後、鏡の予算がまだあるのにすぐ壁なら、"/"または"\"のマスは候補から消す
        その候補のマスが、今の自分のマスからmoveの方向に何マス進んだものなのかを集計して返す。
        (0マスは自分の目の前のマスとする。)
        
    =#

    look_x = x
    look_y = y
    
    # 移動可能なマスまでの距離の配列
    range = Int[]
    
    for i in 0:6
        look_x += move[1]
        look_y += move[2]

        # 本家も"#"かどうかで判定していない
        if look_x <= 0 || 6 <= look_x   # 0-indexedなので本来のjuliaなら1~7だがこのxには0~6が入る
            break
        elseif look_y <= 0 || 6 <= look_y
            break
        end

        look_cell = board[look_y+1, look_x+1]
        if look_cell == CELL_LASER
            continue
        elseif look_cell == CELL_SLASH || look_cell == CELL_BACKS
            # 鏡にあたったときは終了の運命しかない
            if mirror > 0
                # 予算がある
                next_move = reflect_dir(move, look_cell)
                next_cell = board[look_y + next_move[2] + 1, look_x + next_move[1] + 1]
                if next_cell == CELL_WALL
                    # 次の座標が"#"なら追加せず終了
                    break
                else
                    # 次が大丈夫なら追加して終了
                    push!(range, i)
                    break
                end
            else
                # 予算が無ければ追加して終了
                push!(range, i)
                break
            end
        else
            push!(range, i)
        end
    end

    # その中からランダムに決める   ミラーを置く必要がないなら最長を選ぶ
    # random_range = if length(range) == 0
    #     0
    # else
    #     if mirror > 0
    #         range[next_int(RND, 0, length(range)) + 1]
    #     else
    #         range[end]
    #     end
    # end
    random_range = if mirror > 0
        if length(range) == 0
            #println("alarm_int:",RND)
            next(RND)
            0
        else
            range[next_int(RND, 0, length(range)) + 1]
        end
    else
        if length(range) == 0
            0
        else
            range[end]
        end
    end

    # 目的の場所の 一つ手前 まで行く。
    # rangeで出るのは目の前を0とした0-indexedの表示なのでこれでいい
    lined_data = current
    if random_range > 0
        for i in 1:random_range
            lined_data = inner_draw_laser(lined_data)
        end
    # else # random_range = 0 なら何もしない
    end

    # 返すデータを作成
    if mirror > 0
        # 一歩手前まで行った盤面から鏡を置いて反射！
        result = reflection(set_mirror(RND, lined_data))
        if length(range) != 0
            # 候補がまだあるならくっつけておく
            return vcat(data, result)
        else
            # 行き止まりならUndo  初回で行き止まりならループが終了するデータを返す
            if length(data) > 1
                return data[1:end-1]
            else
                return DrawLaser[DrawLaser(empty_board, 0, 0, DIR_VECTORS[DIR_DOWN], 0)]
            end
        end
    else
        # 予算がない場合

        # 一歩先に行った後を作る
        return_data = reflection(lined_data)

        return_board = if return_data.board[y+1, x+1] == CELL_EMPTY
            # まさかもし最初の座標がCELL_EMPTYなんてことないですよね...?
            # 一応LASERを引いておきます
            replace_2d_array(return_data.board, return_data.x - return_data.move[1] + 1, return_data.y - return_data.move[2] + 1, CELL_LASER)
        else
            copy(return_data.board)
        end
        
        result = DrawLaser(return_board, return_data.x, return_data.y, return_data.move, return_data.mirror)
        return vcat(data, result)
    end
end

function draw_random_laser(RND::TSRandom, board::Matrix{Int8}, laser::@NamedTuple{mirror::Int64, x::Int64, y::Int64, move::Tuple{Int8, Int8}})::DrawLaser
    # 最初の状態を作成して履歴配列（Vector）に初期化
    initial = DrawLaser(board, laser.x, laser.y, laser.move, laser.mirror)
    data = DrawLaser[initial]

    while_count = 100
    while while_count > 0

        #println("\n==4==")
        #println(RND)
        for i in 1:lastindex(data)
            #Base.print_matrix(stdout,data[i].board)
            #println()
            #println(data[i].x," ", data[i].y, " ", data[i].move, " ", data[i].mirror)
        end
        #println(while_count)

        # move_laser を実行して履歴配列を更新
        data = move_laser(RND, data)


        current::DrawLaser = data[end]

        is_running = current.mirror > 0 || current.board[current.y+1, current.x+1] != CELL_WALL
        if !is_running
            break
        end

        while_count -= 1
    end

    # 最新のデータを返す
    return data[end]
end

function draw_one_laser(RND::TSRandom, laser0, laser1)::DrawLaser

    #println("\n==3==")
    #println(empty_board)
    #println(laser0)
    #println(laser1)

    data::DrawLaser = draw_random_laser(RND, empty_board, laser0)

    #println(data)
    
    if data.x != laser1.x || data.y != laser1.y
        return data
    else
        return draw_one_laser(RND, laser0, laser1)
    end
end

mutable struct TwoLaserResult
    board::Matrix{Int8}
    starts::Vector{Point}   # 両方とも0-indexed
    ends::Vector{Point}
end

global print_counter = 0

function draw_two_laser(RND::TSRandom, laser0, laser1, minoCount::Int, mirrorCount::Int)::TwoLaserResult
    draw_1_data::DrawLaser = draw_one_laser(RND, laser0, laser1)
    #error("hello")
    #global print_counter
    #println("\n", print_counter)
    #print_counter += 1
    println("==1==")
    #println(draw_1_data)
    println(RND)
    println_m(draw_1_data.board)
    println(draw_1_data.x," ",draw_1_data.y," ",draw_1_data.move," ",draw_1_data.mirror," ",)
    draw_2_data = draw_random_laser(RND, draw_1_data.board, laser1)
    println("==2==")
    #println(draw_2_data)
    println(RND)
    println_m(draw_2_data.board)
    println(draw_2_data.x," ",draw_2_data.y," ",draw_2_data.move," ",draw_2_data.mirror," ",)

    final_board = draw_2_data.board
    mirror_count = 0
    laser_cell_count = 0
    for cell in final_board
        if cell == CELL_SLASH || cell == CELL_BACKS
            mirror_count +=1
            laser_cell_count += 1
        elseif cell == CELL_LASER
            laser_cell_count += 1
        end
    end

    if laser_cell_count >= minoCount * 3 && mirror_count == mirrorCount
        # スタート(s)とエンド(e)を盤面に書き込む
        # ※ replace_2d_array を使って順番に書き換えていきます
        replace_2d_array!(final_board, laser0.x + 1, laser0.y + 1, CELL_START)
        replace_2d_array!(final_board, laser1.x + 1, laser1.y + 1, CELL_START)
        replace_2d_array!(final_board, draw_1_data.x + 1, draw_1_data.y + 1, CELL_END)
        replace_2d_array!(final_board, draw_2_data.x + 1, draw_2_data.y + 1, CELL_END)
        starts = [Point(laser0.x, laser0.y), Point(laser1.x, laser1.y)]
        ends   = [Point(draw_1_data.x, draw_1_data.y), Point(draw_2_data.x, draw_2_data.y)]
        return TwoLaserResult(final_board, starts, ends)
    else
        return draw_two_laser(RND, laser0, laser1, minoCount, mirrorCount)
    end
end

mutable struct PlaceMino
    board::Matrix{Int8}
    laser_cells::Vector{Point} # laser_cellsはレーザーの通ったセルの配列
    mino_data::Vector{MinoData}
end
# const TRIMINO_PATTERNS = (
#     ((1, 3), (2, 3)),   # (1,3),(2,3),(3,3)     #  0
#     ((2, 3), (4, 3)),   # (2,3),(3,3),(4,3)     #  1
#     ((4, 3), (5, 3)),   # (3,3),(4,3),(5,3)     #  2
#     ((3, 1), (3, 2)),   # (3,1),(3,2),(3,3)     #  3
#     ((3, 2), (3, 4)),   # (3,2),(3,3),(3,4)     #  4
#     ((3, 4), (3, 5)),   # (3,3),(3,4),(3,5)     #  5
#     ((2, 3), (3, 2)),   # (2,3),(3,3),(3,2)     #  6
#     ((2, 4), (3, 4)),   # (2,4),(3,4),(3,3)     #  7
#     ((4, 3), (4, 2)),   # (3,3),(4,3),(4,2)     #  8
#     ((2, 3), (3, 4)),   # (2,3),(3,3),(3,4)     #  9
#     ((4, 3), (4, 4)),   # (3,3),(4,3),(4,4)     # 10
#     ((2, 2), (3, 2)),   # (2,2),(3,2),(3,3)     # 11
#     ((3, 2), (4, 3)),   # (3,2),(3,3),(4,3)     # 12
#     ((3, 4), (4, 4)),   # (3,3),(3,4),(4,4)     # 13
#     ((2, 2), (2, 3)),   # (2,2),(2,3),(3,3)     # 14
#     ((3, 4), (4, 3)),   # (3,4),(3,3),(4,3)     # 15
#     ((2, 4), (2, 3)),   # (2,4),(2,3),(3,3)     # 16
#     ((3, 2), (4, 2)),   # (3,3),(3,2),(4,2)     # 17
# )

# XとYを入れ替えて両方 +1 したもの
const TRIMINO_PATTERNS = (
    ((0+1, 2+1), (1+1, 2+1)),   # (0, 2), (1, 2)
    ((1+1, 2+1), (3+1, 2+1)),   # (1, 2), (3, 2)
    ((3+1, 2+1), (4+1, 2+1)),   # (3, 2), (4, 2)
    ((2+1, 0+1), (2+1, 1+1)),   # (2, 0), (2, 1)
    ((2+1, 1+1), (2+1, 3+1)),   # (2, 1), (2, 3)
    ((2+1, 3+1), (2+1, 4+1)),   # (2, 3), (2, 4)
    ((1+1, 2+1), (2+1, 1+1)),   # (1, 2), (2, 1)
    ((1+1, 2+1), (2+1, 3+1)),   # (1, 2), (2, 3)
    ((2+1, 3+1), (3+1, 2+1)),   # (2, 3), (3, 2)
    ((2+1, 1+1), (3+1, 2+1)),   # (2, 1), (3, 2)
    ((3+1, 1+1), (3+1, 2+1)),   # (3, 1), (3, 2)
    ((1+1, 1+1), (2+1, 1+1)),   # (1, 1), (2, 1)
    ((1+1, 2+1), (1+1, 3+1)),   # (1, 2), (1, 3)
    ((2+1, 3+1), (3+1, 3+1)),   # (2, 3), (3, 3)
    ((3+1, 2+1), (3+1, 3+1)),   # (3, 2), (3, 3)
    ((2+1, 1+1), (3+1, 1+1)),   # (2, 1), (3, 1)
    ((1+1, 1+1), (1+1, 2+1)),   # (1, 1), (1, 2)
    ((1+1, 3+1), (2+1, 3+1)),   # (1, 3), (2, 3)
)

# レーザーが通るマスのランダムな位置にミノを1つ置く関数 置けなかった場合は引数をそのまま返す
function place_random_mino(RND::TSRandom, data::PlaceMino)::PlaceMino
    board = data.board
    # data.laser_cellsはレーザーの通ったセルの配列
    random_pos = data.laser_cells[next_int(RND, 0, length(data.laser_cells)) + 1]
    x = random_pos.x
    y = random_pos.y
    println("\n==5==")
    println(RND)
    println(data.laser_cells)
    println(x," ",y)
    println_m(board)
    #=
        [
            [                     " ",                          " ", board[y - 2]?.[x] ?? "#",                          " ",                      " "],
            [                     " ", board[y - 1]?.[x - 1] ?? "#", board[y - 1]?.[x] ?? "#", board[y - 1]?.[x + 1] ?? "#",                      " "],
            [board[y]?.[x - 2] ?? "#",     board[y]?.[x - 1] ?? "#",                      "x",     board[y]?.[x + 1] ?? "#", board[y]?.[x + 2] ?? "#"],
            [                     " ", board[y + 1]?.[x - 1] ?? "#", board[y + 1]?.[x] ?? "#", board[y + 1]?.[x + 1] ?? "#",                      " "],
            [                     " ",                          " ", board[y + 2]?.[x] ?? "#",                          " ",                      " "]
        ]
    =#
    # x,y 中心のマンハッタン距離が2以下となる部分を考えている。ミノはトリオミノなのでそりゃ考えたいわな
    placeable_cell = fill(CELL_EMPTY, 5,5)
    
    for i in -2:2
        for j in -2:2
            if abs(i)+abs(j) <= 2   # マンハッタン距離が2以下なら
                fixed_x = clamp(x+i, 0, 6)
                fixed_y = clamp(y+j, 0, 6)

                cell = board[fixed_y+1, fixed_x+1]
                if cell == CELL_SLASH || cell == CELL_BACKS
                    cell = CELL_LASER
                end

                placeable_cell[j+3, i+3] = cell
            end
        end
    end
    placeable_cell[3,3] = CELL_LASER
    println_m(placeable_cell)
    #println(placeable_cell[1,1]," ",placeable_cell[1,2]," ",placeable_cell[1,3])

    # ID:idxのトリオミノが置けるならidxをplaceable_minoに追加
    placeable_mino = Int[]
    for (idx, (pos1, pos2)) in enumerate(TRIMINO_PATTERNS)
        if placeable_cell[pos1...] == placeable_cell[pos2...] == CELL_LASER
            push!(placeable_mino, idx - 1)
        end
    end

    
    println(placeable_mino)

    #error("hello")
    # 置けるミノがあれば置き、できなければそのまま返す
    if length(placeable_mino) > 0
        random_mino_id = placeable_mino[next_int(RND, 0, length(placeable_mino)) + 1]
        place_mino = MINO_PATTERN[random_mino_id + 1]
        println(random_mino_id)
        println(place_mino.protrusion)
        place_cell = Point[
            Point( x + place_mino.protrusion[1].x, y + place_mino.protrusion[1].y),
            Point( x + place_mino.protrusion[2].x, y + place_mino.protrusion[2].y)
        ]

        # ミノの１番目のセルから３番目のセルをボードに配置している
        # replace_2d_arrayは二次元配列を置き換える独自関数
        println(x," ",y," ",place_cell[1]," ",place_cell[2])

        place_1 = copy(board)
        replace_2d_array!(place_1, x+1, y+1, CELL_N(random_mino_id))
        replace_2d_array!(place_1, place_cell[1].x + 1, place_cell[1].y + 1, CELL_N(random_mino_id))
        replace_2d_array!(place_1, place_cell[2].x + 1, place_cell[2].y + 1, CELL_N(random_mino_id))
        filtered_laser_cells = Vector{Point}()
        # for p in data.laser_cells
        #     is_overlap = random_pos == p || place_cell[1] == p || place_cell[2] == p
        #     if !is_overlap
        #         push!(filtered_laser_cells, p)
        #     end
        # end
        filtered_laser_cells = filter(data.laser_cells) do p
            p != random_pos && p != place_cell[1] && p != place_cell[2]
        end

        global print_counter
        println("\n == print_counter : $print_counter ==")
        print_counter += 1

        println("\n== 8 ==")
        println(data.laser_cells)
        println(filtered_laser_cells)
        


        return_mino_data = vcat(data.mino_data,
            MinoData(
                [
                    CellData(
                        place_mino.offset.x,
                        place_mino.offset.y,
                        board[y+1, x+1]
                    ),
                    CellData(
                        place_mino.protrusion[1].x + place_mino.offset.x,
                        place_mino.protrusion[1].y + place_mino.offset.y,
                        board[y + place_mino.protrusion[1].y + 1, x + place_mino.protrusion[1].x + 1]
                    ),
                    CellData(
                        place_mino.protrusion[2].x + place_mino.offset.x,
                        place_mino.protrusion[2].y + place_mino.offset.y,
                        board[y + place_mino.protrusion[2].y + 1, x + place_mino.protrusion[2].x + 1]
                    )
                ],
                place_mino.vertex,
                nothing
            )
        )

        return PlaceMino(place_1, filtered_laser_cells, return_mino_data)
    end
    return data
end

mutable struct InitPuzzleData
    board::Matrix{Int8}
    mino_data::Vector{MinoData}
    starts::Vector{Point}
    ends::Vector{Point}
end

# 一旦generate関数のガワだけを書いておくが、中身の関数の内、でかいやつはgenerate関数の外に書いておきたい。
function generate(mode::Int, seed::Int)
    if mode == 3 && seed == 20260101    # Int32なら21万年までは対応可能
        return new_year_2026
    end

    minoCount, mirrorCount = MINO_MIRROR_TABLE[mode]

    RND = TSRandom(seed)

    s_idx1 = min(next_int(RND, 0, 20), 18)
    # s_idx1 - 1番目とs_idx番目の間に"S"が挿入される -> "S"の位置は s_idx1 番目 (0-indexed)
    # 全体の文字の長さが18文字([0]~[17]なので、s_idx1=18,19で同じ結果になる。 -> "S"の位置は18番目 (0-indexed)

    s_idx2 = min(next_int(RND, 0, 21), 19)
    # もし s_idx2 > s_idx1 なら、最初の"S"の位置は s_idx1 番目になる。
    # もし s_idx2 = s_idx1 なら、s_idx2 - 1番目と s_idx2番目の間に"S"が挿入されるので、最初に挿入した"S"の位置が1ずれて、s_idx1+1になる。
    # 2番目に挿入した"S"の位置はs_idx2番目になる。
    # もし s_idx2 < s_idx1 なら、最初の"S"の位置は1つずれて、s_idx1+1番目になる。
    # 2番目に挿入した"S"の位置はs_idx2番目になる。

    if s_idx2 <= s_idx1
        s_idx1 += 1
    end

    function get_s(index::Int)::@NamedTuple{x::Int64, y::Int64, move::Tuple{Int8, Int8}}
        if index < 5
            return ( x= index + 1, y= 0, move= (Int8(0), Int8(1)) )
        elseif index < 15
            return ( x= ((index + 1) % 2) * 6, y= (index - 1 - (index - 1) % 2) ÷ 2 - 1, move= ((index % 2 == 0 ? -1 : 1), 0) )
        else
            return ( x= index - 14, y= 6, move= (Int8(0), Int8(-1)) )
        end
    end

    mirror_random_count = next_int(RND, div(mirrorCount,2), mirrorCount + 1)

    laser0 = (mirror= mirror_random_count, get_s(min(s_idx1, s_idx2))... )
    laser1 = (mirror= mirrorCount - mirror_random_count, get_s(max(s_idx1, s_idx2))... )

    initial = InitPuzzleData(empty_board, MinoData[], Point[], Point[])

    println(laser0)
    println(laser1)
    println(RND)
    println(initial)

    # ボードの二次元配列、ミノのデータ、レーザーの開始地点、終了地点を返す関数
    puzzle_data::InitPuzzleData = while_f(initial) do s

        laser_drawn_board::TwoLaserResult = draw_two_laser(RND, laser0, laser1, minoCount, mirrorCount)
        
        laser_cells::Vector{Point} = Point[]
        for j in 1:size(laser_drawn_board.board,2)
            for i in 1:size(laser_drawn_board.board,1)
                cell = laser_drawn_board.board[j, i]
                if cell == CELL_BACKS || cell == CELL_SLASH || cell == CELL_LASER
                    push!(laser_cells, Point(i - 1, j - 1))
                end
            end
        end
        # for (idx, cell) in pairs(IndexCartesian(), laser_drawn_board.board)
        #     if cell == CELL_BACKS || cell == CELL_SLASH || cell == CELL_LASER
        #         push!(laser_cells, Point(idx[2] - 1, idx[1] - 1))
        #     end
        # end
        println("\n==6==")
        println(laser_cells)
        println(RND)

        # ミノを難易度設定で指定した回数置く
        placed_minos_board::PlaceMino = PlaceMino(laser_drawn_board.board, laser_cells, MinoData[])
        for _ in 1:minoCount
            println("\n== 7 ==")
            println(placed_minos_board.laser_cells)
            println(RND)
            placed_minos_board = place_random_mino(RND, placed_minos_board)
        end

        return_data = InitPuzzleData(
            laser_drawn_board.board,
            placed_minos_board.mino_data,
            laser_drawn_board.starts,
            laser_drawn_board.ends
        )
        cont = CELL_SLASH in placed_minos_board.board ||
               CELL_BACKS in placed_minos_board.board ||
               length(placed_minos_board.mino_data) != minoCount
        
        return (cont, return_data)
    end

    laser_board = LaserState[
        simulate_laser(empty_board, Point(laser0.x, laser0.y)),
        simulate_laser(empty_board, Point(laser1.x, laser1.y))
    ]

    clean_board = map(puzzle_data.board) do cell
        if cell == CELL_WALL || cell == CELL_START || cell == CELL_END
            return cell
        else
            return CELL_EMPTY
        end
    end

    laser_data1 = LaserData(
        puzzle_data.starts[1],
        puzzle_data.ends[1],
        laser_board[1].board,
        laser_board[1].vertex
    )
    laser_data2 = LaserData(
        puzzle_data.starts[2],
        puzzle_data.ends[2],
        laser_board[2].board,
        laser_board[2].vertex
    )

    return PuzzleData(
        # PuzzleData[0]はボード状態。壁とスタートとゴール以外はまっさらにする
        clean_board,
        # PuzzleData[1]はミノの配列
        puzzle_data.mino_data,
        # PuzzleData[2]はレーザーデータ
        [laser_data1, laser_data2]
    )
end