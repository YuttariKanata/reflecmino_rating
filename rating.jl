include("generator.jl")

# グラフ描画などで整形して出力するために printf をインポート
using Printf
using StaticArrays
using Graphs
using Statistics
using Dates
using Serialization


const MINO_COUNT = MINO_MIRROR_TABLE[DIFFICULTY][1]

# マスクをクリアするための定数
const PIECE_MASK = UInt64(0b111111)



struct PlacementCandidate
    board_mask::UInt32  # 5x5盤面上での位置を表すビットボード (衝突判定用)
    state_mask::UInt64  # 42ビット状態(State)に埋め込むためのビット値 (状態記録用)
end

"""
5x5の座標 (c, r) を、UInt32ビットボードの何番目のビット(0〜24シフト)にするか計算する
"""
@inline function coord_to_bitshift(c::Int, r::Int)::Int
    return (r - 1) * 5 + (c - 1)
end

"""
各ピースの全配置パターンを、ビットボード(UInt32)として前計算する
"""
function precompute_candidates_bitboard(minosdata::Vector{Tuple{CellData, CellData, CellData}})::NTuple{MINO_COUNT, Vector{PlacementCandidate}}
    temp_list = [Vector{PlacementCandidate}() for _ in 1:MINO_COUNT]
    
    for idx in 1:MINO_COUNT
        piece = minosdata[idx]
        ref_x, ref_y = piece[1].x, piece[1].y
        
        dx1, dy1 = piece[1].x - ref_x, piece[1].y - ref_y
        dx2, dy2 = piece[2].x - ref_x, piece[2].y - ref_y
        dx3, dy3 = piece[3].x - ref_x, piece[3].y - ref_y
        rel_cells = ((Int(dx1), Int(dy1)), (Int(dx2), Int(dy2)), (Int(dx3), Int(dy3)))
        
        # 42ビット状態に埋め込むときのシフト量
        state_shift = (idx - 1) * 6
        
        for r in 1:5, c in 1:5
            is_inside = true
            for (dx, dy) in rel_cells
                if !(1 <= c + dx <= 5 && 1 <= r + dy <= 5)
                    is_inside = false
                    break
                end
            end
            
            if is_inside
                # ① 盤面ビットボード（UInt32）のマスクを作成
                b_mask = UInt32(0)
                for (dx, dy) in rel_cells
                    shift = coord_to_bitshift(c + dx, r + dy)
                    b_mask |= (UInt32(1) << shift)
                end
                
                # ② 42ビット状態（UInt64）のマスクを作成
                # (r << 3) | c を指定位置までシフトしておく
                s_mask = UInt64((r << 3) | c) << state_shift
                
                push!(temp_list[idx], PlacementCandidate(b_mask, s_mask))
            end
        end
    end
    
    return Tuple(temp_list)
end

"""
ビットボード版：すべての合法な盤面状態を最速で列挙するエントリー関数
"""
function collect_all_states_bitboard(minosdata::Vector{Tuple{CellData, CellData, CellData}})::Tuple{Vector{UInt64}, NTuple{MINO_COUNT, Vector{PlacementCandidate}}}
    # 1. 最初に1回だけ、すべての配置パターンをビットマスクとして前計算（Tuple型）
    all_candidates = precompute_candidates_bitboard(minosdata)
    
    # 2. 結果を格納する配列（UInt64）を用意し、メモリ領域をあらかじめ確保
    hist = Vector{UInt64}()
    sizehint!(hist, 900000)
    
    # 初期状態
    initial_board = UInt32(0) # 盤面はすべて空（全ビット0）
    initial_state = UInt64(0) # 7つのピースはすべて未配置（全ビット0）
    
    # 3. 探索スタート
    search_nodes_bitboard!(1, all_candidates, initial_board, initial_state, hist)
    
    return hist, all_candidates
end

