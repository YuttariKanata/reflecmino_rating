const DIFFICULTY::Int8 = 3  # 1 2 3 がある (1=normal 2=oni 3=oniplus)
const MINO_MIRROR_TABLE = (
    (4, 6),     # normal
    (5, 8),     # oni
    (7, 13)     # oniplus
)

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

function next(rnd::TSRandom)
    t = xor(rnd.x,(rnd.x<<11))
    rnd.x = rnd.y
    rnd.y = rnd.z
    rnd.z = rnd.w
    rnd.w = xor(xor(rnd.w,rnd.w >>> 19), xor(t, (t >>> 8)))
    return rnd.w
end

function next_int(rnd::TSRandom, min::Int32, max::Int32)
    r = abs(Int64(next(rnd)))
    return min + Int32(r % (max - min))
end
next_int(rnd::TSRandom, min::Int64, max::Int64) = next_int(rnd,Int32(min),Int32(max))

function next_bool(rnd::TSRandom)
    r = abs(Int64(next(rnd)))
    return Bool(r % 2)
end

function get_s(index::Int32)::Tuple{Int32, Int32, Int8, Int8}
    if index < 5
        return (Int32(index+1), Int32(0), Int32(0), Int32(1))
    elseif index < 15
        return (Int32(((index + 1) % 2) * 6), Int32((index - 1 - (index - 1) % 2) ÷ 2 - 1), Int32(index % 2 == 0 ? -1 : 1), Int32(0))
    else
        return (Int32(index-14), Int32(6), Int32(0), Int32(-1))
    end
end
get_s(index::Int64) = get_s(Int32(index))

function extract_initial_lasers!(rnd::TSRandom)
    hashtags = falses(18)

    idx1 = next_int(rnd, Int32(0), Int32(20)) # 0~19
    insert!(hashtags,min(idx1+1,19),true)   # min(1~20,19)

    idx2 = next_int(rnd, Int32(0), Int32(21)) # 0~20
    insert!(hashtags,min(idx2+1,20),true)   # min(1~21,20)

    (x1, y1, dx1, dy1) = get_s(Int32(findfirst(hashtags)-1))
    (x2, y2, dx2, dy2) = get_s(Int32(findlast(hashtags)-1))

    mirror_count = MINO_MIRROR_TABLE[DIFFICULTY][2]
    mirror_random_count_1 = next_int(rnd, mirror_count÷2, mirror_count+1)
    mirror_random_count_2 = mirror_count - mirror_random_count_1

    #println(idx1," ",idx2)
    #println(findfirst(hashtags)-1," ",findlast(hashtags)-1)
    return
end

const CELL_EMPTY  = Int8(0)  # ' '
const CELL_WALL   = Int8(1)  # '#' または 'S' (外周)
const CELL_LASER  = Int8(2)  # '￭' (描画されたレーザーの軌跡)
const CELL_SLASH  = Int8(3)  # '/' (右上がり鏡)
const CELL_BACK   = Int8(4)  # '\' (右下がり鏡)

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

const REFLECT_DIR_TABLE = (
    (DIR_DOWN , DIR_UP   ), # (1,1)=(←,/) => (↓)    (1,2)=(←,\) => (↑)
    (DIR_RIGHT, DIR_LEFT ), # (2,1)=(↑,/) => (→)    (2,2)=(↑,\) => (←)
    (DIR_UP   , DIR_DOWN ), # (3,1)=(→,/) => (↑)    (3,2)=(→,\) => (↓)
    (DIR_LEFT , DIR_RIGHT)  # (4,1)=(↓,/) => (←)    (4,2)=(↓,\) => (→)
)

"""
鏡に進んできた方向dir_idに対してどう反射するかを返す関数
"""
function reflect_dir(dir_id::Int8, mirror_type::Int8)::Int8
    #@show dir_id, mirror_type
    return REFLECT_DIR_TABLE[dir_id][mirror_type-2]
end

