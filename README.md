point_tenki
===============================

ヤフー3時間ごとのピンポイント天気をコマンドライン表示する
-------------------------------

　3時間ごとの天気、またはその時間の天気情報を表示します。

# 導入方法

## 必要ライブラリ

```
    LWP::UserAgent
    HTML::TreeBuilder
```

Debain系

`    sudo apt-get install git libwww-perl libhtml-treebuilder-libxml-perl ` 

## インストール

`  git clone  https://github.com/yama-natuki/point_tenki.git `

# 使い方

　引数に表示させたい場所のurlを渡す。

`    ./point_tenki.pl -a 場所のurl `

暮しい使い方は -h オプションで表示。

# ライセンス
　GPLv2