"""
探索のコア（再帰関数）
"""
function search_nodes_bitboard!(
    piece_idx::Int, 
    all_candidates::NTuple{MINO_COUNT, Vector{PlacementCandidate}}, 
    current_board::UInt32, 
    current_state::UInt64, 
    hist::Vector{UInt64}
    )
    # 【ベースケース】7つすべてのピースの吟味が終わったら記録して終了
    if piece_idx > MINO_COUNT
        push!(hist, current_state)
        return
    end

    # パターン①：このピースは配置しない（パス）
    # 盤面も状態ビットも変更せず、そのまま次のピースへ進む
    search_nodes_bitboard!(piece_idx + 1, all_candidates, current_board, current_state, hist)

    # パターン②：このピースを配置する
    # 事前計算された「このピースがはみ出さない配置リスト」だけをループ
    candidates = @inbounds all_candidates[piece_idx]
    
    for cand in candidates
        
        # 【衝突判定】現在の盤面と、ピースの形が1マスも重なっていないか？
        # ビットの論理積（&）が0なら、どこも重なっていないので配置OK！
        if (current_board & cand.board_mask) == 0
            
            # 【配置と遷移】
            # 盤面ビット：論理和（|）でピースの形を埋める
            # 状態ビット：論理和（|）で42ビットの中に座標(c, r)を埋める
            next_board = current_board | cand.board_mask
            next_state = current_state | cand.state_mask
            
            # 次のピースの探索へ進む
            search_nodes_bitboard!(piece_idx + 1, all_candidates, next_board, next_state, hist)
            
            # 【バックトラック】
            # ループの次のイテレーションでは、元の「current_board」「current_state」を
            # そのまま使うため、明示的に消去する処理（消しゴムをかける処理）は一切不要です！
        end
    end
end


"""
シングルスレッド究極高速版（エッジ一括生成 ＆ ビット衝突チェック）
"""
function build_puzzle_graph_drag_ultimate(states::Vector{UInt64}, all_candidates::NTuple{MINO_COUNT, Vector{PlacementCandidate}})
    num_nodes = length(states)
    
    # 1. 状態からIDを逆引きする辞書
    state_to_id = Dict{UInt64, Int}(state => i for (i, state) in enumerate(states))
    
    # 【メモリ最適化】
    # 3万回の実験から、登録されるエッジ数は約670万本前後（counter5）だと分かっているので
    # 最初にガツッとメモリを確保して、探索中のpush!速度を最速にします。
    edges = Vector{Edge{Int}}()
    sizehint!(edges, 7000000)

    # 各ノードの「現在の盤面ビットボード(UInt32)」をあらかじめ一括復元
    boards = Vector{UInt32}(undef, num_nodes)
    for i in 1:num_nodes
        st = states[i]
        b = UInt32(0)
        for p_idx in 1:MINO_COUNT
            shift = (p_idx - 1) * 6
            p_bits = (st >> shift) & PIECE_MASK
            if p_bits != 0
                for cand in all_candidates[p_idx]
                    if ((cand.state_mask >> shift) & PIECE_MASK) == p_bits
                        b |= cand.board_mask
                        break
                    end
                end
            end
        end
        boards[i] = b
    end
    
    # 3. すべてのノード（盤面）について、ドラッグ＆ドロップの遷移を調べる
    for u_id in 1:num_nodes
        current_state = states[u_id]
        current_board = boards[u_id]
        
        for piece_idx in 1:MINO_COUNT
            state_shift = (piece_idx - 1) * 6
            
            # 該当ピースのビット領域を 000000（未配置）にしたベース状態
            state_removed = current_state & ~(PIECE_MASK << state_shift)
            
            # 現在のピースのボードマスクを特定し、それを除いた「他のピースだけの盤面」を作る
            p_bits = (current_state >> state_shift) & PIECE_MASK
            current_piece_board = UInt32(0)
            if p_bits != 0
                for cand in all_candidates[piece_idx]
                    if ((cand.state_mask >> state_shift) & PIECE_MASK) == p_bits
                        current_piece_board = cand.board_mask
                        break
                    end
                end
            end
            other_board = current_board & ~current_piece_board
            
            # --- 遷移パターンB：別の場所にワープする ---
            candidates = @inbounds all_candidates[piece_idx]
            for cand in candidates
                
                # 【ビット衝突チェック】重なっていたら即スキップ
                if (other_board & cand.board_mask) != 0
                    continue
                end
                
                next_state = state_removed | cand.state_mask
                if next_state == current_state
                    continue
                end
                
                # 衝突していない合法的配置の可能性があるときだけ辞書を引く
                v_id = get(state_to_id, next_state, 0)
                if v_id > u_id
                    # add_edge!の代わりに、ただの配列へのpush!（事前確保済みなため爆速）
                    push!(edges, Edge(u_id, v_id))
                end
            end
        end
    end
    
    # # 4. まず指定した頂点数（num_nodes）で空のグラフを作る
    # g = SimpleGraph(num_nodes)
    
    # # 5. 溜まったエッジを一気に流し込む（裏側で高速に隣接リストが構築されます）
    # for e in edges
    #     add_edge!(g, e)
    # end
    return edges
    #return SimpleGraph(edges)