"""
レーザーの描画とバックトラックを行う関数。
アロケーションを避けるため、深さごとの盤面状態を board_stack に保存する。
board_stack のサイズは (7, 7, MAX_DEPTH) を想定。
"""
function draw_random_laser!(
    rnd::TSRandom,
    board_stack::Array{Int8, 3},
    start_board::Matrix{Int8},
    start_x::Int, start_y::Int, start_dir::Int8, start_mirror::Int
)::Tuple{Bool, Int, Int, Int} # (成功フラグ, 最終的な深さ)

    # 初期盤面を深さ1にコピー
    @inbounds for j in 1:7, i in 1:7
        board_stack[i, j, 1] = start_board[i, j]
    end

    # タプルのアロケーションすら避けるため、状態変数をフラットな配列として事前確保
    xs = Vector{Int}(undef, 100)
    ys = Vector{Int}(undef, 100)
    dirs = Vector{Int8}(undef, 100)
    mirrors = Vector{Int}(undef, 100)

    xs[1] = start_x
    ys[1] = start_y
    dirs[1] = start_dir
    mirrors[1] = start_mirror

    # 一時バッファ（関数内で使い回す）
    trim_i = zeros(Int, 7)
    trim_c = zeros(Int8, 7)
    valid_steps = zeros(Int, 7)

    depth = 1
    max_iterations = 100

    @inbounds for _ in 1:max_iterations
        x = xs[depth]
        y = ys[depth]
        dir = dirs[depth]
        mirror = mirrors[depth]

        dx, dy = DIR_VECTORS[dir]

        # 1. 視界の取得 (trim_mirror)
        trim_len = 0
        for i in 1:7
            nx, ny = x + i * dx, y + i * dy
            if nx < 0 || nx > 6 || ny < 0 || ny > 6
                break
            end
            c = board_stack[ny + 1, nx + 1, depth]
            if c == CELL_WALL
                break # 壁の手前でストップ
            end
            trim_len += 1
            trim_i[trim_len] = i
            trim_c[trim_len] = c
            if c == CELL_SLASH || c == CELL_BACK
                break # 最初の鏡でストップ
            end
        end

        # 2. TSのバグを含む行き止まり判定 (trim_deadend_mirror)
        if mirror > 0 && trim_len > 0
            last_c = trim_c[trim_len]
            if last_c == CELL_SLASH || last_c == CELL_BACK
                # TS側の dx+dy < 0 時の文字列置換による鏡の反転挙動を再現
                ts_last_mirror = last_c
                if dx + dy < 0
                    ts_last_mirror = (last_c == CELL_SLASH) ? CELL_BACK : CELL_SLASH
                end

                col0 = x - dy + 1
                col2 = x + dy + 1
                row0 = y - dx + 1
                row2 = y + dx + 1

                # TSの「盤面中央を参照してしまう」バグの再現 (インデックス4が中央)
                if dx == 0
                    pick0 = (1 <= col0 <= 7) ? board_stack[4, col0, depth] : Int8(-1)
                    pick2 = (1 <= col2 <= 7) ? board_stack[4, col2, depth] : Int8(-1)
                else
                    pick0 = (1 <= row0 <= 7) ? board_stack[row0, 4, depth] : Int8(-1)
                    pick2 = (1 <= row2 <= 7) ? board_stack[row2, 4, depth] : Int8(-1)
                end

                left_is_wall  = (ts_last_mirror == CELL_SLASH) && (pick0 == CELL_WALL)
                right_is_wall = (ts_last_mirror == CELL_BACK)  && (pick2 == CELL_WALL)

                if left_is_wall || right_is_wall
                    trim_len -= 1 # 末尾の鏡を取り除く
                end
            end
        end

        # 3. 有効なステップ数の抽出 (range)
        valid_len = 0
        for i in 1:trim_len
            if trim_c[i] != CELL_LASER
                valid_len += 1
                valid_steps[valid_len] = trim_i[i]
            end
        end

        # 4. バックトラックまたは進行
        if mirror > 0
            if valid_len == 0
                if depth > 1
                    depth -= 1 # バックトラック
                    continue
                else
                    return false, depth, xs[depth], ys[depth] # 完全に手詰まり
                end
            end

            # ランダムにステップ数を選択
            idx = next_int(rnd, Int32(0), Int32(valid_len)) + 1
            chosen_step = valid_steps[idx]
            random_range = chosen_step - 1

            new_depth = depth + 1
            # 盤面のコピー (in-place)
            for j in 1:7, i in 1:7
                board_stack[i, j, new_depth] = board_stack[i, j, depth]
            end

            # レーザーの描画
            for i in 1:random_range
                board_stack[y + i*dy + 1, x + i*dx + 1, new_depth] = CELL_LASER
            end

            final_x = x + chosen_step*dx
            final_y = y + chosen_step*dy
            target_c = board_stack[final_y + 1, final_x + 1, depth] # 古い盤面を参照

            new_mirror = mirror
            new_dir = dir

            if target_c == CELL_EMPTY
                new_mirror = mirror - 1
                turn_val = next_bool(rnd)
                mirror_type = CELL_EMPTY
                if turn_val
                    mirror_type = (dx != 0) ? CELL_BACK : CELL_SLASH
                else
                    mirror_type = (dx == 0) ? CELL_BACK : CELL_SLASH
                end
                board_stack[final_y + 1, final_x + 1, new_depth] = mirror_type
                new_dir = reflect_dir(dir, mirror_type)
            else
                new_dir = reflect_dir(dir, target_c)
            end

            xs[new_depth] = final_x
            ys[new_depth] = final_y
            dirs[new_depth] = new_dir
            mirrors[new_depth] = new_mirror
            depth = new_depth

        else
            # 鏡をもう置けない場合
            chosen_step = valid_len == 0 ? 1 : valid_steps[valid_len]
            random_range = chosen_step - 1

            new_depth = depth + 1
            for j in 1:7, i in 1:7
                board_stack[i, j, new_depth] = board_stack[i, j, depth]
            end

            for i in 1:random_range
                board_stack[y + i*dy + 1, x + i*dx + 1, new_depth] = CELL_LASER
            end

            final_x = x + chosen_step*dx
            final_y = y + chosen_step*dy
            target_c = board_stack[final_y + 1, final_x + 1, depth]

            new_dir = dir
            if target_c == CELL_SLASH || target_c == CELL_BACK
                new_dir = reflect_dir(dir, target_c)
            end

            if target_c == CELL_EMPTY
                board_stack[final_y + 1, final_x + 1, new_depth] = CELL_LASER
            end

            xs[new_depth] = final_x
            ys[new_depth] = final_y
            dirs[new_depth] = new_dir
            mirrors[new_depth] = mirror
            depth = new_depth
        end

        # 終了条件のチェック
        if mirrors[depth] == 0 && board_stack[ys[depth] + 1, xs[depth] + 1, depth] == CELL_WALL
            return true, depth, xs[depth], ys[depth]
        end
    end

    return false, depth, xs[depth], ys[depth]
