include("rating.jl")





# 各シードの出力結果をまとめて保持する構造体（データ管理を綺麗にするため）
struct StageEvaluationResult
    D_stage::Float64
    distances::Vector{Int}
    correct_states::Vector{UInt64}
    scores::Vector{EvaluatedState}
end

"""
20250101 から 20251231 までの1年分のシード（計365件）に対して
evaluate_s を実行し、すべての結果を Dict に格納して返す。
"""
function collect_one_year_data(year::Int)
    # 結果を格納する辞書 (Seed => 結果の構造体)
    year_results = Dict{Int, StageEvaluationResult}()
    sizehint!(year_results, 365)

    # 2025年の全日付を生成
    start_date = Date(year, 1, 1)
    end_date = Date(year, 12, 31)
    
    println("=== 1年分のデータ収集を開始します (year/01/01 〜 year/12/31) ===")
    
    # 経過時間測定用
    total_time = @elapsed begin
        for current_date in start_date:Day(1):end_date
            # 日付を YYYYMMDD 形式の整数に変換 (例: 20250101)
            seed_str = Dates.format(current_date, "yyyymmdd")
            seed = parse(Int, seed_str)
            
            # 各ステージの評価を実行（printを消したバージョン）
            # 1件あたり約800ms想定のため、約5分弱で完了します
            print("Processing Seed: $(seed) ... ")
            
            t = @elapsed begin
                D_stage, distances, correct_states, scores = evaluate_s(seed)
                
                # 構造体にまとめて辞書に保存
                year_results[seed] = StageEvaluationResult(
                    D_stage, 
                    distances, 
                    correct_states, 
                    scores
                )
            end
            
            println("Done! (D_stage = $(round(year_results[seed].D_stage, digits=4)), Time: $(round(t, digits=2))s)")
        end
    end
    
    println("=========================================================")
    println("🎉 全365日分のデータ収集が完了しました！")
    println("総所要時間: ", round(total_time / 60, digits=2), " 分")
    println("=========================================================")
    
    return year_results
end