end


"""
全状態（states）の中から、ミノが何個(0〜7個)置かれているかの内訳を統計する関数
"""
function analyze_piece_counts(states::Vector{UInt64})
    # 0個〜7個の配置数を記録するカウンター（インデックス1が0個、8が7個に対応）
    counts = zeros(Int, 8)
    
    for st in states
        placed_pieces = 0
        for p_idx in 1:MINO_COUNT
            shift = (p_idx - 1) * 6
            p_bits = (st >> shift) & PIECE_MASK
            # 座標が(0,0)でなければ「配置されている」とカウント
            if p_bits != 0
                placed_pieces += 1
            end
        end
        # 該当する個数のカウンターをインクリメント
        counts[placed_pieces + 1] += 1
    end
    
    # 結果を見やすく綺麗に表示
    println("=== ミノ配置数の統計 ===")
    println("総状態数: ", length(states))
    println("-----------------------")
    for i in 0:MINO_COUNT
        num_states = counts[i + 1]
        percentage = round((num_states / length(states)) * 100, digits=2)
        println("ミノ $i 個配置: $(num_states) 通り ($(percentage)%)")
    end
    println("=======================")
    
    return counts
end





"""
42ビット状態(state)を、シミュレーション用の 5x5 Matrix{Int8} に変換（デコード）する関数
※ミノの存在する全マスを CELL_MINO(8) または各鏡のIDで埋める仕様に変更
"""
function decode_state_to_matrix!(
    grid::Matrix{Int8},     # 毎回「無」をもらっておく
    state::UInt64, 
    minosdata::Vector{Tuple{CellData, CellData, CellData}}
    )::Int
    
    # 1. ベースとなる固定盤面をコピー（サイズは 5x5 固定、初期値はすべて0）
    #grid = zeros(Int8, 5, 5)
    #grid = zeros(MMatrix{5,5,Int8})
    mino_number = MINO_COUNT
        
    # 2. 1番〜7番のピースを順にデコードして盤面に書き込む
    for idx in 1:MINO_COUNT
        shift = (idx - 1) * 6
        p_bits = (state >> shift) & PIECE_MASK
        
        # 座標が (0,0) の場合は「未配置（持ち駒）」なのでスキップ
        if p_bits == 0
            mino_number -= 1
            continue
        end
        
        # 基準点(c, r)の座標を復元
        c = Int(p_bits & 0b111)       # 下位3ビットが列 (x)
        r = Int((p_bits >> 3) & 0b111) # 上位3ビットが行 (y)
        
        # --- ピースの形状（3マス分）を盤面に書き込む ---
        @inbounds piece = minosdata[idx]
        ref_x, ref_y = piece[1].x, piece[1].y
        
        for cell in piece
            # 基準点からの相対座標を計算
            dx = cell.x - ref_x
            dy = cell.y - ref_y
            nx = c + dx
            ny = r + dy
            
            # ミノの領域であれば、一旦ベースとして CELL_MINO(8) を書き込む
            #（空白マスであってもミノの枠内であることを示す）
            #@inbounds grid[ny, nx] = CELL_MINO
            
            # もしそのマスが鏡（CELL_SLASH(3) または CELL_BACKS(4)）なら、上書きする
            if cell.type != CELL_LASER
                @inbounds grid[ny, nx] = cell.type
            else
                @inbounds grid[ny, nx] = CELL_MINO
            end
        end
    end
    
    return mino_number
end