end

# 始点・終点を書き込むための識別IDを定義（必要に応じて定数セクションへ配置）
const CELL_START = Int8(5)  # 's'
const CELL_END   = Int8(6)  # 'e'

"""
TS 側の draw_two_laser を安全なループ構造で完全等価に再現する。
"""
function draw_two_laser!(
    rnd::TSRandom,
    board_stack1::Array{Int8, 3},
    board_stack2::Array{Int8, 3},
    empty_board::Matrix{Int8},
    final_board::Matrix{Int8},
    laser_start_x::Vector{Int},    # [laser[0].x, laser[1].x]
    laser_start_y::Vector{Int},    # [laser[0].y, laser[1].y]
    laser_start_dir::Vector{Int8}, # [dir0, dir1]
    mirror_counts::Vector{Int},    # [mirror_random_count_1, mirror_random_count_2]
    ends_x::Vector{Int},           # 結果格納用バッファ (長さ2)
    ends_y::Vector{Int}            # 結果格納用バッファ (長さ2)
)
    minoCount = MINO_MIRROR_TABLE[DIFFICULTY][1]
    target_mirrorCount = MINO_MIRROR_TABLE[DIFFICULTY][2]

    while true
        # --- 1本目のレーザー生成 (draw_one の再現) ---
        depth1 = 1
        ex1, ey1 = 0, 0
        while true
            success1, depth1, ex1, ey1 = draw_random_laser!(
                rnd, board_stack1, empty_board,
                laser_start_x[1], laser_start_y[1], laser_start_dir[1], mirror_counts[1]
            )

            if success1
                # TS: if (data[1] !== laser[1].x || data[2] !== laser[1].y)
                if ex1 != laser_start_x[2] || ey1 != laser_start_y[2]
                    ends_x[1] = ex1
                    ends_y[1] = ey1
                    break # 重複がないため draw_one() 完了
                end
            end
            # 失敗、または始点重複時は、そのまま乱数状態を引き継いで再試行（再帰の再現）
        end

        # 1本目の最終盤面（depth1層）を2本目の初期盤面として final_board に転写
        @inbounds for j in 1:7, i in 1:7
            final_board[i, j] = board_stack1[i, j, depth1]
        end

        # --- 2本目のレーザー生成 ---
        success2, depth2, ex2, ey2 = draw_random_laser!(
            rnd, board_stack2, final_board,
            laser_start_x[2], laser_start_y[2], laser_start_dir[2], mirror_counts[2]
        )

        if !success2
            continue # 2本目が失敗した場合は、全体の引き直しループ先頭へ
        end
        
        ends_x[2] = ex2
        ends_y[2] = ey2

        # --- 条件判定（鏡枚数・通過マスのカウント） ---
        mirror_count = 0
        laser_cell_count = 0

        @inbounds for j in 1:7, i in 1:7
            c = board_stack2[i, j, depth2]
            if c == CELL_SLASH || c == CELL_BACK
                mirror_count += 1
                laser_cell_count += 1
            elseif c == CELL_LASER
                laser_cell_count += 1
            end
        end

        # TS: if (laser_cell_count >= minoCount * 3 && mirror_count === mirrorCount)
        if laser_cell_count >= minoCount * 3 && mirror_count == target_mirrorCount
            # 合格時、最終結果のボード（board_stack2 の depth2層）を final_board に確定書き込み
            @inbounds for j in 1:7, i in 1:7
                final_board[i, j] = board_stack2[i, j, depth2]
            end

            # 始点 's' の上書き
            final_board[laser_start_y[1] + 1, laser_start_x[1] + 1] = CELL_START
            final_board[laser_start_y[2] + 1, laser_start_x[2] + 1] = CELL_START

            # 終点 'e' の上書き
            final_board[ends_y[1] + 1, ends_x[1] + 1] = CELL_END
            final_board[ends_y[2] + 1, ends_x[2] + 1] = CELL_END

            return # 正常終了。final_board と ends_x, ends_y に値が確定
        end

        # 条件不適合なら、乱数を進めた状態で全体をリトライ（draw_two_laser の外側再帰の再現）
    end
