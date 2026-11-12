# PSICO
https://github.com/barrackdo/psico

## 概要
PowerShell スクリプトの統合・制御・整理を目的とした CLI ツールです。

## 主な機能
- スクリプトのインストール、削除、編集、一覧表示、検索
- スクリプトの実行、テスト、初期化
- スクリプトのメタ情報 (バージョン、説明、タグ、引数) の管理
- ログ出力機能 (ログレベル 0-2)

## インストール

### 簡単インストール
PowerShell で以下のコマンドを実行してください。
```powershell
irm https://github.com/barrackdo/psico/raw/main/install.ps1 | iex
```
※ インストール先は `%LocalAppData%\psico` となります。

### 手動インストール
1. `psico` ディレクトリを作成
2. `psico.ps1` と `core\*.ps1` を同ディレクトリの適切な位置にコピー

### プロファイルへの登録
インストールの完了後にプロファイルへ関数を手動で書き込むと `psico` コマンドとして簡単に使えるようになります。
- PowerShell のプロファイル (`$PROFILE`) に以下を追加し、再読み込み (`. $PROFILE`)
   - `<PSICO ディレクトリ>` は環境に合わせて適宜修正してください

```powershell
function psico {
    & "<PSICO ディレクトリ>\psico.ps1" @args
}
```

### 初期設定
`psico --init` を実行する。

## 使用方法
- `psico` (引数なしの場合は `psico --help` と同等)
- `psico <name> [args]...` でサブコマンド実行(スクリプト実行)
  - 例; `psico myScript`
- `psico [option] [args]...`
  - `psico --help` でヘルプ表示
  - `psico --init` で初期化 (ディレクトリ構成と設定ファイル作成)
  - `psico --list` で利用可能なスクリプトの一覧表示
  - `psico --add <name> <description>` で新規スクリプトを作成
    - 例: `psico --add myScript "My useful script"`
  - `psico --list` でスクリプト一覧を表示

## オプション一覧
| 長オプション | 短オプション | 引数 | 説明 |
|--------------|--------------|------|------|
| `--init` ||| 初期構成を生成 (ディレクトリと設定ファイル) |
| `--install` | `-i` | `<url|path>` | `.ps1` または `.psm1` を URL からインストール |
| `--add` | `-a` | `<name> <description>` | 新規スクリプト作成 |
| `--remove` | `-r` | `<name>` | スクリプト削除 |
| `--edit` | `-e` | `<name>` | スクリプトをエディタで開く |
| `--list` | `-l` | | スクリプト一覧表示 (情報の description 付き) |
| `--list` | `-l` | `<tag>` | タグ別にスクリプト一覧表示 |
| `--search` | `-s` | `<keyword>` | ワイルドカードでスクリプト検索 (ファイル名+メタ情報) |
| `--search` | `-s` | `<pattern>` | 正規表現でスクリプト検索 (`"/^hello/"` のように記述する) |
| `--info` || ` <name>` | スクリプトのメタ情報表示 |
| `--test` || ` <name>` | モック引数付きでスクリプトをテスト実行 |
| `--log` || `<level>` | ログ出力レベル変更 (0-2) |
| `--log` || `-1` | ログファイル削除 |
| `--completion` ||| 補完を一時的に有効化 (現在のセッションのみ) |
| `--help` | `-h` || ヘルプ表示 |
| `--version` | `-v` || PSICO のバージョン表示 |

## 補完機能
`psico` コマンドの適切な位置で `Tab` キーや `Ctrl + Space` を押すと補完候補が表示される。
オプションやサブコマンドの引数のタイプによっては適切な補完候補が出ないことがあります。

### 補完の永続化
`$PROFILE` に以下を記載。
```
. "<PSICO ディレクトリ>\core\psico_completion.ps1"
Enable-PsicoCompletion
#Enable-PsicoCompletion -Silent
```

### 補完機能の不具合
存在しないオプションやサブコマンドに対しては想定外の補完候補が出る。
規定の数以上の引数に対しては想定外の補完候補が出る。

## 設定ファイル
設定ファイルは `<PSICO ディレクトリ>\config.json` です。
設定項目は以下の通りです。
- `editor`: `--edit / -e` でスクリプトファイルを開くテキストエディター
	- 既定値はメモ帳(`notepad`)
- `logLevel`: ログファイル(`<PSICO ディレクトリ>\logs\psico_<YYYYMMDD>.log`) への出力レベル
	- 既定値は`1`
- `completionSilent`: 補完機能起動時のメッセージ表示
	- 既定値は`false`

## ライセンス
MIT License