"""
状態(state)をデコードし、盤面上のどのマスに何番目のミノが配置されているかを
5x5のグリッド形式で綺麗にプリントする関数
"""
function print_mino_layout(state::UInt64, minosdata::Vector{Tuple{CellData, CellData, CellData}})
    # 5x5の表示用マトリクス（0で初期化）
    # 0: 空白、1〜7: 各ミノの番号
    layout = zeros(Int, 5, 5)
    
    for idx in 1:MINO_COUNT
        shift = (idx - 1) * 6
        p_bits = (state >> shift) & PIECE_MASK
        
        # 未配置（持ち駒）の場合はスキップ
        if p_bits == 0
            continue
        end
        
        # 基準点(c, r)の座標を復元
        c = Int(p_bits & 0b111)
        r = Int((p_bits >> 3) & 0b111)
        
        # ピースの形状（3マス分）を取得
        piece = minosdata[idx]
        ref_x, ref_y = piece[1].x, piece[1].y
        
        for cell in piece
            # 基準点からの相対座標を計算
            dx = cell.x - ref_x
            dy = cell.y - ref_y
            nx = c + dx
            ny = r + dy
            
            # 盤面配列(1〜5)にミノのインデックス（番号）を書き込む
            if 1 <= nx <= 5 && 1 <= ny <= 5
                @inbounds layout[ny, nx] = idx
            end
        end
    end
    
    # --- コンソールへの整形出力 ---
    println("=== ミノ配置レイアウト ===")
    println("   x: 1  2  3  4  5")
    println("y  ----------------")
    for r in 1:5
        @printf("%d | ", r)
        for c in 1:5
            val = layout[r, c]
            if val == 0
                print(" . ")  # 何もないマス
            else
                @printf(" %d ", val)  # ミノ番号（1〜7）
            end
        end
        println()
    end
    println("==========================")
end

# 1次審査の結果を格納する軽量な構造体
struct EvaluatedState
    state::UInt64
    laser_score::Float64
    mino_count::Int
end

"""
レーザー影響度の高い順にソートし、第一段階の評価中に真解(true_state)を特定しながら
効率的にステージ全体の難易度を計算する関数
"""
function evaluate_stage_difficulty(
    states::Vector{UInt64}, 
    minosdata::Vector{Tuple{CellData, CellData, CellData}}, 
    start_pos1::Point, start_pos2::Point,  # スタート位置2つ
    goal_pos1::Point, goal_pos2::Point     # ゴール位置2つ
    )
    
    num_nodes = length(states)
    
    # 1次審査の結果を格納する配列
    candidates = Vector{EvaluatedState}()
    sizehint!(candidates, num_nodes)
    
    # 第一段階の評価中に発見・確定させる正解の状態を保持する変数
    true_state = nothing
    
    println("【1次審査】全盤面のレーザー評価を開始...")
    for i in 1:num_nodes
        st = states[i]
        
        # 1. ミノの配置数をその場で超高速にカウント
        placed_pieces = 0
        for p_idx in 1:MINO_COUNT
            if ((st >> ((p_idx - 1) * 6)) & PIECE_MASK) != 0
                placed_pieces += 1
            end
        end
        
        # 2. レーザーのシミュレーションを実行し、スコアを計算
        # ここで start_pos や goal_pos を使って光線を追跡します
        # 完全にクリア条件を満たしている（真解である）場合、関数内でそれを検知できるようにします
        laser_score, is_correct = simulate_laser_score_and_check(
            st, minosdata, start_pos1, start_pos2, goal_pos1, goal_pos2
        )
        
        # もしこれが完全な正解盤面なら、true_stateとして記録
        if is_correct
            true_state = st
        end
        
        push!(candidates, EvaluatedState(st, laser_score, placed_pieces))
    end
    
    # 万が一、全状態の中にクリア条件を満たすものがなかった場合のガード
    if true_state === nothing
        println("エラー: クリア条件を満たす正解盤面(true_state)が見つかりませんでした。")
        return 0.0
    end
    
    # 3. 【高速化の肝】レーザーのスコアが高い順（人間を騙せる順）にソート
    sort!(candidates, by = x -> x.laser_score, rev = true)
    
    println("【2次審査】上位ノードから順にミノ距離を計算中... (確定した正解: ", string(true_state, base=16), ")")
    
    max_trap_depth = 0.0
    trap_volume = 0
    
    # 上位の危険なノードから順にスキャン
    for cand in candidates
        # 早期打ち切り：レーザーがヘロヘロで誰も騙されない領域に入ったら終了
        if cand.laser_score < 0.4
            break
        end
        
        # 確定した true_state を使って、1次審査で数え済みの count と共にコスト計算
        d_mino = compute_mino_distance_with_count(cand.state, true_state, cand.mino_count)
        prox_mino = 1.0 / (1.0 + d_mino)
        
        # 罠度（ローカルミニマ度）の計算
        f_s = cand.laser_score * (1.0 - prox_mino)
        
        # 統計量の更新
        if f_s > max_trap_depth
            max_trap_depth = f_s
        end
        if f_s > 0.7
            trap_volume += 1
        end
    end
    
    # 最終的なステージ難易度 D の算出
    stage_difficulty = max_trap_depth * log(trap_volume + 1)
    
    println("=== 難易度評価完了 ===")
    println("最高罠深度 (Max Depth): ", max_trap_depth)
    println("危険領域の広さ (Trap Volume): ", trap_volume)
    println("ステージ総合難易度: ", stage_difficulty)
    
    return stage_difficulty