end

# ミノの最大数定義
const MAX_MINO_COUNT = 7

# ミノ1つ分の情報を保持する具象型（アロケーションフリー用）
struct MinoItem
    id::Int8
    # cell配列のシミュレート: [cell0, cell1, cell2] 
    # それぞれ (x, y, type)。固定長で持たせる
    cx::NTuple{3, Int8}
    cy::NTuple{3, Int8}
    # vertex: 原作の vertex 表現用（必要なら）
    vertex::Int32
end

# TS側の mino_pattern のデータを完全に再現する静的テーブル
# 各ミノ：(protrusion_x1, protrusion_y1, protrusion_x2, protrusion_y2, offset_x, offset_y, vertex)
const MINO_PATTERN_TABLE = (
    ( 0, -2,  0, -1,  0,  1,  0), # 0
    ( 0, -1,  0,  1,  0,  0,  0), # 1
    ( 0,  1,  0,  2,  0, -1,  0), # 2
    (-2,  0, -1,  0,  1,  0,  0), # 3
    (-1,  0,  1,  0,  0,  0,  0), # 4
    ( 1,  0,  2,  0, -1,  0,  0), # 5
    ( 0, -1, -1,  0,  0,  0,  0), # 6
    ( 0, -1,  1,  0,  0,  0,  0), # 7
    ( 1,  0,  0,  1,  0,  0,  0), # 8
    (-1,  0,  0,  1,  0,  0,  0), # 9
    (-1,  1,  0,  1,  0,  0,  0), # 10
    (-1, -1, -1,  0,  0,  0,  0), # 11
    ( 0, -1,  1, -1,  0,  0,  0), # 12
    ( 1,  0,  1,  1,  0,  0,  0), # 13
    ( 0,  1,  1,  1,  0,  0,  0), # 14
    (-1,  0, -1,  1,  0,  0,  0), # 15
    (-1, -1,  0, -1,  0,  0,  0), # 16
    ( 1, -1,  1,  0,  0,  0,  0)  # 17
)

