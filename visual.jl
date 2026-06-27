
using Graphs
using GraphPlot
using Compose
using Colors
import Cairo

"""
指定された個数(target_count)のピースだけが配置されている部分グラフを可視化する関数
"""
function visualize_puzzle_subgraph(g::SimpleGraph, states::Vector{UInt64}, target_count::Int, filename="subgraph_$target_count.png")
    num_nodes = length(states)
    
    # 1. 各ノードのミノ配置数を計算し、対象となるノードのインデックスを抽出
    target_indices = Int[]
    for i in 1:num_nodes
        st = states[i]
        placed = 0
        for p_idx in 1:MINO_COUNT
            if ((st >> ((p_idx - 1) * 6)) & PIECE_MASK) != 0
                placed += 1
            end
        end
        
        if placed == target_count
            push!(target_indices, i)
        end
    end
    
    sub_num_nodes = length(target_indices)
    println("対象レイヤー ($target_count ピース配置) のノード数: $sub_num_nodes")
    
    if sub_num_nodes == 0
        println("指定されたピース数のノードが存在しません。")
        return
    end
    
    # 2. 対象ノードとその間のエッジだけで部分グラフ(induced subgraph)を作成
    # Graphs.induced_subgraph を使うと、指定した頂点集合とその間に張られているエッジを自動で切り出せます
    sub_g, vmap = induced_subgraph(g, target_indices)
    
    # --- 3. カラーパレットとサイズの設定 ---
    # レイヤーごとに一色に統一（例: 2ピース配置なら緑、など）
    cmap = [
        RGB(0.8, 0.8, 0.8), # 0: グレー
        RGB(0.2, 0.6, 0.9), # 1: 水色
        RGB(0.2, 0.8, 0.4), # 2: 緑
        RGB(0.9, 0.8, 0.2), # 3: 黄色
        RGB(0.9, 0.5, 0.1), # 4: オレンジ
    ]
    # 安全対策：インデックスが配列外にならないようにガード
    color_idx = clamp(target_count + 1, 1, length(cmap))
    fillcolors = fill(cmap[color_idx], sub_num_nodes)
    
    # ノード数に応じて見やすいサイズに調整
    base_size = 0.001 #sub_num_nodes > 1000 ? 0.003 : (sub_num_nodes > 100 ? 0.01 : 0.03)
    nsizes = fill(base_size, sub_num_nodes)
    
    # --- 4. グラフのレイアウトとプロット ---
    println("部分グラフのレイアウトを計算中...")
    p = gplot(sub_g, 
              #nodefillc=fillcolors, 
              nodesize=2, 
              layout=shell_layout)
    
    # --- 5. 画像ファイルとして保存 ---
    println("画像ファイル $(filename) に書き出し中...")
    if endswith(filename, ".png")
        draw(PNG(filename, 64cm, 64cm), p)
    elseif endswith(filename, ".pdf")
        draw(PDF(filename, 64cm, 64cm), p)
    end
    println("可視化が完了しました！")
end

#visualize_puzzle_subgraph(g, states,4)






using Graphs
using Plots

using Graphs
using Plots

"""
i個のピースが配置されている盤面（レイヤー）だけを抽出し、
その内部の遷移関係（隣接行列）をヒートマップとして保存する関数
"""
function visualize_layer_adjacency_matrix(g::SimpleGraph, states::Vector{UInt64}, target_count::Int, filename="layer_$(target_count)_heatmap.png")
    num_nodes = length(states)
    
    # 1. 指定されたピース数(target_count)のノードを抽出
    layer_node_indices = Int[]
    layer_states = UInt64[]
    
    for i in 1:num_nodes
        st = states[i]
        placed = 0
        for p_idx in 1:MINO_COUNT
            if ((st >> ((p_idx - 1) * 6)) & PIECE_MASK) != 0
                placed += 1
            end
        end
        
        if placed == target_count
            push!(layer_node_indices, i)
            push!(layer_states, st)
        end
    end
    
    sub_num_nodes = length(layer_node_indices)
    println("対象レイヤー ($target_count ピース配置) の総ノード数: $sub_num_nodes")
    
    if sub_num_nodes == 0
        println("指定されたピース数のノードが存在しません。")
        return
    end
    
    # 2. 状態のビットパターン（使っているピースの組み合わせ等）でソートして
    # 構造的なクラスターが見えやすくする
    sort_indices = sortperm(layer_states)
    
    # 古いノードIDから、このレイヤー内でのソート後の新しいインデックス(1 〜 sub_num_nodes)へのマップ
    # レイヤー外のノードは0にする
    inv_map = zeros(Int, num_nodes)
    for (new_idx, old_idx_in_layer) in enumerate(sort_indices)
        actual_node_id = layer_node_indices[old_idx_in_layer]
        inv_map[actual_node_id] = new_idx
    end
    
    # 3. エッジの抽出（両端のノードがどちらもこのレイヤーに属しているものだけ）
    xs = Int[]
    ys = Int[]
    
    for edge in edges(g)
        u_new = inv_map[src(edge)]
        v_new = inv_map[dst(edge)]
        
        # 両方のノードが指定レイヤー内の場合のみプロット
        if u_new > 0 && v_new > 0
            push!(xs, u_new); push!(ys, v_new)
            push!(xs, v_new); push!(ys, u_new)
        end
    end
    
    # 4. プロット
    # ノード数（ドット数）に応じてマーカーのサイズを調整
    m_size = sub_num_nodes > 1000 ? 0.2 : 5
    
    println("レイヤー $target_count の隣接行列を描画中...")
    p = scatter(xs, ys, 
        markersize=m_size, 
        markerstrokewidth=0,
        color=:black, 
        legend=false,
        aspect_ratio=:equal,
        xlims=(1, sub_num_nodes),
        ylims=(1, sub_num_nodes),
        title="Layer $target_count Adjacency Matrix (Size: $sub_num_nodes)",
        xlabel="Layer States (Sorted)",
        ylabel="Layer States (Sorted)",
        size=(800, 800)
    )
    
    # 画像として保存
    println("画像ファイル $(filename) に書き出し中...")
    savefig(p, filename);
    println("可視化が完了しました！")