end

#=

    それ、**アルゴリズムの効率化としてめちゃくちゃ賢いアプローチ**です！

    グラフをすべて真面目に生成・探索しようとすると、7ピースのときに6万ノードや50万ノードという壁にぶち当たって処理が激重になります。
    しかし、そのアプローチなら「レーザーのシミュレーション」という**盤面単体で完結する超高速なスコア計算**をフィルターにして、調べるべき盤面（罠の容疑者）を最初から強烈に絞り込むことができますね。

    この「上から順に調べていく」効率的な評価プロセスを数理モデルとして綺麗に整理してみました。

    ---

    ## 効率的なステージ難易度評価アルゴリズムの方針

    全状態を網羅するのではなく、「レーザーが正解に近い盤面（容疑者リスト）」をハイスコア順にソートし、上から順にミノの距離をチェックしていくことで、計算コストを最小限に抑えつつ難易度を弾き出します。

    ### 【手順1】レーザー評価による高速フィルタリング（1次審査）

    まず、ランダム生成（または簡単なビームサーチ等でサンプリング）した盤面群、あるいは各ノードに対して、**レーザーのシミュレーション（$Prox_{\text{laser}}$）だけ**を全件計算します。

    * レーザーの追跡はビット演算や配列参照だけで一瞬で終わるため、1万〜10万件あっても一瞬です。
    * 計算したら、**$Prox_{\text{laser}}$ が高い順（例: 0.7以上、あるいはTop 1000件など）に盤面をソート**します。

    ### 【手順2】Top層から「ミノの距離（配置的近さ）」を計算（2次審査）

    レーザーの成績が優秀な（＝人間を騙す能力が高い）盤面の上位から順に、正解盤面との「ミノの配置的近さ（$Prox_{\text{mino}}$）」を計算していきます。

    ここで、各盤面の **「罠度スコア $f(s)$」** を計算します。


    $$f(s) = Prox_{\text{laser}}(s) \times (1.0 - Prox_{\text{mino}}(s))$$

    ### 【手順3】難易度 $D$ の集計（打ち切り最適化も可能）

    ソートされた上位を調べていくと、以下のように自動的に難易度の指標が手に入ります。

    1. **罠の最大深度（$D_{\text{max}}$）：**
    上位をスキャンしていく中で、最も高い $f(s)$ を記録した値。これが「そのステージの最高の騙し問題」のクオリティです。
    2. **罠の広さ（$D_{\text{volume}}$）：**
    レーザーのスコアが上から落ちていく中で、最終的に $f(s)$ が一定基準を超える盤面がどれくらい密集していたかのカウント。

    > **★さらに高速化するアイデア（早期打ち切り）：**
    > レーザーのスコアが一定（例：0.4以下）まで落ちてきたら、そこから下はミノの配置がどうあれ「そもそもレーザーがヘロヘロで誰も騙されない盤面」なので、**ミノの距離計算をその時点で打ち切って（breakして）終了**できます。これにより、無駄な計算を極限まで削れます。

    ---

    ## この方針の最大の強み

    この方法が素晴らしいのは、先ほど作ったあの恐ろしい「毛玉グラフ」や「巨大な隣接行列」の**右上のエリア（終盤・全配置付近の難所）だけをピンポイントでスナイプして採点できる点**です。

    レーザーの形が正解に似ているということは、自動的に「ゴールに近いレイヤー（最大配置付近）」の状態が集まるため、中盤の広大で無駄な自由空間（あの行列の真ん中の巨大な邪眼エリア）を完全に無視してスキップできます。

    ---

    思考が完全に「いかに軽く、スマートに難易度を測るか」という実用的な最適化に向いていて素晴らしいと思います。

    まずはこの方針に沿って、「ある盤面 $s$ のレーザー軌道が、正解の軌道（$T_{\text{laser}}$）と何マス重なっているか」を判定する、**1次審査用の軽量なレーザー合流度計算関数**の作成に進んでみるのはいかがでしょうか？