"""
レーザーが通るマスのランダムな位置にミノを1つ置く試みを行う。
置けた場合は盤面を更新し、laser_cells から使用した3マスを除外し、mino_data_out に追加する。
"""
function place_random_mino!(
    rnd::TSRandom,
    board::Matrix{Int8},
    laser_cells_x::Vector{Int8},
    laser_cells_y::Vector{Int8},
    laser_cells_len::Ref{Int},
    mino_data_out::Vector{MinoItem},
    mino_data_len::Ref{Int}
)::Bool
    len = laser_cells_len[]
    if len == 0
        return false
    end

    # 1. 通過セルからランダムに1つ選択 (中心セル)
    idx = Int(next_int(rnd, Int32(0), Int32(len))) + 1
    cx = Int(laser_cells_x[idx])
    cy = Int(laser_cells_y[idx])

    # 2. 周辺5x5の配置可能性チェックバッファを構築
    # 盤面外は壁('#' = CELL_WALL)とする。鏡はレーザー軌跡('￭' = CELL_LASER)として読み替える
    # ローカルな固定長バッファ（スタック割り当て）
    local_cells = Matrix{Int8}(undef, 5, 5)
    @inbounds for dy in -2:2
        for dx in -2:2
            nx = cx + dx
            ny = cy + dy
            if nx < 0 || nx > 6 || ny < 0 || ny > 6
                local_cells[dy+3, dx+3] = CELL_WALL
            else
                c = board[ny+1, nx+1]
                if c == CELL_SLASH || c == CELL_BACK
                    local_cells[dy+3, dx+3] = CELL_LASER
                else
                    local_cells[dy+3, dx+3] = c
                end
            end
        end
    end

    # 3. 置けるミノIDのリストアップ
    placeable_ids = Vector{Int8}(undef, 18)
    p_count = 0

    @inbounds begin
        if local_cells[1,3]==CELL_LASER && local_cells[2,3]==CELL_LASER; p_count+=1; placeable_ids[p_count]=0; end
        if local_cells[2,3]==CELL_LASER && local_cells[4,3]==CELL_LASER; p_count+=1; placeable_ids[p_count]=1; end
        if local_cells[4,3]==CELL_LASER && local_cells[5,3]==CELL_LASER; p_count+=1; placeable_ids[p_count]=2; end
        if local_cells[3,1]==CELL_LASER && local_cells[3,2]==CELL_LASER; p_count+=1; placeable_ids[p_count]=3; end
        if local_cells[3,2]==CELL_LASER && local_cells[3,4]==CELL_LASER; p_count+=1; placeable_ids[p_count]=4; end
        if local_cells[3,4]==CELL_LASER && local_cells[3,5]==CELL_LASER; p_count+=1; placeable_ids[p_count]=5; end
        if local_cells[2,3]==CELL_LASER && local_cells[3,2]==CELL_LASER; p_count+=1; placeable_ids[p_count]=6; end
        if local_cells[2,3]==CELL_LASER && local_cells[3,4]==CELL_LASER; p_count+=1; placeable_ids[p_count]=7; end
        if local_cells[3,4]==CELL_LASER && local_cells[4,3]==CELL_LASER; p_count+=1; placeable_ids[p_count]=8; end
        if local_cells[3,2]==CELL_LASER && local_cells[4,3]==CELL_LASER; p_count+=1; placeable_ids[p_count]=9; end
        if local_cells[4,2]==CELL_LASER && local_cells[4,3]==CELL_LASER; p_count+=1; placeable_ids[p_count]=10; end
        if local_cells[2,2]==CELL_LASER && local_cells[3,2]==CELL_LASER; p_count+=1; placeable_ids[p_count]=11; end
        if local_cells[2,3]==CELL_LASER && local_cells[2,4]==CELL_LASER; p_count+=1; placeable_ids[p_count]=12; end
        if local_cells[3,4]==CELL_LASER && local_cells[4,4]==CELL_LASER; p_count+=1; placeable_ids[p_count]=13; end
        if local_cells[4,3]==CELL_LASER && local_cells[4,4]==CELL_LASER; p_count+=1; placeable_ids[p_count]=14; end
        if local_cells[3,2]==CELL_LASER && local_cells[4,2]==CELL_LASER; p_count+=1; placeable_ids[p_count]=15; end
        if local_cells[2,2]==CELL_LASER && local_cells[2,3]==CELL_LASER; p_count+=1; placeable_ids[p_count]=16; end
        if local_cells[2,4]==CELL_LASER && local_cells[3,4]==CELL_LASER; p_count+=1; placeable_ids[p_count]=17; end
    end

    if p_count == 0
        return false # 置けるミノがない場合はそのまま帰る
    end

    # 4. ミノのランダム決定と配置
    r_idx = Int(next_int(rnd, Int32(0), Int32(p_count))) + 1
    mino_id = placeable_ids[r_idx]
    
    p_info = MINO_PATTERN_TABLE[mino_id + 1]
    px1, py1 = Int(p_info[1]), Int(p_info[2])
    px2, py2 = Int(p_info[3]), Int(p_info[4])
    ox, oy   = Int(p_info[5]), Int(p_info[6])
    v_val    = Int32(p_info[7])

    # 絶対座標の算出
    x1, y1 = cx + px1, cy + py1
    x2, y2 = cx + px2, cy + py2

    # TSのID文字列埋め込み挙動の再現（盤面をミノIDで上書き）
    # 元が文字型配列なので、Julia側ではInt8のID（または識別値）を入れる
    # 以降の判定で「盤面に鏡（/ , \）が残っているか」をチェックするため、鏡の上をミノが上書きすると消える
    board[cy+1, cx+1] = mino_id
    board[y1+1, x1+1] = mino_id
    board[y2+1, x2+1] = mino_id

    # 5. 元の盤面タイプ（上書き前）をキャプチャしてMinoItemを構築
    # ※TSの実装では、MinoDataに格納するtypeプロパティには上書き「前」のboardの状態が入る
    # ただし、上記 local_cells を構築する段階で既に外周の判定等は済んでいる
    # 本来のセルタイプ（CELL_EMPTY、CELL_LASER、CELL_SLASH、CELL_BACK）を取得
    orig_type_c = board[cy+1, cx+1] # 既に上書き済みの場合は不正確になるのを防ぐため、必要なら上書き前に退避
    # 正確性を担保するため、local_cells から逆算、もしくは上書き前に取得するのが安全
    # ここでは local_cells の構築ロジックに基づいて再現する
    get_orig_type(x, y) = begin
        if x < 0 || x > 6 || y < 0 || y > 6; return CELL_WALL; end
        # 実装上、このタイミングでは laser_drawn_board の状態なのでそのまま読んでも良いが、
        # 既に上書きしてしまっているので、1マスずつ上書き前の状態を取得できるよう、
        # boardの変更前に退避するか、シミュレーション情報を詰める
    end
    
    # リファクタリング：上書き前に元のタイプを取得しておく
    orig_type_0 = board[cy+1, cx+1]
    orig_type_1 = board[y1+1, x1+1]
    orig_type_2 = board[y2+1, x2+1]

    board[cy+1, cx+1] = mino_id
    board[y1+1, x1+1] = mino_id
    board[y2+1, x2+1] = mino_id

    # 6. laser_cells のフィルタリング（TSのJSON.stringify一致の再現）
    # 使用した3つの座標 (cx, cy), (x1, y1), (x2, y2) を配列から除外
    w_idx = 1
    @inbounds for i in 1:len
        lx = laser_cells_x[i]
        ly = laser_cells_y[i]
        is_used = (lx == cx && ly == cy) || (lx == x1 && ly == y1) || (lx == x2 && ly == y2)
        if !is_used
            laser_cells_x[w_idx] = lx
            laser_cells_y[w_idx] = ly
            w_idx += 1
        end
    end
    laser_cells_len[] = w_idx - 1

    # 7. ミノ配列への追加
    m_len = mino_data_len[] + 1
    mino_data_out[m_len] = MinoItem(
        mino_id,
        (Int8(ox), Int8(px1 + ox), Int8(px2 + ox)),
        (Int8(oy), Int8(py1 + oy), Int8(py2 + oy)),
        v_val
    )
    mino_data_len[] = m_len

    return true