"""
collect_one_year_data() で得られた結果辞書を読み込み、
難易度、状態数、正解数、罠の相関関係などを詳細にレポートする。
"""
function analyze_year_data(year_data::Dict{Int, StageEvaluationResult})
    if isempty(year_data)
        println("データが空です。")
        return
    end

    # 1. 配列へのデータ展開
    seeds = Int[]
    d_stages = Float64[]
    num_nodes_list = Int[]
    num_corrects_list = Int[]

    for (seed, res) in year_data
        push!(seeds, seed)
        push!(d_stages, res.D_stage)
        push!(num_nodes_list, length(res.distances))
        push!(num_corrects_list, length(res.correct_states))
    end

    total_days = length(seeds)

    # 2. 基本統計量の計算
    mean_d = mean(d_stages)
    median_d = median(d_stages)
    std_d = std(d_stages)
    max_d, max_idx = findmax(d_stages)
    min_d, min_idx = findmin(d_stages)

    max_seed = seeds[max_idx]
    min_seed = seeds[min_idx]

    println("\n=========================================================")
    println("📊 2025年パズル難易度データ・詳細分析レポート")
    println("=========================================================")
    println("【1. 全体難易度統計】")
    println("  分析対象日数   : ", total_days, " 日")
    println("  平均難易度     : ", round(mean_d, digits=4))
    println("  中央値難易度   : ", round(median_d, digits=4))
    println("  標準偏差(ばらつき): ", round(std_d, digits=4))
    println("  🔥 冠絶の超難関(Oni) : Seed ", max_seed, " (D_stage = ", round(max_d, digits=4), ")")
    println("  💧 驚天の最平易(Easy): Seed ", min_seed, " (D_stage = ", round(min_d, digits=4), ")")
    
    # 3. 難易度層の分布 (ティア分け)
    # スコアに基づき自動分類（基準値はデータを見て調整してください）
    tier_oni = count(x -> x >= mean_d + std_d, d_stages)
    tier_hard = count(x -> mean_d <= x < mean_d + std_d, d_stages)
    tier_normal = count(x -> mean_d - std_d <= x < mean_d, d_stages)
    tier_easy = count(x -> x < mean_d - std_d, d_stages)

    println("\n【2. 難易度帯の分布 (ティア)】")
    println("  👹 鬼 (Oni)   [μ+σ以上] : ", rpad(tier_oni, 4), "ステージ (", round(tier_oni/total_days*100, digits=1), "%)")
    println("  ⚖️ 難 (Hard)  [μ〜μ+σ]   : ", rpad(tier_hard, 4), "ステージ (", round(tier_hard/total_days*100, digits=1), "%)")
    println("  🌿 普通(Normal)[μ-σ〜μ]   : ", rpad(tier_normal, 4), "ステージ (", round(tier_normal/total_days*100, digits=1), "%)")
    println("  🐟 易 (Easy)  [μ-σ未満]  : ", rpad(tier_easy, 4), "ステージ (", round(tier_easy/total_days*100, digits=1), "%)")

    # 4. 相関分析 (簡略的なピアソン相関係数の計算)
    function correlation(x, y)
        mx, my = mean(x), mean(y)
        return sum((x .- mx) .* (y .- my)) / sqrt(sum((x .- mx).^2) * sum((y .- my).^2))
    end

    corr_nodes = correlation(num_nodes_list, d_stages)
    corr_corrects = correlation(num_corrects_list, d_stages)

    println("\n【3. 変数間の相関係数 (難易度 D_stage との相関)】")
    println("  ・総状態数(ノード数)との相関 : ", round(corr_nodes, digits=4))
    if corr_nodes > 0.5
        println("    👉 強い正の相関：盤面（選択肢）が広いほど、比例して難しくなる傾向です。")
    elseif corr_nodes > 0.2
        println("    👉 弱い正の相関：盤面の広さも影響しますが、それ以上に『罠の配置』が効いています。")
    else
        println("    👉 相関なし：盤面の広さと難易度は無関係。狭くても極悪なステージが存在します。")
    end

    println("  ・正解状態数(別解の数)との相関: ", round(corr_corrects, digits=4))
    if corr_corrects < -0.3
        println("    👉 負の相関：別解（ゴール）が多いステージほど、偶然クリアしやすく簡単になります。")
    else
        println("    👉 相関僅少：別解がいくらあろうとも、強力なローカルミニマが人間を吸い寄せています。")
    end

    # 5. 時系列・月別分析
    # 月ごとのスコアを分類するコンテナ
    monthly_scores = Dict{Int, Vector{Float64}}()
    for m in 1:12 monthly_scores[m] = Float64[] end

    for (seed, res) in year_data
        # seed (YYYYMMDD) から月を抽出
        month = div(mod(seed, 10000), 100)
        push!(monthly_scores[month], res.D_stage)
    end

    println("\n【4. 月別平均難易度の推移】")
    for m in 1:12
        m_mean = mean(monthly_scores[m])
        print("  $(lpad(m, 2))月: [")
        # 簡易テキストバーチャート表示
        bar_len = round(Int, max(0, (m_mean / max_d) * 20))
        print("█"^bar_len, " "^(20 - bar_len))
        println("] 平均 D = ", round(m_mean, digits=4))
    end

    println("\n【5. 難易度上位トップ5のステージ詳細】")
    # 難易度順にペアをソート
    sorted_pairs = sort(collect(year_data), by = x -> x.second.D_stage, rev = true)
    for rank in 1:min(5, total_days)
        s = sorted_pairs[rank].first
        r = sorted_pairs[rank].second
        max_dist = maximum(r.distances)
        println("  第 $(rank) 位: Seed $(s) | D_stage = $(round(r.D_stage, digits=4)) | 総状態数 = $(length(r.distances)) | 正解への最大手数 = $(max_dist)手")
    end
    println("=========================================================\n")

    # さらなるプロットや詳細分析用に、統計データをまとめた辞書を返却
    return Dict(
        "mean" => mean_d,
        "median" => median_d,
        "max_seed" => max_seed,
        "min_seed" => min_seed,
        "corr_nodes" => corr_nodes,
        "corr_corrects" => corr_corrects
    )
end

# 7.32GBの原因だった巨大配列を排除し、分析に必要な統計量だけを持つ軽量構造体
struct LightStageResult
    D_stage::Float64
    num_nodes::Int          # 総状態数
    num_corrects::Int       # 正解状態数
    max_distance::Int       # 正解への最大手数
    f_scores_summary::Vector{Float64} # 後述：分布を再現するためのサンプリング（任意）
end


"""
巨大な year_data から必要な統計情報だけを抽出し、
圧倒的に軽量なバイナリ形式で保存する。
"""
function save_year_data_light(year_data::Dict{Int, StageEvaluationResult}, filepath::String="puzzle_year_data_2025_light.jls")
    # 保存用に、軽量な構造体のDictへ変換する
    light_data = Dict{Int, LightStageResult}()
    sizehint!(light_data, length(year_data))

    for (seed, res) in year_data
        # 巨大配列から必要な統計量をその場で計算
        num_nodes = length(res.distances)
        num_corrects = length(res.correct_states)
        max_dist = maximum(res.distances)
        
        # 復元して再計算できるように、非ゼロの f_score から計算に必要な情報を抽出
        # （もし分析関数に元の f_scores の分布を精密に渡したい場合は、ここで必要な値だけ残す）
        
        light_data[seed] = LightStageResult(
            res.D_stage,
            num_nodes,
            num_corrects,
            max_dist,
            Float64[] # 今回の基本分析には配列は不要なので空で軽量化
        )
    end

    try
        open(filepath, "w") do io
            serialize(io, light_data)
        end
        println("💾 必要情報を絞り込んで軽量保存しました（爆速＆極小）: $filepath")
    catch e
        println("❌ 保存中にエラーが発生しました: ", e)
    end
