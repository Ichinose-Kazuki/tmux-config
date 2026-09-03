{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.myTmux;

  # マウス離下時に、ドラッグ元 pane に残った選択を自動でコピーする。
  # run-shell 経由で呼ばれるため $TMUX を継承し、素の tmux で自サーバーを操作する。
  tmux-autocopy = pkgs.writeShellScriptBin "tmux-autocopy" ''
    # Finalize a selection left on the drag-source pane when the mouse is
    # released over another pane, so the drag-end event is not lost.
    for pane in $(tmux list-panes -F "#{pane_id}" 2>/dev/null); do
      sel=$(tmux display-message -t "$pane" -p '#{selection_present}' 2>/dev/null)
      if [ "$sel" = "1" ]; then
        tmux send-keys -t "$pane" -X copy-pipe-and-cancel 2>/dev/null
      fi
    done
  '';

  # pane 番号 0（ウィンドウ内で最初に開かれた pane）のタイトルだけを取り出す。
  # #{P:...} はウィンドウ内の全 pane を巡回するので、pane_index が 0 の pane の
  # タイトルのみを出力する。アクティブ pane が切り替わってもタブタイトルは
  # pane 0 に固定され、pane 0 の出力には追従して更新される。
  pane0Title = "#{P:#{?#{==:#{pane_index},0},#{pane_title},}}";
in
{
  options.myTmux = {
    enable = lib.mkEnableOption "my tmux configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      terminal = "tmux-256color"; # pane 内のアプリケーションに $TERM として伝わる値
      keyMode = "vi";
      mouse = true;
      extraConfig = ''
        # ホワイトリスト方式のベース設定（すべて無効化）
        unbind-key -a
        set -g prefix None

        # 以下では tmux のウィンドウを terminal emulator のタブに見立ててタブと呼んでいる

        # タブバー（ステータスバー）を上部にし、タブ名のみ表示
        set -g status on
        set -g status-position top
        set -g status-left ""
        set -g status-right ""
        set -g status-style "bg=default"
        set -g status-justify left
        set -g window-status-format "  #{?#{==:${pane0Title},},#W,#{?#{==:${pane0Title},#{host}},#W,${pane0Title}}}  "
        set -g window-status-style "bg=default,fg=colour244"
        set -g window-status-current-format "  #{?#{==:${pane0Title},},#W,#{?#{==:${pane0Title},#{host}},#W,${pane0Title}}}  "
        set -g window-status-current-style "bg=colour239,fg=white,bold"

        # xterm 方式の Home, End を送る（デフォルトでは tmux は vt220 方式を出力する）
        bind -n Home send-keys Escape "[H"
        bind -n End send-keys Escape "[F"

        # タブ操作
        bind -n C-S-t new-window -a -c "#{pane_current_path}"
        bind -n C-S-w kill-window
        bind -n C-Tab next-window
        bind -n C-BTab previous-window

        # タブ入れ替え
        bind -n C-S-Left swap-window -t -1 \; select-window -t -1
        bind -n C-S-Right swap-window -t +1 \; select-window -t +1

        # 画面分割
        bind -n M-\\ split-window -h -c "#{pane_current_path}"
        bind -n M-- split-window -v -c "#{pane_current_path}"

        # 画面間の移動
        bind -n M-h select-pane -L
        bind -n M-l select-pane -R
        bind -n M-k select-pane -U
        bind -n M-j select-pane -D

        # detatch
        bind -n M-d detach-client

        # copy-mode を最小化: スクロールと選択コピーのみ有効、リセット系は無効
        unbind-key -T copy-mode-vi -a
        bind -T copy-mode-vi WheelUpPane send-keys -X -N 5 scroll-up
        bind -T copy-mode-vi WheelDownPane \
          send-keys -X -N 5 scroll-down \; \
          if-shell -F '#{==:#{selection_active},0}' 'if-shell -F "#{==:#{scroll_position},0}" "send-keys -X cancel"'
        bind -T copy-mode-vi MouseDrag1Pane send-keys -X begin-selection
        bind -T copy-mode-vi MouseDragEnd1Pane \
          send-keys -X copy-pipe \; \
          if-shell -F '#{==:#{scroll_position},0}' 'send-keys -X cancel'
        bind -T copy-mode-vi q send-keys -X cancel
        bind -T copy-mode-vi Escape send-keys -X cancel
        bind -T copy-mode-vi Enter send-keys -X cancel

        # copy-mode の表示色
        set -g mode-style "bg=magenta,fg=white"
        set -wg copy-mode-position-format "[#{scroll_position}/#{history_size}]"

        # 内側のアプリ(Claude Code 等)が自ら出す OSC 52 を外側の
        # ターミナルエミュレータへ中継する。
        set -g set-clipboard on

        # 外側の Terminal Emulator に対して True Color (24bitカラー) 対応を宣伝
        set -as terminal-features ',xterm*:RGB'
        set -as terminal-features 'xterm*:extkeys'
        set -as terminal-features 'xterm*:csiu'

        # 内側のアプリケーションの要求の有無に関わらず、拡張キーボードプロトコルを送信する
        set -s extended-keys always
        # 内側へ送る形式を CSI-u にする。tmux のデフォルトは xterm 形式だが、
        # これだと kitty プロトコルの CSI-u シーケンスが xterm 形式に翻訳され、
        # zsh 側の CSI-u バインドに届かなくなる。
        set -s extended-keys-format csi-u

        # detach でセッションを死なさない
        set -g destroy-unattached off

        # マウス離下時に、ドラッグ元 pane に残った選択を自動でコピーする。
        # ユーザー設定は unbind-key -a で root テーブルを空にしているため、
        # 境界越えで pane 切り替えが起きず、ドラッグ元 pane の選択が残る。
        # そのため離下イベントはマウス位置の pane（copy-mode でない）の
        # root テーブルで発火し、ここで残った選択をコピーする。
        # マウスが pane 境界線上で離されたときは MouseDragEnd1Pane ではなく
        # MouseDragEnd1Border が発火するため、両方に同じスクリプトを仕込む。
        bind -n MouseDragEnd1Pane run-shell '${tmux-autocopy}/bin/tmux-autocopy'
        bind -n MouseDragEnd1Border run-shell '${tmux-autocopy}/bin/tmux-autocopy'
      '';
    };

    home.packages = [ tmux-autocopy ];

    programs.zsh.initContent = lib.mkAfter ''
      # tmux 起動: tmux の外で対話シェルが起きたらセッションを選択/作成してアタッチ
      if [[ -z "$TMUX" ]] && command -v tmux >/dev/null 2>&1; then
        # 既存セッション一覧（名前のみ、改行区切り）
        sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)

        if [[ -z "$sessions" ]]; then
          # セッションが無ければ main を作ってアタッチ（メニューは出さない）
          tmux new-session -s main
        else
          # fzf で既存セッション + 新規作成 を選択。Esc でキャンセル。
          choice=$(printf '%s\n' "$sessions" 'create new' \
            | fzf --prompt='tmux> ' --height=40% --reverse --no-info \
                  --header='Enter: select  Esc: cancel')

          if [[ -z "$choice" ]]; then
            : # キャンセル: プレーンなシェルに落ちる
          elif tmux has-session -t "$choice" 2>/dev/null; then
            # 既存セッションへアタッチ
            tmux attach-session -t "$choice"
          elif [[ "$choice" == 'create new' ]]; then
            # 名前決定: main が空いていれば main、さもなくば subN（最小の空き番号）
            if ! tmux has-session -t main 2>/dev/null; then
              name=main
            else
              n=1
              while tmux has-session -t "sub$n" 2>/dev/null; do
                n=$((n + 1))
              done
              name="sub$n"
            fi
            tmux new-session -s "$name"
          fi

          unset sessions choice name n
        fi
      fi
    '';
  };
}
