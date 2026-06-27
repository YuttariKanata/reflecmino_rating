# const.ts

const CELL_EMPTY = Int8(0)
const CELL_WALL  = Int8(1)
const CELL_LASER = Int8(2)
const CELL_SLASH = Int8(3)  # /
const CELL_BACKS = Int8(4)  # \
const CELL_START = Int8(5)
const CELL_END   = Int8(6)
const CELL_X     = Int8(7)
const CELL_MINO = Int8(8)

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
struct MinoPattern
    protrusion::Vector{Point}   # Pointの可変長配列（TypeScriptの [] に対応）
    offset::Point               # Point型のオブジェクト
    vertex::Vector{Int}         # 整数（Int）の可変長配列
end

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

struct CellData
    x::Int
    y::Int
    type::Int8
end

struct MinoData
    cell::Vector{CellData}
    vertex::Vector{Int}
    pos::Union{Point, Nothing}
end

struct LaserData
    start_p::Point
    end_p::Point
    board::Matrix{Int8}
    vertex::Vector{Int}
end

struct PuzzleData
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

const REFLECT_MOVE_TABLE = Dict(
    (-Int8(1),  Int8(0)) => (( Int8(0),  Int8(1)), ( Int8(0), -Int8(1))), # 1: LEFT
    ( Int8(0), -Int8(1)) => (( Int8(1),  Int8(0)), (-Int8(1),  Int8(0))), # 2: UP
    ( Int8(1),  Int8(0)) => (( Int8(0), -Int8(1)), ( Int8(0),  Int8(1))), # 3: RIGHT
    ( Int8(0),  Int8(1)) => ((-Int8(1),  Int8(0)), ( Int8(1),  Int8(0)))  # 4: DOWN
)

const REFLECT_MOVE_TABLE_64 = Dict(
    (-1,  0) => (( 0,  1), ( 0, -1)), # 1: LEFT
    ( 0, -1) => (( 1,  0), (-1,  0)), # 2: UP
    ( 1,  0) => (( 0, -1), ( 0,  1)), # 3: RIGHT
    ( 0,  1) => ((-1,  0), ( 1,  0))  # 4: DOWN
)

"""
鏡に進んできた方向dir_idに対してどう反射するかを返す関数
"""
@inline function reflect_dir(dir_id::Int8, mirror_type::Int8)::Int8
    #@show dir_id, mirror_type
    if mirror_type == CELL_SLASH
        return @inbounds REFLECT_DIR_TABLE[dir_id][1]
    elseif mirror_type == CELL_BACKS
        return @inbounds REFLECT_DIR_TABLE[dir_id][2]
    end
end
@inline function reflect_dir(move::Tuple{Int8, Int8}, mirror_type::Int8)::Tuple{Int8, Int8}
    if mirror_type == CELL_SLASH
        return @inbounds REFLECT_MOVE_TABLE[move][1]
    else mirror_type == CELL_BACKS
        return @inbounds REFLECT_MOVE_TABLE[move][2]
    end
end
# @inline function reflect_dir(move::Tuple{Int, Int}, mirror_type::Int8)::Tuple{Int, Int}
#     if mirror_type == CELL_SLASH
#         return @inbounds REFLECT_MOVE_TABLE_64[move][1]
#     else mirror_type == CELL_BACKS
#         return @inbounds REFLECT_MOVE_TABLE_64[move][2]
#     end
# end


# インデックス: [dx + 2, dy + 2, mirror_type - 2]
# ※ CELL_SLASH = 3, CELL_BACKS = 4 と仮定 (mirror_type - 2 で 1 と 2 にマッピング)
# const REFLECT_LOOKUP = (
#     # --- CELL_SLASH (1) のとき ---
#     (
#         ( 0,  0),   # dx=-1, dy=-1 (不可能な移動)
#         ( 0,  1),   # dx=-1, dy=0  -> DOWN
#         ( 0,  0)    # dx=-1, dy=1  (不可能な移動)
#     ),
#     (
#         ( 1,  0),   # dx=0, dy=-1  -> RIGHT
#         ( 0,  0),   # dx=0, dy=0   (静止状態)
#         (-1,  0)   # dx=0, dy=1   -> LEFT
#     ),
#     (
#         ( 0,  0),   # dx=1, dy=-1  (不可能な移動)
#         ( 0, -1),  # dx=1, dy=0   -> UP
#         ( 0,  0)    # dx=1, dy=1   (不可能な移動)
#     )
# ), (
#     # --- CELL_BACKS (2) のとき ---
#     (
#         ( 0,  0),
#         ( 0, -1),  # dx=-1, dy=0  -> UP
#         ( 0,  0)
#     ),
#     (
#         (-1,  0),  # dx=0, dy=-1  -> LEFT
#         ( 0,  0),
#         ( 1,  0)    # dx=0, dy=1   -> RIGHT
#     ),
#     (
#         ( 0,  0),
#         ( 0,  1),   # dx=1, dy=0   -> DOWN
#         ( 0,  0)
#     )
# )

