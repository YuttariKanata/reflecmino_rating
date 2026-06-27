# レーザーの進む方向（符号付きインデックス計算に便利に割り振ることも可能）
@enum Direction::UInt8 begin
    DIR_UP    = 0
    DIR_RIGHT = 1
    DIR_DOWN  = 2
    DIR_LEFT  = 3
end

# マスの鏡の状態
@enum Mirror::UInt8 begin
    MIRROR_NONE  = 0  # 空白（素通り）
    MIRROR_SLASH = 1  # 右上から左下 (/)
    MIRROR_BACK  = 2  # 左上から右下 (\)
end

# 2種類あるレーザーの色
@enum LaserColor::UInt8 begin
    LASER_ORANGE = 1
    LASER_BLUE   = 2
end

struct Polyomino3
    # 基準点(0,0)から見た3マスの相対座標（例: (0,0), (0,1), (1,0) など）
    # 型安定のため NTuple を使用
    offsets::NTuple{3, CartesianIndex{2}}
    # 各マスに乗っている鏡
    mirrors::NTuple{3, Mirror}
end

struct BoardState
    # ピースが配置されているマス（1なら占有、0なら空白）
    # 5x5 = 25マスなので UInt32 に収まる
    # 座標 (r, c) のビット位置： 1 << ((r-1)*5 + (c-1))
    occupied::UInt32

    # 盤面全体の鏡の配置（各マス2ビット消費、25マス×2 = 50ビットで UInt64 に収まる）
    # 00: なし, 01: /, 10: \
    mirror_map::UInt64
end

# 座標からビットインデックスへのインライン変換
@inline function coord_to_bit(r::Integer, c::Integer)
    return UInt32(1) << (Int32(r - 1) * Int32(5) + Int32(c - 1))
end

struct StateData
    # 真の解（正解の配置）との幾何学的編集距離 d
    distance::Int8
    
    # 状態の評価特徴量（主観的尤度 P_look の計算用）
    lasers_cleared::Int8  # ゴールしたレーザーの本数 (0~2)
    coverage_rate::Float32 # 盤面上のピースマスのうち、レーザーが踏んだ割合 (0.0 ~ 1.0)
    pieces_used::Int8     # 使用されたピースの数
end

# 座標から鏡のシフト量（0 ~ 48）を計算するインライン関数
@inline function coord_to_mirror_shift(r::Integer, c::Integer)
    return Int32(((r - 1) * 5 + (c - 1)) << 1)
end

# 盤面から特定のマスの鏡を取得
@inline function get_mirror(board::BoardState, r::Integer, c::Integer)
    shift = coord_to_mirror_shift(r, c)
    val = UInt8((board.mirror_map >> shift) & 0x03)
    return reinterpret(Mirror, val)
end

# 盤面に鏡をセットした新しい BoardState を返す（非破壊）
@inline function set_mirror(board::BoardState, r::Integer, c::Integer, mirror::Mirror)
    shift = coord_to_mirror_shift(r, c)
    mask = ~(UInt64(0x03) << shift)
    new_map = (board.mirror_map & mask) | (UInt64(UInt8(mirror)) << shift)
    return BoardState(board.occupied, new_map)
end

# ピースを座標 (r, c) に配置可能か判定
@inline function can_place(piece::Polyomino3, r::Integer, c::Integer, board::BoardState)
    @inbounds for i in 1:3
        offset = piece.offsets[i]
        nr = r + offset.I[1]
        nc = c + offset.I[2]
        
        # 境界チェック
        if !(1 <= nr <= 5 && 1 <= nc <= 5)
            return false
        end
        
        # 衝突（既に埋まっているか）チェック
        p_bit = coord_to_bit(nr, nc)
        if (board.occupied & p_bit) != 0
            return false
        end
    end
    return true
end

# ピースを配置した新しい BoardState を返す
# 事前に can_place でチェックされている前提（パフォーマンス優先）
@inline function place_piece(piece::Polyomino3, r::Integer, c::Integer, board::BoardState)
    new_occupied = board.occupied
    new_mirror_map = board.mirror_map
    
    @inbounds for i in 1:3
        offset = piece.offsets[i]
        nr = r + offset.I[1]
        nc = c + offset.I[2]
        
        # occupied ビットの更新
        new_occupied |= coord_to_bit(nr, nc)
        
        # 鏡の更新
        shift = coord_to_mirror_shift(nr, nc)
        mirror_val = UInt64(UInt8(piece.mirrors[i]))
        new_mirror_map |= (mirror_val << shift)
    end
    
    return BoardState(new_occupied, new_mirror_map)
end

