# tmux-config

tmux の設定を home-manager の homeModule として提供する Nix flake です。
ターミナルエミュレータのタブ操作に近い感覚で tmux を使えるようにすることを
目的としています。本体は `home.nix` が `myTmux` という home-manager オプション
としてエクスポートしています。

## 提供する機能

### タブ操作（ウィンドウ操作）

tmux のウィンドウをターミナルエミュレータのタブに見立てて操作します。
タブバーは画面上部にタブ名のみを表示します。

- 新規タブ作成：`Ctrl+Shift+t`
- タブを閉じる：`Ctrl+Shift+w`
- 次のタブへ：`Ctrl+Tab`
- 前のタブへ：`Ctrl+Shift+Tab`
- タブの並び替え（左／右）：`Ctrl+Shift+Left`／`Ctrl+Shift+Right`

### タブタイトルの表示

各タブのタイトルは、ウィンドウ内で最初に開かれた pane（pane 0）のタイトルを
表示します。pane を切り替えてもタブタイトルが揺らず、pane 0 がアプリ側で
タイトルを出力すればそれに追従して更新されます。

タイトルが未設定のときは、自動命名されたコマンド名（`vim`、`htop` など）や
手動で付けたウィンドウ名でフォールバックします。

### 画面分割と pane 移動

- 左右分割：`Alt+\`
- 上下分割：`Alt+-`
- pane 間の移動（vi 風）：`Alt+h` `Alt+l` `Alt+k` `Alt+j`
- detach：`Alt+d`

### コピー操作

マウス操作でテキストを選択してコピーできます。copy-mode はスクロールと
選択コピーだけに最小化し、リセット系の操作は無効化しています。

- ホイールでスクロール。ドラッグで選択を開始し、離すとコピーして copy-mode を
  終了します（最上段にいるときのみ）。
- `q` `Escape` `Enter` で copy-mode をキャンセルします。
- 選択範囲は反転色で表示し、位置と履歴サイズを表示します。

#### 境界越えドラッグでの自動コピー

マウスドラッグで文字を選択中に別の pane 領域へカーソルを動かして離した
とき、ドラッグ元の pane に残った選択を自動でコピーします。通常は離下
イベントがドラッグ先の pane で発火してコピーが取りこぼれるため、これを
補って確実にコピーします。pane の境界線上で離した場合も同じく補います。

### クリップボードの中継

内側のアプリケーション（Claude Code など）が出す OSC 52 シーケンスを、
外側のターミナルエミュレータのクリップボードへ中継します。tmux の中で
動くアプリからのコピーが、そのまま外側のクリップボードに入ります。

### 色

外側のターミナルエミュレータに対して 24bit カラー（True Color）対応を
宣言します。

### キーボードプロトコル

アプリケーションの要求の有無に関わらず、拡張キーボードプロトコルを
内側へ送信します。内側へ送る形式は CSI-u とし、zsh 側の CSI-u キーバインドが
正しく届くようにします。

### Home / End キー

xterm 方式の Home / End キーを内側のアプリへ送ります。tmux のデフォルトは
vt220 方式ですが、これを xterm 方式に置き換えます。

### セッションの自動アタッチ

tmux の外で対話シェルが起きたとき、自動的にセッションを選択または作成して
アタッチします。

- 既存セッションが無ければ `main` というセッションを作ってアタッチします。
- 既存セッションがあれば fzf で一覧から選択します。`create new` を選ぶと
  `main` が空いていれば `main`、さもなくば `sub1` `sub2` ... の最も小さい
  空き番号で新規セッションを作ります。`Esc` でキャンセルし、プレーンな
  シェルに落ちます。

### クラッシュ・再起動対策

`tmux-resurrect` と `tmux-continuum` により、pane の状態を自動で保存・復元
します。手動での保存・復元キーは割り当てていません。

- 15分ごとに、その時点で存在する全セッションの構成（ウィンドウ、pane、
  カレントディレクトリ、一部の実行中プログラム）を自動保存します。
- PC 再起動後、最初に tmux サーバーが起動したタイミングで自動的に前回の
  保存内容を復元します。上記の自動アタッチにより作られる最初の pane に
  対して復元が行われるため、追加の操作は不要です。
- 復元されるプログラムは既定のリスト（`vi` `vim` `view` `nvim` `emacs`
  `man` `less` `more` `tail` `top` `htop` `irssi` `weechat` `mutt`）に
  限られます。それ以外のプログラムが動いていた pane は、カレントディレクトリ
  だけ復元されシェルが開いた状態になります。
- pane に表示されていた画面内容（スクロール履歴）は復元しません。

### ベース設定の方針

デフォルトのキーバインドをすべて削除した上で（ホワイトリスト方式）、上記の
機能だけを有効化します。これにより意図しない挙動を排除し、定義した操作だけが
動くようにしています。detach してもセッションは残ります。

## 使い方

home-manager の設定でこの flake を input に加え、`tmux-config.homeModules.default`
をモジュールとして読み込みます。そして `myTmux.enable = true` を設定します。

```nix
{
  inputs.tmux-config.url = "github:Ichinose-Kazuki/tmux-config";
  # 単体検証時は path:./tmux-config も可

  outputs = { self, nixpkgs, home-manager, tmux-config, ... }: {
    homeConfigurations.myhome = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      modules = [
        tmux-config.homeModules.default
        { myTmux.enable = true; }
      ];
    };
  };
}
```

`myTmux.enable` を有効にすると、`programs.tmux` の設定と、tmux 起動用の
zsh 初期化スクリプトが組み込まれます。zsh の `initContent` にマージされる
ため、利用するホスト側で `programs.zsh.enable = true` になっている必要が
あります。

### 単体でのビルド検証

この flake は `homeConfigurations.default` を持ち、自身の homeModule を
読み込んだ home を単体でビルドできます。

```bash
nix build .#homeConfigurations.default.activationPackage
```