=#

# 盤面内（1〜5）の判定
@inline function is_inside_grid(x::Int, y::Int)::Bool
    return 1 <= x <= 5 && 1 <= y <= 5
end

"""
壁の座標(x, y)から、盤面の内側に向かう初期方向 Tuple{Int8, Int8} を自動判定する
"""
@inline function determine_start_dir(x::Int, y::Int)::Tuple{Int, Int}
    if x == 0      return ( 1,  0) # 右向き
    elseif x == 6  return (-1,  0) # 左向き
    elseif y == 0  return ( 0,  1) # 下向き
    else           return ( 0, -1) # 上向き (y == 6)
    end
end

"""
1つの状態(state)に対してレーザーをシミュレートし、
プレイヤーの感じる「手応えスコア」と「完全正解フラグ」を返す関数
"""
function simulate_laser_score_and_check(
    state::UInt64, 
    minosdata::Vector{Tuple{CellData, CellData, CellData}},
    grid::Matrix{Int8}, # 毎回「無」をもらっておく(5×5)
    start_pos1::Tuple{Int, Int}, # (x, y) ※壁の座標
    start_pos2::Tuple{Int, Int}, 
    goal_pos1::Tuple{Int, Int},  # (x, y) ※壁の座標
    goal_pos2::Tuple{Int, Int}
    )::Tuple{Float64, Int, Bool, UInt32}
    
    # 1. 42ビット状態を 5x5 Matrix{Int8} にデコード
    # grid[y, x] には CELL_SLASH(3), CELL_BACKS(4), または CELL_MINO(8) が入る
    #grid = decode_state_to_matrix(state, minosdata)
    mino_number = decode_state_to_matrix!(grid, state, minosdata)
    total_mino_cells = 3*mino_number

    # 盤面上の「すべてのミノのマス数」をカウント (3, 4, 8 はすべて3以上)
    # total_mino_cells = 0
    # for c in grid
    #     c >= Int8(3) && (total_mino_cells += 1)
    # end
    # total_mino_cells = count(x -> x >= 3, grid)
    
    # レーザーが通過したマスを記録する5x5のビットフラグ
    #visited_cells = falses(5,5)
    visited_cells = UInt32(0)
    
    # ゴール到達フラグ
    g1_reached = false
    g2_reached = false
    
    # 生存ステップ数（2つのレーザーの合計値）
    total_steps = 0
    
    # --- レーザーのシミュレーション（2系統分） ---
    starts = (start_pos1, start_pos2)
    goals = (goal_pos1, goal_pos2)
    
    for laser_idx in 1:2
        st_x, st_y = starts[laser_idx]
        gl_x, gl_y = goals[laser_idx]
        
        # スタート座標から自動的に初期方向(dx, dy)を決定
        move_dir = determine_start_dir(st_x, st_y)
        
        # スタートは壁(0か6)なので、まずは一歩進めて盤面(1〜5)に進入させる
        curr_x = st_x + move_dir[1]
        curr_y = st_y + move_dir[2]
        
        steps = 0
        for _ in 1:50
            # 盤面外（壁）に出たら終了判定
            if !is_inside_grid(curr_x, curr_y)
                # 飛び出た先の壁の座標が、指定されたゴール座標と完全一致すればゴール！
                if curr_x == gl_x && curr_y == gl_y
                    if laser_idx == 1
                        g1_reached = true
                    elseif laser_idx == 2
                        g2_reached = true
                    end
                end
                break
            end
            
            # 通過した盤面マスを記録
            #@inbounds visited_cells[curr_y, curr_x] = true
            visited_cells |= UInt32(1) << ((curr_y - 1) * 5 + (curr_x - 1))
            steps += 1
            total_steps += 1
            
            # 現在のマスにあるオブジェクトを取得
            @inbounds mirror = grid[curr_y, curr_x]
            
            # CELL_SLASH(3) または CELL_BACKS(4) の時だけ反射
            if mirror == CELL_SLASH || mirror == CELL_BACKS
                # Tuple{Int8, Int8} を直接受け取って直接返すオーバーロード版を叩く
                move_dir = reflect_dir(move_dir, mirror)
            end
            
            # 次のマスへ前進
            curr_x += move_dir[1]
            curr_y += move_dir[2]
        end
    end
    

    # [[[ --- 各スコアの計算 --- ]]]
    
    # --- ① 発光率 (s_light) の計算 ＆ 盤面ビットボード (u_board) の構築 ---
    lit_mino_cells = 0
    u_board = UInt32(0) # ループの手前で初期化

    for r in 1:5, c in 1:5
        # 1つ目のif: そのマスにミノが存在するか？
        if grid[r, c] >= 3
            # ミノが存在するので、u_board の対応するビットを立てる
            shift_amount = ((r - 1) * 5 + (c - 1))
            u_board |= UInt32(1) << shift_amount
            
            # 2つ目のif: さらに、そのマスをレーザーが通過（発光）したか？
            if ((visited_cells >> shift_amount) & 1) == 1
                lit_mino_cells += 1
            end
        end
    end
    
    s_light = total_mino_cells > 0 ? (lit_mino_cells / total_mino_cells) : 0.0
    
    # ② ゴール達成スコア (S_goal)
    s_goal = 0.0
    if g1_reached && g2_reached
        s_goal = 1.0
    elseif g1_reached || g2_reached
        s_goal = 0.5
    end
    
    # ③ 生存ステップ数スコア (S_life)
    s_life = min(total_steps / 100, 1.0)
    
    # プレイヤーの「手応えスコア（騙されやすさ）」を統合
    laser_score = 0.5 * s_light + 0.2 * s_goal + 0.3 * s_life
    
    # --- 完全正解(is_correct)の厳密な判定 ---
    placed_pieces = 0
    for p_idx in 1:MINO_COUNT
        if ((state >> ((p_idx - 1) * 6)) & PIECE_MASK) != 0
            placed_pieces += 1
        end
    end
    
    is_correct = (g1_reached && g2_reached) && (placed_pieces == MINO_COUNT) && (s_light == 1.0)
    
    return laser_score, mino_number, is_correct, u_board