# 射出口 / 射入口の定義
struct LaserPort
    r::Int8
    c::Int8
    dir::Direction # 射出口なら盤面への進入方向、射入口なら盤面から出てくる方向
end

# 鏡による方向転換（テーブルルックアップで分岐を消す）
# 引数：現在の進行方向, 鏡の種類 -> 次の進行方向
@inline function reflect(dir::Direction, mirror::Mirror)
    if mirror == MIRROR_NONE
        return dir
    elseif mirror == MIRROR_SLASH # / 鏡
        if dir == DIR_UP;    return DIR_RIGHT;  end
        if dir == DIR_RIGHT; return DIR_UP;     end
        if dir == DIR_DOWN;  return DIR_LEFT;   end
        if dir == DIR_LEFT;  return DIR_DOWN;   end
    elseif mirror == MIRROR_BACK  # \ 鏡
        if dir == DIR_UP;    return DIR_LEFT;   end
        if dir == DIR_RIGHT; return DIR_DOWN;   end
        if dir == DIR_DOWN;  return DIR_RIGHT;  end
        if dir == DIR_LEFT;  return DIR_UP;     end
    end
    return dir
end



# 1本のレーザーを走らせる
# 返り値: (成否::Bool, 通過マスのビットボード::UInt32)
function trace_laser(start_port::LaserPort, end_port_1::LaserPort, end_port_2::LaserPort, board::BoardState)
    r, c = start_port.r, start_port.c
    dir = start_port.dir
    path_bits = UInt32(0)
    
    while 1 <= r <= 5 && 1 <= c <= 5
        # 現在のマスを通過履歴に記録
        path_bits |= coord_to_bit(r, c)
        
        # 鏡による反射
        mirror = get_mirror(board, r, c)
        dir = reflect(dir, mirror)
        
        # 次のマスへ進む
        if dir == DIR_UP;    r -= 1
        elseif dir == DIR_RIGHT; c += 1
        elseif dir == DIR_DOWN;  r += 1
        elseif dir == DIR_LEFT;  c -= 1
        end
    end
    
    # 盤面を出た位置が、いずれかの射入口(の盤面外隣接マス)と一致しているか判定
    # ※ポートの座標(r,c)が1~5の境界上にあるとし、出た直後の座標がポートの「一歩外」に一致するかを見る
    # ここでは単純化のため、出た位置(r,c)が、目標ポートの座標からそのdir方向へ一歩外に出た位置と一致するかをチェック
    
    success_1 = (r == end_port_1.r - (end_port_1.dir == DIR_UP ? 1 : end_port_1.dir == DIR_DOWN ? -1 : 0) &&
                 c == end_port_1.c - (end_port_1.dir == DIR_LEFT ? 1 : end_port_1.dir == DIR_RIGHT ? -1 : 0))
                 
    success_2 = (r == end_port_2.r - (end_port_2.dir == DIR_UP ? 1 : end_port_2.dir == DIR_DOWN ? -1 : 0) &&
                 c == end_port_2.c - (end_port_2.dir == DIR_LEFT ? 1 : end_port_2.dir == DIR_RIGHT ? -1 : 0))
                 
    return (success_1 || success_2), path_bits
end

# 2本のレーザーをシミュレートし、評価特徴量を返す
function simulate_lasers(board::BoardState, orange_start::LaserPort, blue_start::LaserPort, in_port_1::LaserPort, in_port_2::LaserPort, total_pieces::Int)
    # オレンジレーザーの追跡
    ok_orange, path_orange = trace_laser(orange_start, in_port_1, in_port_2, board)
    # 水色レーザーの追跡
    ok_blue, path_blue = trace_laser(blue_start, in_port_1, in_port_2, board)
    
    # 1. ゴールしたレーザーの本数
    # ただし、同じ射入口に2本とも突っ込んでしまった場合は不合格（射入口が被らない仕様）
    # ここでは厳密な判定は上位に任せるか、ポートIDを追跡して分離するが、一旦本数でカウント
    lasers_cleared = Int8(ok_orange) + Int8(ok_blue)
    
    # 2. 盤面上のピースマスがどれだけ照らされたか (Coverage)
    all_path = path_orange | path_blue
    piece_mask = board.occupied
    
    if piece_mask == 0
        coverage_rate = Float32(0.0)
    else
        # ピースがあるマスのうち、レーザーが通ったマスの数
        covered_count = count_ones(all_path & piece_mask)
        total_piece_cells = count_ones(piece_mask)
        coverage_rate = Float32(covered_count) / Float32(total_piece_cells)
    end
    
    return lasers_cleared, coverage_rate
end

