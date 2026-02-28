# Roblox-Go-
Robloxゲーム開発企画「Go!!!!」プロジェクト用の開発リポシトリー

### プロジェクトの目的
Roblox 上で動作するアクションゲーム「Go!!!!」の開発を行う。
Rojo を用いたコード管理、TestEZ による自動テスト、GitHub Actions による CI を導入し、
再現性の高い開発フローと品質管理の自動化を実現する。

### 使い方
- VSCode + Rojo を使って Roblox Studio とコードを同期しながら開発する
- src/ 以下に Lua コードを配置し、Rojo で game/ にマッピング
- TestEZ を使ってユニットテストを実行
- GitHub に push すると GitHub Actions が自動でテストを実行

### 開発環境（Rojo / VSCode / TestEZ など）
- Roblox Studio
- VSCode
- 拡張機能：Rojo、Luau Language Server
- Rojo
- TestEZ
- Git / GitHub
- GitHub Actions（CI）

----

### セットアップ手順
1. リポジトリを clone
<pre>
cd C:\Users\ユーザー名\source\repos　（　←　clone先のフォルダ構成のおすすめ）
git clone https://github.com/ユーザー名/Roblox-Go-.git
cd Roblox-Go-
</pre>
2. Rojo のインストール
<pre>
cargo install rojo
または
Rojo の公式リリースからバイナリをダウンロード。
</pre>
3. VSCode のセットアップ
- Rojo 拡張機能をインストール
- Luau Language Server をインストール
4. Rojo プロジェクトを起動
<pre>
rojo serve
</pre>
5. TestEZ の実行
<pre>
wally install
wally run test
</pre>

### 注意点
- .rbxl や .rbxm などのバイナリファイルは Git に含めない
- src/ 以下のコードが開発の中心
- Rojo のマッピング設定（default.project.json）を変更した場合は共有必須
- GitHub Actions の設定ファイル（.github/workflows/）は削除しない
- テストコードは tests/ に配置する

----

### .gitignoreについて
Roblox のバイナリを完全に除外
- .rbxl や .rbxm は Git に入れるとリポジトリが壊れるため。
- 差分が取れず、容量も巨大になるため 絶対に除外すべき。

Rojo の出力フォルダを除外
- Rojo の out/ や build/ は生成物なので Git に入れない。

VSCode の個人設定を除外
- .vscode/ は個人の環境依存なので、チーム開発や学校提出で問題になる。

Wally / Node などの依存ファイルを除外
- 依存関係は Git に入れず、wally install や npm install で再構築する。

CI（GitHub Actions）で不要なファイルを除外
- coverage などの一時ファイルは Git に入れない。

----

### LICENSE
“This project is licensed under the MIT License.”