end

save_year_data_light(year_data::Dict{Int, StageEvaluationResult}, year::Int) = save_year_data_light(year_data, "puzzle_year_data_$(year).jls")

"""
軽量化されたファイルからデータを読み込む。
"""
function load_year_data_light(filepath::String="puzzle_year_data_2025_light.jls")::Dict{Int, LightStageResult}
    if !isfile(filepath)
        error("❌ 指定されたファイルが見つかりません: $filepath")
    end
    
    open(filepath, "r") do io
        return deserialize(io)
    end
end


"""
軽量化されたデータ（Dict{Int, LightStageResult}）を読み込み、
高速に詳細分析レポートを出力する。
"""
function analyze_year_data_light(light_data::Dict{Int, LightStageResult})
    if isempty(light_data)
        println("データが空です。")
        return
    end

    seeds = Int[]
    d_stages = Float64[]
    num_nodes_list = Int[]
    num_corrects_list = Int[]
    max_dists_list = Int[]

    for (seed, res) in light_data
        push!(seeds, seed)
        push!(d_stages, res.D_stage)
        push!(num_nodes_list, res.num_nodes)
        push!(num_corrects_list, res.num_corrects)
        push!(max_dists_list, res.max_distance)
    end

    total_days = length(seeds)
    mean_d = mean(d_stages)
    median_d = median(d_stages)
    std_d = std(d_stages)
    max_d, max_idx = findmax(d_stages)
    min_d, min_idx = findmin(d_stages)

    println("\n=========================================================")
    println("📊 2025年パズル難易度データ・詳細分析レポート (軽量版データ)")
    println("=========================================================")
    println("【1. 全体難易度統計】")
    println("  分析対象日数   : ", total_days, " 日")
    println("  平均難易度     : ", round(mean_d, digits=4))
    println("  中央値難易度   : ", round(median_d, digits=4))
    println("  標準偏差(ばらつき): ", round(std_d, digits=4))
    println("  🔥 冠絶の超難関(Oni) : Seed ", seeds[max_idx], " (D_stage = ", round(max_d, digits=4), ")")
    println("  💧 驚天の最平易(Easy): Seed ", seeds[min_idx], " (D_stage = ", round(min_d, digits=4), ")")
    
    # ティア分布
    tier_oni = count(x -> x >= mean_d + std_d, d_stages)
    tier_hard = count(x -> mean_d <= x < mean_d + std_d, d_stages)
    tier_normal = count(x -> mean_d - std_d <= x < mean_d, d_stages)
    tier_easy = count(x -> x < mean_d - std_d, d_stages)

    println("\n【2. 難易度帯の分布 (ティア)】")
    println("  👹 鬼 (Oni)   : ", rpad(tier_oni, 4), "ステージ (", round(tier_oni/total_days*100, digits=1), "%)")
    println("  ⚖️ 難 (Hard)  : ", rpad(tier_hard, 4), "ステージ (", round(tier_hard/total_days*100, digits=1), "%)")
    println("  🌿 普通(Normal) : ", rpad(tier_normal, 4), "ステージ (", round(tier_normal/total_days*100, digits=1), "%)")
    println("  🐟 易 (Easy)  : ", rpad(tier_easy, 4), "ステージ (", round(tier_easy/total_days*100, digits=1), "%)")

    # 相関分析
    function correlation(x, y)
        mx, my = mean(x), mean(y)
        return sum((x .- mx) .* (y .- my)) / sqrt(sum((x .- mx).^2) * sum((y .- my).^2))
    end
    corr_nodes = correlation(num_nodes_list, d_stages)
    corr_corrects = correlation(num_corrects_list, d_stages)

    println("\n【3. 変数間の相関係数】")
    println("  ・総状態数(ノード数)との相関 : ", round(corr_nodes, digits=4))
    println("  ・正解状態数(別解の数)との相関: ", round(corr_corrects, digits=4))

    # 月別推移
    monthly_scores = Dict{Int, Vector{Float64}}()
    for m in 1:12 monthly_scores[m] = Float64[] end
    for (seed, res) in light_data
        month = div(mod(seed, 10000), 100)
        push!(monthly_scores[month], res.D_stage)
    end

    println("\n【4. 月別平均難易度の推移】")
    for m in 1:12
        m_mean = mean(monthly_scores[m])
        print("  $(lpad(m, 2))月: [")
        bar_len = round(Int, max(0, (m_mean / max_d) * 20))
        print("█"^bar_len, " "^(20 - bar_len))
        println("] 平均 D = ", round(m_mean, digits=4))
    end

    println("\n【5. 難易度上位トップ5のステージ詳細】")
    sorted_pairs = sort(collect(light_data), by = x -> x.second.D_stage, rev = true)
    for rank in 1:min(5, total_days)
        p = sorted_pairs[rank]
        println("  第 $(rank) 位: Seed $(p.first) | D_stage = $(round(p.second.D_stage, digits=4)) | 総状態数 = $(p.second.num_nodes) | 正解への最大手数 = $(p.second.max_distance)手")
    end
    println("=========================================================\n")
