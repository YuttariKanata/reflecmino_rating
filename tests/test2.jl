# テスト用スクリプト: test_difficulty.jl
include("./test1.jl")

# --- 1. テストデータの構築 ---

# ピース定義（ offsets, mirrors ）
# ピース1: L字型、端に / 鏡、残りは空白
p1 = Polyomino3(" \\/",(0,0), (1,0), (1,1))
p2 = Polyomino3( "/\\ ",(0,0), (0,1), (1,1))
p3 = Polyomino3( " / " ,(0,0), (1,0), (1,1))
p4 = Polyomino3( "\\/ ",(1,0), (1,1), (0,1))
p5 = Polyomino3(" \\\\",(0,0), (0,1), (1,0))
p6 = Polyomino3("  /"  ,(0,0), (0,1), (1,0))
p7 = Polyomino3("//\\" ,(0,0), (0,1), (1,0))
# ピースの束縛 (4ピースなので N=4)
test_pieces = (p1, p2, p3, p4, p5, p6, p7)

# ポート配置定義
# 射出口 (r, c, 進入方向) -> 盤面外から1マス目へ入る設定
# 例: (1, 1) から下へ進む、(5, 3) から上へ進む、など
orange_start = LaserPort(5, 4, DIR_UP)
blue_start   = LaserPort(2, 1, DIR_RIGHT)

# 射入口 (r, c, 出ていく方向) -> この座標から一歩外に出たらゴール
in_port_1    = LaserPort(4, 1, DIR_LEFT)   # (5,2)の下の壁から脱出できればゴール
in_port_2    = LaserPort(5, 2, DIR_DOWN) # (3,5)の右の壁から脱出できればゴール

# ステージ問題インスタンスの生成
prob = StageProblem{length(test_pieces)}(orange_start, blue_start, in_port_1, in_port_2, test_pieces)

# --- 2. 実行と検証 ---

println("=== パズル難易度解析エンジン テスト走行 ===")
println("総ピース数: ", length(prob.pieces))

# 全探索の実行とデータ回収
initial_board = BoardState(0, 0)
current_placements = [Placement(false, 0, 0) for _ in 1:length(test_pieces)]
ctx = SearchContext(prob, StateData[], [Placement(false, 0, 0) for _ in 1:length(test_pieces)])

# パス1: 真の解を特定
find_true_solution!(1, initial_board, current_placements, ctx)

# 正解が見つかったか確認
has_solution = any(p -> p.is_placed, ctx.true_placements)
if !has_solution
    println("[警告] 与えられたポートとピースの設定では、条件を満たす『真の解』が見つかりませんでした。")
    println("※適当に組んだテストデータのため幾何学的に詰んでいる可能性があります。")
    println("ただし、擬似解（ニアミス）の回収テストとしてそのまま走らせます。")
else
    println("[成功] 真の解を検出しました。")
end

# パス2: 全状態の回収
collect_states_data!(1, initial_board, current_placements, ctx)

println("探索された有効な配置（重なりなし）の総数: ", length(ctx.states_data))

# 特徴量の分布を簡単に集計
n_lasers_2 = count(st -> st.lasers_cleared == 2, ctx.states_data)
n_full_cover = count(st -> st.coverage_rate == Float32(1.0), ctx.states_data)
n_near_miss = count(st -> st.lasers_cleared == 2 && st.coverage_rate > Float32(0.0) && st.coverage_rate < Float32(1.0), ctx.states_data)

println("  └ レーザーが2本とも開通した配置数: ", n_lasers_2)
println("  └ ピース全マスをカバーした配置数  : ", n_full_cover)
println("  └ プレイヤーを惑わせるニアミス数(トラップ): ", n_near_miss)

# 難易度点数の計算
difficulty_score = evaluate_difficulty(ctx.states_data; beta=Float32(2.0))
println("\n算出された認知エントロピー（難易度点数）: ", difficulty_score)

# 真の解の配置を表示
print_true_solution(ctx)

# 難易度の数式的内訳を詳細表示
print_difficulty_math_analysis(ctx.states_data; beta=Float32(2.0))