# 問題の入力データを保持する構造体
struct StageProblem{N} # N はピース数 (4, 5, 7 など)
    orange_start::LaserPort
    blue_start::LaserPort
    in_port_1::LaserPort
    in_port_2::LaserPort
    pieces::NTuple{N, Polyomino3}
end

# 探索中に「各ピースがどこに置かれたか」を記録する内部用状態
struct Placement
    is_placed::Bool
    r::Int8
    c::Int8
end

# 全探索を統括するコンテナ
struct SearchContext{N}
    problem::StageProblem{N}
    # 探索で見つかったすべての有効な配置に対する統計データ
    states_data::Vector{StateData}
    # 真の解（正解）の配置を一時的に特定・保持するための領域
    # 最初の全探索で正解を特定し、2回目のパスで距離を確定させるアプローチを取る
    true_placements::Vector{Placement}
end

# 1パスマイル：まずは普通に全探索して、唯一の「真の解」の配置を特定する
function find_true_solution!(
    piece_idx::Int, 
    current_board::BoardState, 
    current_placements::Vector{Placement}, 
    ctx::SearchContext{N}
) where N
    if piece_idx > N
        # レーザーシミュレーション
        lasers, coverage = simulate_lasers(
            current_board, 
            ctx.problem.orange_start, ctx.problem.blue_start, 
            ctx.problem.in_port_1, ctx.problem.in_port_2, N
        )
        # 全ピース使用 ＆ レーザー2本開通 ＆ 全マス通過 が真の解の条件
        all_used = all(p -> p.is_placed, current_placements)
        if all_used && lasers == 2 && coverage == Float32(1.0)
            ctx.true_placements .= current_placements
        end
        return
    end

    # 選択肢1: 置かない
    current_placements[piece_idx] = Placement(false, 0, 0)
    find_true_solution!(piece_idx + 1, current_board, current_placements, ctx)

    # 選択肢2: 置く（回転禁止なので位置の全探索）
    piece = ctx.problem.pieces[piece_idx]
    for r in 1:5, c in 1:5
        if can_place(piece, r, c, current_board)
            next_board = place_piece(piece, r, c, current_board)
            current_placements[piece_idx] = Placement(true, Int8(r), Int8(c))
            find_true_solution!(piece_idx + 1, next_board, current_placements, ctx)
        end
    end
end

# 2パスマイル：真の解との幾何学的距離を計算しながら、すべてのデータを配列に回収する
function collect_states_data!(
    piece_idx::Int, 
    current_board::BoardState, 
    current_placements::Vector{Placement}, 
    ctx::SearchContext{N}
) where N
    if piece_idx > N
        lasers, coverage = simulate_lasers(
            current_board, 
            ctx.problem.orange_start, ctx.problem.blue_start, 
            ctx.problem.in_port_1, ctx.problem.in_port_2, N
        )
        
        # 幾何学的距離 D(σ) の計算：正解の配置（位置・配置有無）と異なるピースの数
        distance = 0
        for i in 1:N
            if current_placements[i].is_placed != ctx.true_placements[i].is_placed ||
               (current_placements[i].is_placed && (current_placements[i].r != ctx.true_placements[i].r || current_placements[i].c != ctx.true_placements[i].c))
                distance += 1
            end
        end
        
        pieces_used = count(p -> p.is_placed, current_placements)
        
        # 統計データを保存
        push!(ctx.states_data, StateData(Int8(distance), lasers, coverage, Int8(pieces_used)))
        return
    end

    # 置かないルート
    current_placements[piece_idx] = Placement(false, 0, 0)
    collect_states_data!(piece_idx + 1, current_board, current_placements, ctx)

    # 置くルート
    piece = ctx.problem.pieces[piece_idx]
    for r in 1:5, c in 1:5
        if can_place(piece, r, c, current_board)
            next_board = place_piece(piece, r, c, current_board)
            current_placements[piece_idx] = Placement(true, Int8(r), Int8(c))
            collect_states_data!(piece_idx + 1, next_board, current_placements, ctx)
        end
    end
end