end


# for i in 1900:2026
#     A = collect_one_year_data(i)
#     save_year_data_light(A,i)
#     GC.gc()
# end

using Serialization
using Statistics
using Dates

"""
軽量化された127年分のJLSデータを一挙にロードし、
すべてのデータ（約46,000件）をフラットに並べて超高精度な統計分析を行う。
"""
function analyze_historical_puzzle_data(base_dir::String="puzzle_year_datas")
    target_years = 1900:2026
    
    # 1.48MBであれば、全データを1つのフラットな配列に結合しても数ミリ秒で処理可能です
    all_seeds = Int[]
    all_d_stages = Float64[]
    all_num_nodes = Int[]
    all_num_corrects = Int[]
    all_max_dists = Int[]
    
    # データの高速一括ロード
    for year in target_years
        filepath = joinpath(base_dir, "puzzle_year_data_$(year).jls")
        !isfile(filepath) && continue

        year_data = open(filepath, "r") do io
            deserialize(io)
        end

        for (seed, res) in year_data
            push!(all_seeds, seed)
            push!(all_d_stages, res.D_stage)
            push!(all_num_nodes, res.num_nodes)
            push!(all_num_corrects, res.num_corrects)
            push!(all_max_dists, res.max_distance)
        end
    end
    
    total_days = length(all_seeds)
    if total_days == 0
        println("❌ エラー: [$base_dir] 内に有効なデータがありません。")
        return
    end

    # 基本統計量の一発計算
    mean_d = mean(all_d_stages)
    median_d = median(all_d_stages)
    std_d = std(all_d_stages)
    max_d, max_idx = findmax(all_d_stages)
    min_d, min_idx = findmin(all_d_stages)

    println("=========================================================")
    println(" 📊 世紀を越えるパズルデータ超長期マクロ分析 (127年間一括)")
    println("=========================================================")
    println("  総解析日数       : ", total_days, " 日分")
    println("  全期間平均難易度  : ", round(mean_d, digits=4))
    println("  全期間中央値      : ", round(median_d, digits=4))
    println("  難易度の標準偏差  : ", round(std_d, digits=4))
    println("  🔥 世紀の最高難度 (Oni) : Seed ", all_seeds[max_idx], " (D_stage = ", round(max_d, digits=4), ")")
    println("  💧 世紀の最低難度 (Easy): Seed ", all_seeds[min_idx], " (D_stage = ", round(min_d, digits=4), ")")

    # ピアソン相関係数
    function correlation(x, y)
        mx, my = mean(x), mean(y)
        return sum((x .- mx) .* (y .- my)) / sqrt(sum((x .- mx).^2) * sum((y .- my).^2))
    end
    
    corr_nodes = correlation(all_num_nodes, all_d_stages)
    corr_corrects = correlation(all_num_corrects, all_d_stages)
    corr_max_dist = correlation(all_max_dists, all_d_stages)

    println("\n【相関係数の一覧 (サンプリング誤差なし)】")
    println("  ・総状態数（ノードの広さ）との相関 : ", round(corr_nodes, digits=4))
    println("  ・正解状態数（別解の多さ）との相関 : ", round(corr_corrects, digits=4))
    println("  ・正解への最大手数との相関       : ", round(corr_max_dist, digits=4))

    # 歴史的難関トップ5
    println("\n【127年の歴史における極悪パズル・トップ5】")
    top_indices = sortperm(all_d_stages, rev=true)[1:5]
    for (rank, idx) in enumerate(top_indices)
        println("  第 $(rank) 位: Seed $(all_seeds[idx]) | D_stage = $(round(all_d_stages[idx], digits=4)) | 総状態数 = $(all_num_nodes[idx]) | 最大手数 = $(all_max_dists[idx])手")
    end
    println("=========================================================\n")

    # 全データをフラットな名前付きタプルで返す（あとで Plots 等で可視化しやすいように）
    return (
        seeds = all_seeds,
        d_stages = all_d_stages,
        num_nodes = all_num_nodes,
        num_corrects = all_num_corrects,
        max_dists = all_max_dists
    )
end