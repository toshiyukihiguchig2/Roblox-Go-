# Roblox-Go-
Robloxゲーム開発企画「Go!!!!」プロジェクト用の開発リポシトリー

### プロジェクトの目的
Roblox 上で動作するアクションゲーム「Go!!!!」の開発を行う。
Rojo を用いたコード管理、TestEZ による自動テスト、GitHub Actions による ビルド を導入し、
再現性の高い開発フローと品質管理の自動化を実現する。

### 使い方
- VSCode + Rojo を使って Roblox Studio とコードを同期しながら開発する
- src/ 以下に Lua コードを配置し、Rojo で game/ にマッピング
- TestEZ を使ってユニットテストを実行
- GitHub に push すると GitHub Actions により、Rojo が正しく動作しプロジェクトをビルドできることを自動で検証する

### セットアップ後の運用
- PowerShellを起動し、cloneしたリポジトリーへ移動しVSCodeを立ち上げる
<pre>
cd C:\Users\toshi\source\repos\Roblox-Go-
code .
</pre>
- VSCodeのコンソール（PowerShell）で Rojo を起動する
<pre>
rojo serve
</pre>
- Roblox Studio を起動し、セットアップ済みである制作中のバーチャル空間を選択する
- Roblox Studio のプラグインからRojoを開き「Connect」を押下する
- 開発を進める流れ
<pre>
1. src/ に本番コードを書く
2. src/tests/ に対応するテストを書く
3. Roblox Studio で Rojo で同期して動作確認
（1～3を繰り返し）
4. GitHub に push → CI が自動テスト（結果をGithubのアクションで確認）
</pre>

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
実行環境：VSCode

1. VSCode の左側でプロジェクトルートを右クリックし「新しいファイル」を選択
2. ファイル名「wally.toml」を入力して作成する
3. 次の内容を貼り付ける（TestEZ 導入用）
----
[package]
name = "GitHubのユーザー名/roblox-go"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
TestEZ = "roblox/testez@0.4.1"
----
※ name は GitHub のユーザー名に合わせて変更してOK
</pre>
- Wally を適用する
<pre>
　wally install　（　←　プロジェクト内に Packages/ フォルダが生成されれば OK ）
</pre>
8. TestEZ の実行
- default.project.json に Packages を追加する
<pre>
{
    "name": "Roblox-Go-",
    "tree": {
        "$className": "DataModel",
        "ReplicatedStorage": {
            "$className": "ReplicatedStorage",
            "Source": {
                "$path": "src"
            },
            "Packages": {
                "$path": "Packages"
            }
        }
    }
}
</pre>
- TestEZ のテストコードを書く準備（テストコードが機能するかの確認）
<pre>
実行環境：VSCode

・src/tests/ フォルダを作成する
・src/tests/example.spec.lua を作成する
・サンプルコードを記述し保存すると、Studio 側の ReplicatedStorage/Source/tests に同期される
  （サンプルコード）
  return function()
    describe("math", function()
        it("adds numbers", function()
            expect(1 + 1).to.equal(2)
        end)
    end)
  end
</pre>
- Roblox Studio で TestEZ を実行する
<pre>
実行環境：Roblox Studio

Rojo 接続中に Studio を開くと：
- ReplicatedStorage/Packages/TestEZ が存在する
- ReplicatedStorage/Source/tests にテストがある

この状態で、TestEZ の UI（TestEZ ランナー）を使ってテストを実行する
※TestEZ の UI がない場合は、次のコードを Command Bar で実行
  local TestEZ = require(game.ReplicatedStorage.Packages.TestEZ)
  local results = TestEZ.TestBootstrap:run({game.ReplicatedStorage.Source.tests})
  print(results)
</pre>
9. UI（TestEZ ランナー）の作成方法
<pre>
① VSCode の src/ に runner フォルダを作る
src/
 ├ tests/
 └ runner/