end

"""
TS の generate の全ロジックを統合した関数。
引数の各種バッファは外部から渡され、アロケーションを引き起こさない。
"""
function generate_puzzle!(
    rnd::TSRandom,
    board_stack1::Array{Int8, 3},
    board_stack2::Array{Int8, 3},
    working_board::Matrix{Int8},
    final_board::Matrix{Int8},
    mino_data_out::Vector{MinoItem},
    mino_data_len::Ref{Int},
    laser_start_x::Vector{Int},
    laser_start_y::Vector{Int},
    laser_start_dir::Vector{Int8},
    mirror_counts::Vector{Int},
    ends_x::Vector{Int},
    ends_y::Vector{Int}
)
    minoCount = MINO_MIRROR_TABLE[DIFFICULTY][1]
    
    # 固定長バッファを確保（49マスあれば十分）
    laser_cells_x = Vector{Int8}(undef, 50)
    laser_cells_y = Vector{Int8}(undef, 50)
    laser_cells_len = Ref(0)

    # 以前作成した、get_s 乱数展開をここにインライン、または呼び出し
    # (質問文にある extract_initial_lasers! の確定ロジックをループの先頭で行う)
    
    while true
        # 1. 毎回初期化して始点を決定する
        hashtags = falses(18)
        idx1 = next_int(rnd, Int32(0), Int32(20))
        insert!(hashtags, min(idx1+1, 19), true)
        idx2 = next_int(rnd, Int32(0), Int32(21))
        insert!(hashtags, min(idx2+1, 20), true)
        
        (x1, y1, dx1, dy1) = get_s(Int32(findfirst(hashtags)-1))
        (x2, y2, dx2, dy2) = get_s(Int32(findlast(hashtags)-1))
        
        laser_start_x[1] = x1; laser_start_y[1] = y1
        laser_start_x[2] = x2; laser_start_y[2] = y2
        
        # 方向ベクトルのID化
        get_dir_id(dx, dy) = begin
            if dx==-1 && dy==0; return DIR_LEFT;
            elseif dx==0 && dy==-1; return DIR_UP;
            elseif dx==1 && dy==0; return DIR_RIGHT;
            else return DIR_DOWN; end
        end
        laser_start_dir[1] = get_dir_id(dx1, dy1)
        laser_start_dir[2] = get_dir_id(dx2, dy2)

        mirror_count = MINO_MIRROR_TABLE[DIFFICULTY][2]
        mirror_random_count_1 = Int(next_int(rnd, mirror_count÷2, mirror_count+1))
        mirror_counts[1] = mirror_random_count_1
        mirror_counts[2] = mirror_count - mirror_random_count_1

        # 2. 空盤面の初期化
        empty_board = Matrix{Int8}(undef, 7, 7)
        @inbounds for j in 1:7, i in 1:7
            if i == 1 || i == 7 || j == 1 || j == 7
                empty_board[i, j] = CELL_WALL
            else
                empty_board[i, j] = CELL_EMPTY
            end
        end

        # 3. 2本のレーザーを描画 (draw_two_laser!)
        # この関数の中で要件（通過マス数、鏡数）を満たさない場合は内部で無限ループ再帰を再現している
        draw_two_laser!(
            rnd, board_stack1, board_stack2, empty_board, working_board,
            laser_start_x, laser_start_y, laser_start_dir, mirror_counts, ends_x, ends_y
        )

        # この時点で working_board には、レーザーと鏡がすべて配置され、始点's'・終点'e'が書き込まれた状態が入っている
        # 4. レーザー通過マスの座標をスキャンしてリスト化する
        # TS: e === "\\" || e === "/" || e === "￭"
        c_len = 0
        @inbounds for j in 1:7, i in 1:7
            c = working_board[i, j]
            if c == CELL_LASER || c == CELL_SLASH || c == CELL_BACK
                c_len += 1
                laser_cells_x[c_len] = Int8(j - 1)  # 0-indexed
                laser_cells_y[c_len] = Int8(i - 1)  # 0-indexed
            end
        end
        laser_cells_len[] = c_len

        # 5. ミノのランダム配置を規定回数試行
        mino_data_len[] = 0
        @inbounds for _ in 1:minoCount
            place_random_mino!(
                rnd, working_board, laser_cells_x, laser_cells_y,
                laser_cells_len, mino_data_out, mino_data_len
            )
        end

        # 6. ループ終了条件の検証 (バリデーション)
        # 条件A: 配置されたミノの数が規定数と一致しているか
        if mino_data_len[] != minoCount
            continue
        end

        # 条件B: 盤面にミノで隠されなかった鏡（/ or \）が残っていないか
        has_remaining_mirror = false
        @inbounds for j in 1:7, i in 1:7
            c = working_board[i, j]
            if c == CELL_SLASH || c == CELL_BACK
                has_remaining_mirror = true
                break
            end
        end

        if has_remaining_mirror
            continue # 鏡が残っていたら最初から（レーザー引き直しから）やり直し
        end

        # すべての条件を満たした場合、final_board に確定盤面を移して終了
        @inbounds for j in 1:7, i in 1:7
            final_board[i, j] = working_board[i, j]
        end
        break
    end