# 難易度判定のメインロジック
# beta: 人間の認知の鋭さ（逆温度）、w: 各特徴量の重み (レーザー開通数, カバレッジ, ピース使用率)
function evaluate_difficulty(states::Vector{StateData}; beta::Float32=Float32(2.0), w::NTuple{3, Float32}=(Float32(2.0), Float32(3.0), Float32(1.0)))
    # 1. 各状態の「解けてそうスコア」S(σ) の計算と最大値の抽出（ソフトマックスのアンダーフロー/オーバーフロー対策）
    n_states = length(states)
    scores = Vector{Float32}(undef, n_states)
    max_score = -Inf32
    
    @inbounds for i in 1:n_states
        st = states[i]
        # 使用率の計算
        u_rate = Float32(st.pieces_used) # 分母は固定なので比例値として扱う
        
        # S(σ) = w1 * L(σ) + w2 * C(σ) + w3 * U(σ)
        s = w[1] * Float32(st.lasers_cleared) + w[2] * st.coverage_rate + w[3] * u_rate
        scores[i] = s
        if s > max_score
            max_score = s
        end
    end
    
    # 2. 主観的尤度 P_look(σ) の計算（正規化）
    p_look = Vector{Float32}(undef, n_states)
    sum_exp = Float32(0.0)
    @inbounds for i in 1:n_states
        p_look[i] = exp(beta * (scores[i] - max_score))
        sum_exp += p_look[i]
    end
    @inbounds for i in 1:n_states
        p_look[i] /= sum_exp
    end
    
    # 3. 認知エントロピーの計算
    # H_cognitive = - Σ (P_look(σ) * D(σ) * log(P_look(σ)))
    cognitive_entropy = Float32(0.0)
    @inbounds for i in 1:n_states
        p = p_look[i]
        if p > Float32(1e-8)
            d = Float32(states[i].distance)
            cognitive_entropy -= p * d * log(p)
        end
    end
    
    return cognitive_entropy
end

# 外部から一発で難易度点数を呼び出すためのラッパー
function calculate_stage_difficulty(prob::StageProblem{N}) where N
    initial_board = BoardState(0, 0)
    current_placements = [Placement(false, 0, 0) for _ in 1:N]
    
    ctx = SearchContext(prob, StateData[], [Placement(false, 0, 0) for _ in 1:N])
    
    # パス1: 正解の特定
    find_true_solution!(1, initial_board, current_placements, ctx)
    
    # パス2: 統計データの全回収
    collect_states_data!(1, initial_board, current_placements, ctx)
    
    # 難易度点数の算出
    return evaluate_difficulty(ctx.states_data)
end

# 真の解の配置を視覚的に表示する関数
function print_true_solution(ctx::SearchContext{N}) where N
    # 配置が見つかっていない場合のチェック
    has_sol = any(p -> p.is_placed, ctx.true_placements)
    if !has_sol
        println("真の解は特定されていません。")
        return
    end

    # 5x5 の盤面を 0 (空白) で初期化
    grid = zeros(Int8, 5, 5)

    # 各ピースの配置をグリッドに書き込む
    for i in 1:N
        placement = ctx.true_placements[i]
        if placement.is_placed
            piece = ctx.problem.pieces[i]
            r, c = placement.r, placement.c
            
            # ピースの各マスの相対座標を絶対座標に変換してID（i）を埋める
            for offset in piece.offsets
                nr = r + offset.I[1]
                nc = c + offset.I[2]
                grid[nr, nc] = Int8(i)
            end
        end
    end

    # 綺麗に整形して出力
    println("\n--- [真の解のピース配置] ---")
    for r in 1:5
        print("  ")
        for c in 1:5
            val = grid[r, c]
            if val == 0
                print(". ") # 空白マス
            else
                print(val, " ") # ピースID (1~4)
            end
        end
        println()
    end
    println("----------------------------")
end

# test1.jl の末尾に追加する正しいコンストラクタ
function Polyomino3(mirror_str::AbstractString, coords::Vararg{Tuple{Integer, Integer}, 3})
    # 1. 座標のパース (Vararg が後ろにきたので coords から 3 つ引っこ抜く)
    offsets = (
        CartesianIndex(coords[1][1], coords[1][2]),
        CartesianIndex(coords[2][1], coords[2][2]),
        CartesianIndex(coords[3][1], coords[3][2])
    )
    
    # 2. 鏡文字列のパース
    if length(mirror_str) < 3
        error("鏡の指定文字列は3文字以上必要です。例: \"/\\ \"")
    end
    
    function parse_char(c::Char)
        if c == '/'
            return MIRROR_SLASH
        elseif c == '\\'
            return MIRROR_BACK
        elseif c == ' ' || c == '.'
            return MIRROR_NONE
        else
            error("不正な鏡文字です: '$c'. 使用可能: '/', '\\', ' ', '.'")
        end
    end
    
    chars = collect(mirror_str)
    mirrors = (parse_char(chars[1]), parse_char(chars[2]), parse_char(chars[3]))
    
    return Polyomino3(offsets, mirrors)
end

using Printf

