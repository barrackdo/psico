# PSICO

## 概要
PowerShell スクリプトの統合・制御・整理を目的とした CLI ツールです。開発用ディレクトリと実行用ディレクトリを分離し、ユーザーが簡単にスクリプトを管理・実行できます。

## 主な機能
- スクリプトのインストール、削除、編集、一覧表示、検索
- スクリプトの実行、テスト、初期化
- ゾーン識別子 (Zone Identifier) の自動解除
- スクリプトのメタ情報 (バージョン、説明、タグ、引数) の管理
- ログ出力機能 (ログレベル 0-2)
- スクリプトのテスト実行

## インストール

### 簡単インストール
PowerShell の一行コマンドでインストールできます。
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://github.com/barrackdo/psico/raw/main/install.ps1 | iex"
```
※ インストール先は `%UserProfile%\psico` となります。

### 手動インストール
1. `PSICO` ディレクトリを作成
2. `psico.ps1` と `core\psico_core.ps1` を同ディレクトリにコピー
3. PowerShell のプロファイル (`$PROFILE`) に以下を追加し、再読み込み (`. $PROFILE`)
   - `<PSICO ディレクトリ>` は環境に合わせて適宜修正してください

```powershell
function psico {
    & "<PSICO ディレクトリ>\psico.ps1" @args
}
Set-Alias psico psico
```

## 使用方法
- `psico --help` でヘルプ表示
- `psico --init` で初期化 (ディレクトリ構成と設定ファイル作成)
- `psico --list` で利用可能なスクリプトの一覧表示
- `psico --add <name> "<description>"` で新規スクリプトを作成
  - 例: `psico --add myScript "My useful script"`
- `psico --list` でスクリプト一覧を表示

### スクリプト作成から実行までの一連の操作例

```powershell
# 1. 初期化 (初回のみ)
psico --init

# 2. 新しいスクリプトを作成 (例: hello.ps1)
psico --add hello "挨拶を表示するスクリプト"

# 3. 作成されたスクリプトを確認
psico --list

# 4. スクリプトの詳細情報を確認
psico --info hello

# 5. スクリプトをテスト実行
psico --test hello

# 6. 通常実行 (引数なしで実行)
psico hello

# 7. スクリプトを編集
psico --edit hello

# 8. 編集後の再実行
psico hello
```

## 主なコマンド
- `--init` : 初期化 (ディレクトリ構成と設定ファイル作成)
- `--list` : スクリプト一覧表示
- `--add <name> "<description>"` : 新規スクリプト作成
- `--remove <name>` : スクリプト削除
- `--edit <name>` : スクリプト編集
- `--search <pattern>` : スクリプト検索
- `--info <name>` : スクリプトメタ情報表示
- `--test <name>` : スクリプトテスト実行
- `--log <level>` : ログレベル設定 (0-2, -1 でログ削除)

## 主な機能詳細
- ゾーン識別子 (Zone Identifier) の即時解除
- スクリプトのメタ情報 (バージョン、説明、タグ、引数) の管理
- ログ出力 (ログレベル 0-2) とログファイルの自動作成
- スクリプトのテスト実行 (`--test`)

## ライセンス
MIT License