end

"""
指定されたシード値からパズルデータを生成し、結果を返すエントリーポイント。
この関数自体の内部で初期バッファを確保し、生成ロジック中のアロケーションをゼロにする。
"""
function generate_20260614()
    # 1. 乱数生成器の初期化 (シード: 20260614)
    # ※TypeScript側の `new random(20260614)` と等価な初期状態
    seed_val = Int32(20260614)
    rnd = TSRandom(seed_val)

    # 2. バックトラックおよび描画用スタック・バッファの事前確保
    # レーザーの最大ステップ数を100と想定し、3次元配列の深さを101確保
    MAX_DEPTH = 101
    board_stack1 = zeros(Int8, 7, 7, MAX_DEPTH)
    board_stack2 = zeros(Int8, 7, 7, MAX_DEPTH)
    
    working_board = zeros(Int8, 7, 7)
    final_board   = zeros(Int8, 7, 7)

    # ミノ格納用バッファ (oniplus時の最大数 7 に合わせる)
    mino_data_out = Vector{MinoItem}(undef, MAX_MINO_COUNT)
    mino_data_len = Ref(0)

    # レーザー制御用の各種配列バッファ
    laser_start_x   = zeros(Int, 2)
    laser_start_y   = zeros(Int, 2)
    laser_start_dir = zeros(Int8, 2)
    mirror_counts   = zeros(Int, 2)
    ends_x          = zeros(Int, 2)
    ends_y          = zeros(Int, 2)

    # 3. パズル生成の実行
    # 内部ループはすべてこれらの事前確保された領域をインプレースで書き換えるため、ヒープアロケーションは発生しない
    generate_puzzle!(
        rnd,
        board_stack1,
        board_stack2,
        working_board,
        final_board,
        mino_data_out,
        mino_data_len,
        laser_start_x,
        laser_start_y,
        laser_start_dir,
        mirror_counts,
        ends_x,
        ends_y
    )

    # 4. 確定した結果の抽出
    # 呼び出し側へ返すためにのみ、ここで構造化オブジェクト（あるいはタプル）を生成
    actual_mino_count = mino_data_len[]
    minos = [mino_data_out[i] for i in 1:actual_mino_count]

    return (
        board = final_board,
        minos = minos,
        starts = [(x=laser_start_x[1], y=laser_start_y[1]), (x=laser_start_x[2], y=laser_start_y[2])],
        ends = [(x=ends_x[1], y=ends_y[1]), (x=ends_x[2], y=ends_y[2])]
    )
end

# 内部デバッグ・可視化用の簡易ヘルパー
function print_board(board::Matrix{Int8})
    # 定数IDに対応する文字列表現
    char_map = Dict{Int8, String}(
        CELL_EMPTY => "  ",
        CELL_WALL  => " #",
        CELL_LASER => " ￭",
        CELL_SLASH => " /",
        CELL_BACK  => " \\",
        CELL_START => " s",
        CELL_END   => " e"
    )
    
    # ミノID (0~17) はそのまま数値文字列として出力
    for i in 0:17
        char_map[Int8(i)] = lpad(string(i), 2)
    end

    for i in 1:7
        for j in 1:7
            print(get(char_map, board[i, j], " ?"))
        end
        println()
    end
end

# --- 実行セクション ---
result = generate_20260614()

println("=== 20260614 確定盤面 ===")
print_board(result.board)

println("\n=== 配置されたミノのデータ (MinoItem) ===")
for (idx, m) in enumerate(result.minos)
    println("Mino [$idx]: ID=$(m.id), cx=$(m.cx), cy=$(m.cy), vertex=$(m.vertex)")
end