# @inline function reflect_dir(move::Tuple{Int, Int}, mirror_type::Int8)::Tuple{Int, Int}
#     dx, dy = move
#     # mirror_typeが3か4かで1か2にマッピング（お手元の定数に合わせて調整してください）
#     m_idx = Int(mirror_type) - 2 
#     # @inbounds で境界チェックを完全に消去
#     return @inbounds REFLECT_LOOKUP[m_idx][dx + 2][dy + 2]
# end

@inline function reflect_dir(move::Tuple{Int, Int}, mirror_type::Int8)::Tuple{Int, Int}
    dx, dy = move
    
    # CELL_SLASH (/) の場合: (-dx, -dy) の x と y を入れ替えて (-dy, -dx) になる
    #   LEFT  (-1,  0) -> ( 0,  1) DOWN
    #   UP    ( 0, -1) -> ( 1,  0) RIGHT
    #   RIGHT ( 1,  0) -> ( 0, -1) UP
    #   DOWN  ( 0,  1) -> (-1,  0) LEFT
    
    # CELL_BACKS (\) の場合: (dx, dy) の x と y を入れ替えて (dy, dx) になる
    #   LEFT  (-1,  0) -> ( 0, -1) UP
    #   UP    ( 0, -1) -> (-1,  0) LEFT
    #   RIGHT ( 1,  0) -> ( 0,  1) DOWN
    #   DOWN  ( 0,  1) -> ( 1,  0) RIGHT

    # mirror_type == CELL_SLASH のときだけ 1、それ以外(CELL_BACKS)のとき 0 になるフラグを計算
    # ※お手元の定数 (例: CELL_SLASH=3) に合わせて調整してください
    is_slash = (mirror_type == CELL_SLASH)
    
    # 数字の計算だけで新しい方向を導出（分岐が1つも存在しない）
    # is_slash が 1 のときは -dy と -dx になり、0 のときは dy と dx になります
    next_dx = is_slash ? -dy : dy
    next_dy = is_slash ? -dx : dx
    
    return (next_dx, next_dy)
end





mutable struct LaserState
    board::Matrix{Int8}
    x::Int
    y::Int
    move::Int8
    vertex::Vector{Int}
end

function draw_laser_on_board(board::Matrix{Int8}, start_pos::Point)
    
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
    r = abs(Int64(next(rnd)))
    return min + Int32(r % (max - min))
end
next_int(rnd::TSRandom, min::Int64, max::Int64)::Int64 = Int64(next_int(rnd,Int32(min),Int32(max)))

function next_bool(rnd::TSRandom)
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
function inner_draw_laser!(data::DrawLaser)::DrawLaser
    data.x += data.move[1]
    data.y += data.move[2]
    data.board[data.y+1, data.x+1] = CELL_LASER
    return data
end

# ミラー設置関数
function set_mirror!(RND::TSRandom, data::DrawLaser)::DrawLaser
    x = data.x + data.move[1]
    y = data.y + data.move[2]
    #board = data.board

    # どっちのミラーを置くか
    random_turn = next_bool(RND)
    
    # 鏡の消費
    if data.board[y+1, x+1] == CELL_EMPTY
        # 目の前がEMPTYなら鏡を置く
        data.mirror -= 1
    # else
        # 目の前がEMPTYでない(仕様的には"/"もしくは"\"となるはず)
        # data.mirror
    end

    if data.board[y+1, x+1] == CELL_EMPTY
        if random_turn
            # random_turnがtrue (右に曲がる)
            #replace_2d_array!(board, x+1, y+1, data.move[1] != 0 ? CELL_BACKS : CELL_SLASH)
            data.board[y+1, x+1] = data.move[1] != 0 ? CELL_BACKS : CELL_SLASH
            # data.move[1] != 0 つまり横の動きなら"\" 縦の動きなら"/" で右に曲がる
        else
            # random_turnがfalse (左に曲がる)
            #replace_2d_array!(board, x+1, y+1, data.move[1] == 0 ? CELL_BACKS : CELL_SLASH)
            data.board[y+1, x+1] = data.move[1] == 0 ? CELL_BACKS : CELL_SLASH
            # data.move[1] == 0 つまり縦の動きなら"\" 横の動きなら"/" で左に曲がる
        end
    # else # は何もしない
    end
    
    return data # 座標を進めはしない。