② src/runner/TestRunner.server.lua を作成
local TestEZ = require(game.ReplicatedStorage.Packages.TestEZ)
local results = TestEZ.TestBootstrap:run({
    game.ReplicatedStorage.Source.tests
}, TestEZ.Reporters.TextReporter)
print("===== TestEZ Finished =====")
③ Rojo の project.json に runner を追加
{
    "name": "Roblox-Go-",
    "tree": {
        "$className": "DataModel",
        "ReplicatedStorage": {
            "$className": "ReplicatedStorage",
            "Source": {
                "$path": "src"
            },
            "Packages": {
                "$path": "Packages"
            }
        },
        "ServerScriptService": {
            "$className": "ServerScriptService",
            "TestRunner": {
                "$path": "src/runner"
            }
        }
    }
}
④ Studio で TestEZ UI を確認
「プレイ」を押下する。（または「F5」キー）
「出力」にテスト実行結果を表示する
</pre>

### GitHub Actions の自動テスト（CI）を設定
- 全体像：GitHub Actions で TestEZ を動かす仕組み
<pre>
GitHub Actions は、 GitHub のサーバー上で TestEZ を実行する。
必要な構成は次の 3 つ。
　・Foreman（Roblox CLI のパッケージ管理）
 　・Wally（依存パッケージ管理）
 　・TestEZ を実行するコマンド
 これらを GitHub Actions の workflow に書くことで、push のたびに自動テストが走る
</pre>
前提：VSCodeでGitHub Actionsプラグインをインストール済みであること
1. プロジェクトに foreman.toml を追加する
<pre>
実行環境：VSCode

・VSCode のプロジェクトルートに foreman.toml を作成し、以下を記載する
----
[tools]
wally = { source = "UpliftGames/wally", version = "0.3.2" }
rojo = { source = "rojo-rbx/rojo", version = "7.6.1" }
----
※versionはwally、Rojoそれぞれのインストール時のversionを設定する
　分からない場合は PowerShell または VSCode のターミナルでコマンド確認する
  wally --version
  rojo --version 
</pre>
2. TestEZ を CLI で実行するためのスクリプトを追加する
<pre>
実行環境：VSCode

・VSCode のプロジェクトルートに test.project.json を作し、以下を記載する
----
{
    "name": "tests",
    "tree": {
        "$path": "src/tests"
    }
}
----
※これは GitHub Actions が TestEZ を実行するための「テスト専用の Rojo プロジェクト」
</pre>
3. GitHub Actions の workflow を追加
<details>
<summary>旧手順：問題点３つあるため改良　クリックして開く</summary>
・Parameter token or opts.auth is required
　→ Roblox/setup-foreman@v1 が壊れていた
・手動インストールに変更
　→ URLミス修正
・PATH問題
　→ $HOME/.foreman/bin を追加
<pre>
実行環境：VSCode

github/workflows/test.yml を作成し、下記を記載する
----
name: Test

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Install Foreman
        uses: Roblox/setup-foreman@v1

      - name: Install tools
        run: foreman install

      - name: Install Wally packages
        run: wally install

      - name: Run tests
        run: rojo test test.project.json
----
</pre>
</details>
<pre>
実行環境：VSCode

github/workflows/test.yml を作成し、下記を記載する
----
name: Test

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install Foreman
        run: |
          curl -L https://github.com/Roblox/foreman/releases/latest/download/foreman-linux-x86_64.zip -o foreman.zip
          unzip foreman.zip
          chmod +x foreman
          sudo mv foreman /usr/local/bin/

      - name: Install tools
        run: foreman install

      - name: Add Foreman tools to PATH
        run: echo "$HOME/.foreman/bin" >> $GITHUB_PATH

      - name: Install Wally packages
        run: wally install

      - name: Build place
        run: rojo build test.project.json -o test.rbxl
----
</pre>
4. push すると GitHub Actions が自動で動く
<pre>
GitHub に push すると：
- Actions タブに「Test」ジョブが走る
- TestEZ が自動で実行される
- 成功・失敗が GitHub 上で確認できる
</pre>

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

### 注意点
- .rbxl や .rbxm などのバイナリファイルは Git に含めない
- src/ 以下のコードが開発の中心
- Rojo のマッピング設定（default.project.json）を変更した場合は共有必須
- GitHub Actions の設定ファイル（.github/workflows/）は削除しない
- テストコードは tests/ に配置する

----

### LICENSE
“This project is licensed under the MIT License.”