# 難易度計算の数学的内訳をはっきりと数式・数値付きで表示する関数
function print_difficulty_math_analysis(states::Vector{StateData}; beta::Float32=Float32(2.0), w::NTuple{3, Float32}=(Float32(2.0), Float32(3.0), Float32(1.0)))
    n_states = length(states)
    if n_states == 0
        println("状態データが空です。")
        return
    end

    # --- 1. 各状態のスコア計算（内部ロジックの再追跡） ---
    scores = Vector{Float32}(undef, n_states)
    max_score = -Inf32
    @inbounds for i in 1:n_states
        st = states[i]
        s = w[1] * Float32(st.lasers_cleared) + w[2] * st.coverage_rate + w[3] * Float32(st.pieces_used)
        scores[i] = s
        if s > max_score
            max_score = s
        end
    end

    p_look = Vector{Float32}(undef, n_states)
    sum_exp = Float32(0.0)
    @inbounds for i in 1:n_states
        p_look[i] = exp(beta * (scores[i] - max_score))
        sum_exp += p_look[i]
    end
    @inbounds for i in 1:n_states
        p_look[i] /= sum_exp
    end

    # --- 2. 数学的な構造を明示するためのビン（バケット）集計 ---
    # スコアのユニーク値ごとに、状態数、平均幾何距離、エントロピー寄与度を集計
    # 辞書を使ってユニークスコアを丸めて管理（Float32の誤差対策）
    class_dict = Dict{Float32, Vector{Int}}() # score -> indices
    for i in 1:n_states
        s_rounded = round(scores[i], digits=3)
        if !haskey(class_dict, s_rounded)
            class_dict[s_rounded] = Int[]
        end
        push!(class_dict[s_rounded], i)
    end

    # スコア降順（人間が惹きつけられやすい順）にソート
    sorted_scores = sort(collect(keys(class_dict)), rev=true)

    # --- 3. 画面への出力情報の構築 ---
    println("\n========================================================================")
    println("      【 難易度解析エンジン : 認知エントロピー 数学内訳表示 】")
    println("========================================================================")
    println("■ 1. 状態評価関数（主観的ポテンシャル）の定式化:")
    println("   S(σ) = w₁·L(σ) + w₂·C(σ) + w₃·U(σ)")
    @printf("   [設定重み] w₁ (レーザー) = %.1f,  w₂ (カバレッジ) = %.1f,  w₃ (使用率) = %.1f\n", w[1], w[2], w[3])
    @printf("   [認知解像度（逆温度）] β = %.1f\n", beta)
    println("   [全探索空間の総数] |Σ| = ", n_states)
    @printf("   [理論上の最大スコア] S_max = %.3f\n", max_score)
    println("\n■ 2. 主観的尤度（ギブス分布）の正規化方程式:")
    println("   P_look(σ) = exp(β · (S(σ) - S_max)) / Z")
    @printf("   [分配関数（規格化因子）] Z = Σ exp(β · (S(σ) - S_max)) = %.4f\n", sum_exp)
    
    println("\n■ 3. ポテンシャル帯ごとのマクロ統計およびエントロピー寄与内訳:")
    println("------------------------------------------------------------------------")
    @printf("%-10s | %-8s | %-12s | %-12s | %-12s\n", "Score S(σ)", "状態数", "主観確率ΣP", "平均幾何距離D", "エントロピー寄与")
    println("------------------------------------------------------------------------")

    total_entropy = Float32(0.0)
    for s in sorted_scores
        indices = class_dict[s]
        count_sigma = length(indices)
        
        sum_p = Float32(0.0)
        sum_d = Float32(0.0)
        entropy_contribution = Float32(0.0)
        
        for idx in indices
            p = p_look[idx]
            sum_p += p
            sum_d += states[idx].distance
            if p > Float32(1e-8)
                entropy_contribution -= p * Float32(states[idx].distance) * log(p)
            end
        end
        
        avg_d = sum_d / count_sigma
        total_entropy += entropy_contribution
        
        # 特に確率が高い（プレイヤーがハメられる）セクターを強調
        tag = sum_p > Float32(0.05) ? " ★" : ""
        @printf("%10.3f | %8d | %12.5f | %12.2f | %12.5f%s\n", s, count_sigma, sum_p, avg_d, entropy_contribution, tag)
    end
    println("------------------------------------------------------------------------")
    
    println("\n■ 4. 最終統合方程式（認知エントロピー）の収束:")
    println("   H_cognitive = - Σ [ P_look(σ) · D(σ) · ln(P_look(σ)) ]")
    @printf("   ⇒ 算出された総認知エントロピー = %.6f\n", total_entropy)
    println("========================================================================\n")
end