end

# 反射関数
function reflection!(data::DrawLaser)::DrawLaser
    data.x += data.move[1]
    data.y += data.move[2]

    if data.board[data.y+1, data.x+1] == CELL_SLASH || data.board[data.y+1, data.x+1] == CELL_BACKS
        # 鏡なら曲がる
        data.move = reflect_dir(data.move, data.board[data.y+1, data.x+1])
    #else
        # そうでないならそのままの向きで
    end
    return data # 座標を進め(鏡の上にいるかも)、向きを変える
end

function move_laser!(RND::TSRandom, data::Vector{DrawLaser}, work_board::Matrix{Int8}, ranges::Vector{Int})::Vector{DrawLaser}
    copyto!(work_board, data[end].board)
    current::DrawLaser = DrawLaser(work_board, data[end].x, data[end].y, data[end].move, data[end].mirror)
    #board::Matrix{Int8}     = current.board
    # ここでのx,yは、壁も含めたボード全体での0-indexed座標。
    x::Int64                = current.x
    y::Int64                = current.y
    move::Tuple{Int8, Int8} = current.move      # Tuple{Int8, Int8}の形式
    mirror::Int64           = current.mirror

    look_x = x
    look_y = y
    
    # 移動可能なマスまでの距離の配列
    #ranges = Vector{Int}(undef,7)
    ranges_idx = 1
    
    for i in 0:6
        look_x += move[1]
        look_y += move[2]

        # 本家も"#"かどうかで判定していない
        if look_x <= 0 || 6 <= look_x   # 0-indexedなので本来のjuliaなら1~7だがこのxには0~6が入る
            break
        elseif look_y <= 0 || 6 <= look_y
            break
        end

        look_cell = current.board[look_y+1, look_x+1]
        if look_cell == CELL_LASER
            continue
        elseif look_cell == CELL_SLASH || look_cell == CELL_BACKS
            # 鏡にあたったときは終了の運命しかない
            if mirror > 0
                # 予算がある
                next_move = reflect_dir(move, look_cell)
                next_cell = current.board[look_y + next_move[2] + 1, look_x + next_move[1] + 1]
                if next_cell == CELL_WALL
                    # 次の座標が"#"なら追加せず終了
                    break
                else
                    # 次が大丈夫なら追加して終了
                    #push!(range, i)
                    ranges[ranges_idx] = i
                    ranges_idx += 1
                    break
                end
            else
                # 予算が無ければ追加して終了
                #push!(range, i)
                ranges[ranges_idx] = i
                ranges_idx += 1
                break
            end
        else
            #push!(range, i)
            ranges[ranges_idx] = i
            ranges_idx += 1
        end
    end
    ranges_idx -= 1  # ranges_idx == length(range)にする

    # その中からランダムに決める   ミラーを置く必要がないなら最長を選ぶ
    random_range = if mirror > 0
        if ranges_idx == 0
            next(RND)
            0
        else
            ranges[next_int(RND, 0, ranges_idx) + 1]
        end
    else
        if ranges_idx == 0
            0
        else
            ranges[ranges_idx]
        end
    end

    # 目的の場所の 一つ手前 まで行く。
    # rangeで出るのは目の前を0とした0-indexedの表示なのでこれでいい
    #lined_data = deepcopy(current)
    lined_data = current
    if random_range > 0
        for _ in 1:random_range
            inner_draw_laser!(lined_data)
        end
    # else # random_range = 0 なら何もしない
    end

    # 返すデータを作成
    if mirror > 0
        # 一歩手前まで行った盤面から鏡を置いて反射！
        reflection!(set_mirror!(RND, lined_data))
        if ranges_idx != 0
            # 候補がまだあるならくっつけておく
            saved_data = DrawLaser(copy(lined_data.board), lined_data.x, lined_data.y, lined_data.move, lined_data.mirror)
            return push!(data, saved_data)
        else
            # 行き止まりならUndo  初回で行き止まりならループが終了するデータを返す
            if length(data) > 1
                pop!(data)
                return data
            else
                empty!(data)
                push!(data, DrawLaser(empty_board, 0, 0, DIR_VECTORS[DIR_DOWN], 0))
                return data
            end
        end
    else
        # 予算がない場合

        # 一歩先に行った後を作る
        reflection!(lined_data)

        if lined_data.board[y+1, x+1] == CELL_EMPTY
            # まさかもし最初の座標がCELL_EMPTYなんてことないですよね...?
            #println("hey!!!")
            # 一応LASERを引いておきます
            replace_2d_array!(lined_data.board, lined_data.x - lined_data.move[1] + 1, lined_data.y - lined_data.move[2] + 1, CELL_LASER)
        #else
            #copy(lined_data.board)
        end
        
        #result = lined_data
        saved_data = DrawLaser(copy(lined_data.board), lined_data.x, lined_data.y, lined_data.move, lined_data.mirror)
        return push!(data, saved_data)
    end