end

#visualize_layer_adjacency_matrix(g, states, 1);

using Graphs
using Plots

"""
全状態をミノ配置数順にソートし、隣接行列をヒートマップ(PNG)として保存する関数
"""
function visualize_adjacency_matrix_heatmap(g::SimpleGraph, states::Vector{UInt64}, filename="adjacency_heatmap.png")
    num_nodes = length(states)
    println("隣接行列の解析中... (総ノード数: $num_nodes)")
    
    # 1. 各ノードのミノ配置数を計算
    node_counts = Vector{Int}(undef, num_nodes)
    for i in 1:num_nodes
        st = states[i]
        placed = 0
        for p_idx in 1:MINO_COUNT
            if ((st >> ((p_idx - 1) * 6)) & PIECE_MASK) != 0
                placed += 1
            end
        end
        node_counts[i] = placed
    end
    
    # 2. ミノ配置数が少ない順（0 -> 1 -> 2 -> ... -> MINO_COUNT）にノードを並び替えるインデックスを取得
    # これにより、行列の軸が配置数ごとに綺麗にグループ化されます
    sort_indices = sortperm(node_counts)
    
    # 3. ソートされた順序で隣接行列（SparseかDenseのフラグ配列）を構築
    # 1万超のサイズを密行列にするとメモリを喰うため、描画用にエッジのある座標(x, y)を抽出します
    xs = Int[]
    ys = Int[]
    
    # 古いノードIDから、ソート後の新しい行列インデックスへの逆引きマップ
    inv_map = Vector{Int}(undef, num_nodes)
    for (new_idx, old_idx) in enumerate(sort_indices)
        inv_map[old_idx] = new_idx
    end
    
    # エッジをスキャンして、ソート後の座標に変換
    for edge in edges(g)
        u_new = inv_map[src(edge)]
        v_new = inv_map[dst(edge)]
        
        # 対称行列なので両方プロット
        push!(xs, u_new); push!(ys, v_new)
        push!(xs, v_new); push!(ys, u_new)
    end
    
    # 4. 描画用に、配置数の境界線（グリッド）を描くための準備
    # 各ピース個数レイヤーがどこからどこまでを占めているかのインデックスを記録
    boundaries = Int[]
    current_cnt = 0
    for (idx, old_idx) in enumerate(sort_indices)
        if node_counts[old_idx] != current_cnt
            push!(boundaries, idx)
            current_cnt = node_counts[old_idx]
        end
    end
    
    # 5. Plots.scatter または heatmap 形式でプロット
    # 点数が多いため、scatterのドットを極限まで小さく(pixelサイズ)してプロットするのが最速かつ高精細です
    println("ヒートマップを描画中...")
    p = scatter(xs, ys, 
        markersize=0.1, 
        markerstrokewidth=0,
        color=:black, 
        legend=false,
        aspect_ratio=:equal,
        xlims=(1, num_nodes),
        ylims=(1, num_nodes),
        title="Puzzle State Transition Adjacency Matrix",
        xlabel="States (Sorted by Mino Count)",
        ylabel="States (Sorted by Mino Count)",
        size=(1000, 1000)
    )
    
    # 階層の境界線を赤い破線で引く
    vline!(p, boundaries, color=:red, linestyle=:dash, alpha=0.5)
    hline!(p, boundaries, color=:red, linestyle=:dash, alpha=0.5)
    
    # 画像として保存
    println("画像ファイル $(filename) に書き出し中...")
    savefig(p, filename)
    println("隣接行列の可視化が完了しました！")
end

#visualize_adjacency_matrix_heatmap(g, states)