end


"""
正解状態(true_state)から逆向きに全空間へBFSを行い、すべての状態への本物の最短手数を一括計算する。
到達不能な場合は -1 のままとなる。
"""
function compute_all_mino_distances!(
    distances::Vector{Int},          # 出力: 各ノードの最短手数 (num_nodes)
    states::Vector{UInt64},
    boards::Vector{UInt32},          # 各ノードの盤面ビットボード
    state_to_id::Dict{UInt64, Int},  # 逆引き辞書
    true_state::UInt64,
    all_candidates::NTuple{MINO_COUNT, Vector{PlacementCandidate}}
    )

    num_nodes = length(states)
    fill!(distances, -1) # 未訪問は -1

    # 正解状態のIDを取得して初期化
    true_id = state_to_id[true_state]
    distances[true_id] = 0

    # BFS用のキュー
    queue = Vector{Int}()
    sizehint!(queue, num_nodes)
    push!(queue, true_id)   # 正解から逆にたどっていく
    
    head = 1

    while head <= lastindex(queue)
        u_id = queue[head]
        head += 1
        current_dist = distances[u_id]
        
        u_state = states[u_id]
        u_board = boards[u_id]

        # 各ピースに対して遷移を列挙
        for piece_idx in 1:MINO_COUNT
            state_shift = (piece_idx - 1) * 6
            state_removed = u_state & ~(PIECE_MASK << state_shift)
            
            p_bits = (u_state >> state_shift) & PIECE_MASK
            current_piece_board = UInt32(0)
            if p_bits != 0
                for cand in all_candidates[piece_idx]
                    if ((cand.state_mask >> state_shift) & PIECE_MASK) == p_bits
                        current_piece_board = cand.board_mask
                        break
                    end
                end
            end
            other_board = u_board & ~current_piece_board

            # 遷移パターン：別の場所（または持ち駒との往復）
            candidates = @inbounds all_candidates[piece_idx]
            for cand in candidates
                if (other_board & cand.board_mask) != 0
                    continue
                end
                
                next_state = state_removed | cand.state_mask
                if next_state == u_state
                    continue
                end
                
                # 実験結果より100%存在することが確定しているため直接引く
                @inbounds v_id = state_to_id[next_state]
                
                if distances[v_id] == -1
                    distances[v_id] = current_dist + 1
                    push!(queue, v_id)
                end
            end

            # パターン: 盤面上から「完全に持ち駒に戻す（回収）」という一手
            if p_bits != 0
                v_id = get(state_to_id, state_removed, 0)
                # 全件探索なので、存在する遷移先であれば足切りなしで進む
                if v_id != 0 && distances[v_id] == -1
                    distances[v_id] = current_dist + 1
                    push!(queue, v_id)
                end
            end
        end
    end