end

function draw_random_laser(RND::TSRandom, board::Matrix{Int8}, laser::@NamedTuple{mirror::Int64, x::Int64, y::Int64, move::Tuple{Int8, Int8}})::DrawLaser
    # 最初の状態を作成して履歴配列（Vector）に初期化
    initial = DrawLaser(board, laser.x, laser.y, laser.move, laser.mirror)
    data = DrawLaser[initial]

    work_board = Matrix{Int8}(undef, size(board))
    work_ranges = Vector{Int}(undef,7)

    while_count = 100
    while while_count > 0
        # move_laser を実行して履歴配列を更新
        move_laser!(RND, data, work_board, work_ranges)
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

function draw_one_laser(RND::TSRandom, laser0::@NamedTuple{mirror::Int64, x::Int64, y::Int64, move::Tuple{Int8, Int8}}, laser1::@NamedTuple{mirror::Int64, x::Int64, y::Int64, move::Tuple{Int8, Int8}})::DrawLaser

    data::DrawLaser = draw_random_laser(RND, empty_board, laser0)

    if data.x != laser1.x || data.y != laser1.y
        return data
    else
        return draw_one_laser(RND, laser0, laser1)
    end
end

struct TwoLaserResult
    board::Matrix{Int8}
    starts::Vector{Point}   # 両方とも0-indexed
    ends::Vector{Point}
end

global print_counter = 0

function draw_two_laser(RND::TSRandom, laser0, laser1, minoCount::Int, mirrorCount::Int)::TwoLaserResult
    draw_1_data::DrawLaser = draw_one_laser(RND, laser0, laser1)
    draw_2_data::DrawLaser = draw_random_laser(RND, draw_1_data.board, laser1)
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

struct PlaceMino
    board::Matrix{Int8}
    laser_cells::Vector{Point} # laser_cellsはレーザーの通ったセルの配列
    mino_data::Vector{MinoData}
end

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

    # ID:idxのトリオミノが置けるならidxをplaceable_minoに追加
    placeable_mino = Int[]
    for (idx, (pos1, pos2)) in enumerate(TRIMINO_PATTERNS)
        if placeable_cell[pos1...] == placeable_cell[pos2...] == CELL_LASER
            push!(placeable_mino, idx - 1)
        end
    end


    # 置けるミノがあれば置き、できなければそのまま返す
    if length(placeable_mino) > 0
        random_mino_id = placeable_mino[next_int(RND, 0, length(placeable_mino)) + 1]
        place_mino = MINO_PATTERN[random_mino_id + 1]
        place_cell = Point[
            Point( x + place_mino.protrusion[1].x, y + place_mino.protrusion[1].y),
            Point( x + place_mino.protrusion[2].x, y + place_mino.protrusion[2].y)
        ]

        # ミノの１番目のセルから３番目のセルをボードに配置している
        # replace_2d_arrayは二次元配列を置き換える独自関数

        place_1 = copy(board)
        replace_2d_array!(place_1, x+1, y+1, CELL_N(random_mino_id))
        replace_2d_array!(place_1, place_cell[1].x + 1, place_cell[1].y + 1, CELL_N(random_mino_id))
        replace_2d_array!(place_1, place_cell[2].x + 1, place_cell[2].y + 1, CELL_N(random_mino_id))
        filtered_laser_cells = Vector{Point}()
        filtered_laser_cells = filter(data.laser_cells) do p
            p != random_pos && p != place_cell[1] && p != place_cell[2]
        end

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

struct InitPuzzleData
    board::Matrix{Int8}
    mino_data::Vector{MinoData}
    starts::Vector{Point}
    ends::Vector{Point}
