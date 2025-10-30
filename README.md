# flowtype

macOS 向けの SwiftUI 製フォントブラウザです。システムにインストール済みのフォントを一覧化し、ファミリー名・表示名・PostScript 名で検索したり、等幅フォントだけに絞り込んで比較できます。

## 主な機能
- CoreText API を利用したフォントメタデータの収集と安定ソート
- ファミリー / 表示名 / PostScript 名によるインクリメンタル検索
- 等幅フォントのみ表示するトグル
- カード形式のプレビューと任意テキストのリアルタイム反映
- フォントのピン留めと比較ペインでの並列プレビュー
- PostScript 名のワンクリックコピーおよびピン留めフォント一覧の一括コピー

## 技術スタック
- Swift 5.x
- SwiftUI (NavigationSplitView, Grid, TextEditor など)
- CoreText / AppKit (フォント情報取得、クリップボード操作)

## 動作要件
- macOS 13 Ventura 以降 (推奨: 14 Sonoma 以上)
- Xcode 15 以降

## セットアップ
1. 本リポジトリをクローンします。
   ```bash
   git clone https://github.com/your-user/flowtype.git
   cd flowtype
   ```
2. `flowtype.xcodeproj` を Xcode で開き、ターゲット `flowtype` を選択します。
3. 任意のシミュレータまたはローカルの macOS 実機でビルド & 実行します。

## 使い方
- 左サイドバーで検索クエリや等幅フィルタ、サンプルテキスト、プレビューサイズを調整します。
- 中央のグリッドでプレビューカードを確認し、📌 ボタンでピン留めします。
- 右ペインではピン留めしたフォントを縦に並べて比較でき、コピー操作で PostScript 名やサンプルテキストを共有できます。

## テスト
- `flowtypeTests` および `flowtypeUITests` ターゲットがテンプレートとして用意されています。必要に応じて `swift-testing` や XCTest を使った検証コードを追加してください。

## プロジェクト構成
```
flowtype/
├─ flowtype/            # アプリ本体 (SwiftUI)
│  ├─ ContentView.swift
│  ├─ flowtypeApp.swift
│  └─ Assets.xcassets/
├─ flowtypeTests/       # 単体テスト (テンプレート)
└─ flowtypeUITests/     # UI テスト (テンプレート)
```

## ライセンス
現時点ではライセンスが明示されていません。必要に応じて `LICENSE` を追加してください。