end


function evaluate_s(target_seed::Integer)
    puzzle = generate(target_seed)
    minosdata, starts, goals = minos_start_end(puzzle)
    
    start_pos1 = (starts[1].x, starts[1].y)
    start_pos2 = (starts[2].x, starts[2].y)
    goal_pos1  = (goals[1].x,  goals[1].y)
    goal_pos2  = (goals[2].x,  goals[2].y)
    
    # 1. 全状態列挙
    states, all_candidates = collect_all_states_bitboard(minosdata)
    num_nodes = length(states)

    state_to_id = Dict{UInt64, Int}()
    sizehint!(state_to_id, num_nodes)
    
    boards = Vector{UInt32}(undef, num_nodes)
    fill!(boards, 0)

    scores = Vector{EvaluatedState}(undef, num_nodes)
    correct_states = Vector{UInt64}()
    grid = Matrix{Int8}(undef, 5, 5)

    # 2. 【1次審査】全状態のレーザー評価
    for (i, s) in enumerate(states)
        state_to_id[s] = i
        fill!(grid, Int8(0))
        
        score, mino_number, is_correct, u_board = simulate_laser_score_and_check(s, minosdata, grid, start_pos1, start_pos2, goal_pos1, goal_pos2)
        
        scores[i] = EvaluatedState(s, score, mino_number)
        boards[i] = u_board

        if is_correct
            push!(correct_states, s)
        end
    end
    
    if isempty(correct_states)
        println("Error: no correct states")
        return
    end

    true_state = correct_states[1]
    true_id = state_to_id[true_state]
    
    # 3. 【2次審査】全空間の一括逆BFS（足切りなし）
    distances = Vector{Int}(undef, num_nodes)
    compute_all_mino_distances!(distances, states, boards, state_to_id, true_state, all_candidates)
    
    # =========================================================================
    # 4. 【新・数理モデルフェーズ】個別評価の滑らかな足し上げ
    # =========================================================================
    
    max_laser_score = scores[true_id].laser_score
    if max_laser_score == 0
        max_laser_score = 1
    end

    # 罠エネルギーの総和を保持する変数
    total_trap_energy = 0.0
    
    # 【感度パラメータ】
    # この値を大きくするほど、高スコアの罠状態（0.8~1.0）が爆発的に優遇されます。
    # 10.0 にすると、f(s)=0.9 の1ノード（e^9 ≒ 8103）が、f(s)=0.2 の1ノード（e^2 ≒ 7.3）の約1100倍重くなります。
    alpha = 10.0

    for i in 1:num_nodes
        if distances[i] == -1
            continue
        end
        
        # 個別状態の評価
        prox_mino = 1.0 / (1.0 + distances[i])
        prox_laser = Float64(scores[i].laser_score) / max_laser_score
        f_s = prox_laser * (1.0 - prox_mino)
        
        # ──【いい感じに足し上げる核心】──
        # 指数関数に通すことで、無害な低スコア状態の雑音を消し去り、本物の罠だけを増幅して足し上げる
        total_trap_energy += exp(alpha * f_s)
    end

    # 最後に対数（log）を取って現実的な難易度スケールに引き戻す
    # 誰も罠にハマらない（全ノード f(s) ≒ 0）のとき、D_stage ≒ 0 になるよう -1.0 して調整
    D_stage = log(total_trap_energy) / alpha

    # 5. 結果を出力
    # println("\n================ STAGE EVALUATION REPORT ================")
    # println(" 総状態数 (Total Nodes) : ", num_nodes)
    # println("---------------------------------------------------------")
    # println(" 🔥 ステージ難易度 (D_stage) : ", D_stage)
    # println("=========================================================\n")

    return D_stage, distances, correct_states, scores
end