end

# 一旦generate関数のガワだけを書いておくが、中身の関数の内、でかいやつはgenerate関数の外に書いておきたい。
function generate(mode::Int, seed::Int)::PuzzleData
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

        # ミノを難易度設定で指定した回数置く
        placed_minos_board::PlaceMino = PlaceMino(laser_drawn_board.board, laser_cells, MinoData[])
        for _ in 1:minoCount
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
        draw_laser_on_board(empty_board, Point(laser0.x, laser0.y)),
        draw_laser_on_board(empty_board, Point(laser1.x, laser1.y))
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

function printAllPiecesFromPuzzle(puzzle::PuzzleData)
    for (i,mi) in enumerate(puzzle.mino_data)
        m = fill(" ",3,3)
        minx = 0
        miny = 0
        for cell in mi.cell
            minx = min(minx,cell.x)
            miny = min(miny,cell.y)
        end
        for cell in mi.cell
            m[cell.y - miny + 1, cell.x - minx + 1] = CELL_STRING[cell.type]
        end
        println("--$i--")
        for i in 1:3
            for j in 1:3
                print(m[i,j]," ")
            end
            println()
        end
    end

end
generate(seed::Int)::PuzzleData = generate(DIFFICULTY, seed)
generate(seed::Int32)::PuzzleData = generate(DIFFICULTY, Int64(seed))

function minos_start_end(puzzle::PuzzleData)::Tuple{Vector{Tuple{CellData, CellData, CellData}}, Tuple{Point, Point}, Tuple{Point, Point}}
    cs = Vector{Tuple{CellData, CellData, CellData}}()
    for mdata in puzzle.mino_data
        push!(cs, (mdata.cell[1], mdata.cell[2], mdata.cell[3]))
    end
    return (cs, (puzzle.laser[1].start_p, puzzle.laser[2].start_p), (puzzle.laser[1].end_p, puzzle.laser[2].end_p))
end
#minos_start_end(generate(3,3))

# printAllPiecesFromPuzzle(generate(3, 20260621))
# println("=====================================")
# printAllPiecesFromPuzzle(generate(3, 20260622))

#=
```julia
struct CellData
    x::Int
    y::Int
    type::Int8
end
```
このような構造体があり、
```julia
(Tuple{CellData, CellData, CellData}[(CellData(0, 0, 2), CellData(0, -1, 4), CellData(0, 1, 4)), (CellData(0, -1, 4), CellData(0, 0, 3), CellData(0, 1, 2)), (CellData(0, 0, 2), CellData(-1, 0, 4), CellData(0, 1, 3)), (CellData(0, 1, 2), CellData(-1, 0, 3), CellData(0, 0, 2)), (CellData(0, 0, 2), CellData(0, -1, 4), CellData(-1, 0, 4)), (CellData(0, 0, 4), CellData(0, -1, 4), CellData(0, 1, 2)), (CellData(0, 0, 2), CellData(-1, 0, 4), CellData(1, 0, 3))], (Point(0, 4), Point(6, 5)), (Point(0, 3), Point(2, 0)))
```
というデータが送られてきます。これはある日の問題であり、ピースの数から難易度はoniplusと分かります。このデータの見方は、
0 => 空白マス
1 => 壁
2 => 空白ピースマス
3 => slash '/'
4 => back slash '\'
という対応が前提としてあり、x,y,typeの形で返ってきます。
例えば、CellData(0, 0, 4), CellData(-1, 0, 2), CellData(0, 1, 3)なら
(0,0)の位置に4(つまり'\' 右肩下がりに置いた両面鏡)
(-1,0)の位置に2(つまり空白マス)
(0,1)の位置に3(つまり'/' 右肩上がりに置いた両面鏡)
ということを表し、このピースは逆さL字型のピースであることが分かります。(回転できないので向きも重要です)
→がx軸の正の方向で、↓がy軸の正の方向です。右上のマスが(1,1)です。右上のマスの右上に原点(0,0)があると思ってください。

最後の(Point, Point), (Point, Point)の意味は、start pointとend pointで、
(0,4)と(6,5)からレーザーが出て、(0,3),(2,0)にレーザーを入れなければいけません。
# # e # # # #
#           #
#           #
e           #
s           #
#           s
# # # # # # #
こんな感じです。


とりあえずまずは、レーザーを入れることや鏡の種類などを無視して、ミノの入れ方について何通り存在するかを総当たりするプログラムを書いてください
=#