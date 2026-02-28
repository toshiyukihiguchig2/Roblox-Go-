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
実行環境：PowerShell

cd C:\Users\ユーザー名\source\repos　（　←　clone先のフォルダ構成のおすすめ）
git clone https://github.com/ユーザー名/Roblox-Go-.git
cd Roblox-Go-
</pre>
2. Rojo のインストール
<pre>
実行環境：PowerShell

cargo install rojo

または

Rojo の公式リリースからバイナリをダウンロード。　（　←　Windowsならこっちが安定）
・Rojo の公式リリースページを開く（https://github.com/rojo-rbx/rojo/releases）
・最新版の Assets を開く
  例）rojo-7.7.0-rc.1-windows-x86_64.zip
・zip をダウンロードして解凍
・中にある rojo.exe を「C:\Users\ユーザー名\AppData\Local\Programs\Rojo」のようなフォルダに置く（　←　フォルダは自分で作って OK）
・そのフォルダを PATH に追加
　・Windowsキー →「環境変数」→「環境変数の編集」
　・「Path」を選択 →「編集」
　・C:\Users\ユーザー名\AppData\Local\Programs\Rojo を追加
・PowerShellを別窓で開いて下記コマンドを実行
  rojo --version　（　←　バージョンが表示されれば OK）
</pre>
3. VSCode のセットアップ
- VSCodeの起動について
<pre>
実行環境：PowerShell

cd C:\Users\ユーザー名\source\repos
</pre>
- Rojo 拡張機能をインストール
- Luau Language Server をインストール
4. Rojo プロジェクトを起動
<pre>
実行環境：VSCode（ターミナル）

・下記コマンドを実行して Rojo を起動する
　rojo serve　（　←　「Rojo server listening on port 34872」こんな感じのがでれば OK）
</pre>
5. Roblox Studio で Rojo プラグインに接続
- Roblox Studio に Rojo プラグインをインストールする手順
<pre>
・Roblox Studio を開く
・上部メニューの Plugins（プラグイン） をクリック
・Manage Plugins（プラグイン管理） を開く
・右上の 「Find Plugins（プラグインを探す）」または「＋」をクリック
・ツールボックスの検索欄に Rojo と入力
・Rojo（公式） を選んで「Install（インストール）」
・インストール後、Studio の中央の Plugins（プラグイン）をクリック
・ほかのプラグインと並んで Rojo ボタンが表示される
</pre>
- Rojo プラグインの動作確認
<pre>
VSCode 側で rojo serve が動いている状態で、Studio の Rojo ボタンを押すと：
・Rojo の窓が開き
・ポート番号 34872 が表示される（自動）
・Connectをクリック　（　←　VSCode の src/ が Studio の ReplicatedStorage/Source に同期される。）
  ※ Roblox Studio のRojoプラグインと VSCode で参照している Rojo CI のバージョンが一致しないと接続できない。
  　その場合は、どちらかのバージョンをアップグレードもしくはダウングレードする必要あり。
</pre>
6. Rojo 接続後の開発フロー
- Rojo を使う場合、Roblox Studio 側でスクリプトを作らないのが基本になる。
<pre>
開発フロー：
- VSCode の src/ に Lua ファイルを作る
- Rojo が自動で Studio に同期する
- Studio 側では動作確認だけ行う
- 修正は VSCode 側で行う
- GitHub に push してバージョン管理する
　※Studio 側でスクリプトを直接編集すると、Rojo の同期で上書きされてしまうため、VSCode 側が唯一の編集場所になる。
</pre>
7. TestEZ の構築
- Wally で TestEZ を導入する
<pre>
実行環境：PowerShell または VSCode のターミナル

1. Wally をインストールする（ブラウザで直接ダウンロードする方法　おすすめ）
　・URL をブラウザで開く（https://github.com/UpliftGames/wally/releases/latest）
  ・ページ内の Assets にある「wally-windows.exe」をクリック 
　・zip をダウンロードして解凍
　・中にある wally.exe を「C:\Users\ユーザー名\AppData\Local\Programs\Wally」のようなフォルダに置く（　←　フォルダは自分で作って OK）
2. wally.exe を PATH へ通す
　・Windowsキー →「環境変数」→「環境変数の編集」
　・「Path」を選択 →「編集」
　・C:\Users\ユーザー名\AppData\Local\Programs\Wally を追加
3. PowerShellを開き疎通を確認する
  wally --version
</pre>
- プロジェクトに wally.toml を作成する
<pre>

</pre>
8. TestEZ の実行
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
