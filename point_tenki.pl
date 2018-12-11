#!/usr/bin/perl
#
# Yahooピンポイント天気の3時間予報から現在の天気情報を表示する。
# Copyright (c) 2017 yama_natuki
# license GPLv2
#

use strict;
use warnings;
use LWP::UserAgent;
use HTML::TreeBuilder;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use utf8;
use Encode;
binmode(STDOUT, ":utf8");

# デフォルトurl
my $url = 'https://weather.yahoo.co.jp/weather/jp/13/4410/13120.html';
my ($weather_tomorrow, $weather_today, $weather_now, $show_all, $show_help);
my @today;     # 今日の天気
my @tomorrow;  # 明日の天気
my $area;      # 場所

sub get_contents {
    my $address = shift;
    my $http = LWP::UserAgent->new;
    my $res = $http->get($address);
    my $content = $res->content;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse($content);
    return $tree;
}

# 場所を取得
sub get_area {
    my $area = shift;

    # URLの判定
    eval {
        $area = $area->look_down('class', 'yjw_sub_md_lined');
        $area = $area->look_down('class', 'yjw_title_h2')->find('h2')->as_text;
    };

    if ($@) {
        print "Not URL\n";
        exit 0;
    }

    utf8::decode($area);
    $area =~ s/エリアの情報//;
    return $area;
}

# 3時間ごとの天気を取得
sub get_point_data {
    my $point = shift;
    my @items =  $point->look_down('id', 'yjw_pinpoint_today')->find('td');
    &split_data( \@items );
}

# 明日の天気
sub point_tomorrow {
    my $point = shift;
    my @items =  $point->look_down('id', 'yjw_pinpoint_tomorrow')->find('td');
    &split_data( \@items );
}

sub split_data {
    my $items = shift;
    my $length = 54; #全項目数
    my $slice = 9; #分割数
    my @data;

    for (my $i = 0; $i < ($length / $slice); $i++) {
        my @arrE1;
        for (my $j =0; $j < $slice; $j++) {
            my $p = shift @$items;
            if ($p eq "") { last;}
            $p = $p->as_text;
            utf8::decode($p);
            push(@arrE1, $p);
        }
        push(@data, \@arrE1);
    }
    return @data;

}

# 文字数カウント
sub data_width {
    my $item = shift;
    my @width;
    foreach my $i ( @$item ) {
        #全角文字を2byteでカウントする
        push( @width, length Encode::encode('cp932', $i) );
    }
    return @width;
}

# マルチバイト文字数をカウントする
sub mb_count {
    my $str = shift;
    my $count = 0;
    for my $i (0 .. length($str) -1) {
        # とりあえず文字だけ取得しておく
        my $chr = substr($str, $i, 1);
        {
            # ここのスコープはバイトとして扱う
            use bytes;
            # 1バイトじゃなかったらカウントアップ！
            $count++ unless 1 == length($chr);
        }
    }
    return $count;
}

sub gettime() {
    my $ntime = (localtime)[2];

    if    ( $ntime <  3 ) { return 1; }
    elsif ( $ntime <  6 ) { return 2; }
    elsif ( $ntime <  9 ) { return 3; }
    elsif ( $ntime < 12 ) { return 4; }
    elsif ( $ntime < 15 ) { return 5; }
    elsif ( $ntime < 18 ) { return 6; }
    elsif ( $ntime < 21 ) { return 7; }
    elsif ( $ntime < 24 ) { return 8; }
}

#コマンドラインの取得
sub getopt() {
    GetOptions(
               "today|t"    => \$weather_today,
               "now|n"      => \$weather_now,
               "tomorrow|m" => \$weather_tomorrow,
               "all|a"      => \$show_all,
               "help|h"     => \$show_help
              );
}

sub print_forecast {
    my $weather = shift;
    my $now = &gettime;
    my @width = &data_width($weather->[5]);

    if ($weather_tomorrow) {
        print "\e[32m明日の天気\e[0m\n";
    }
    else {
        print "\e[32m3時間ごとの天気\e[0m\n";
    }

    print $area . "\n";
    print "----------\n";

    foreach my $x (@$weather) {
        for (my $i = 0; $i < 9; $i++) {
            my $item = $x->[$i];
            my $length = $width[$i] + 2 - &mb_count( $item);
            if ($i > 0) {
                unless ($weather_tomorrow) {
                    if ( $i eq $now ) {
                        $item = "\e[1m" . $item . "\e[0m";
                        $length = $width[$i] + 2 - &mb_count( $item) + 8; #esc文字分追加
                    }
                    elsif ( $i < $now ) {
                        $item = "\e[090m" . $item . "\e[0m";              #\e[2m は端末によって機能しないので。
                        $length = $width[$i] + 4 - &mb_count( $item) + 8; #esc文字分追加
                    }
                }
            }
            #文字数指定を可変にするには %*sにして引数で渡すだけでいい
            printf("%-*s", $length, $item);
        }
        print "\n";
	}

}

sub weather_now {
    my $now = &gettime;
    print "\e[32mYahooピンポイント天気\e[0m\n";
    print "場所   :: " . $area . "\n";
    print "時間   :: " . $today[0]->[$now] . "\n";
    print "天気   :: " . $today[1]->[$now] . "\n";
    print "気温   :: " . $today[2]->[$now] . "℃\n";
    print "湿度   :: " . $today[3]->[$now] . "％\n";
    print "降水量 :: " . $today[4]->[$now] . " mm/h\n";
    print "風速   :: " . $today[5]->[$now] . " m/s\n";
}

# help
sub show_help {
    print "Usage: point_tenki.pl [options]  url\n".
        "\tOption:\n".
        "\t\t-t|--today\n".
        "\t\t\t3時間ごとの天気を表示。\n".
        "\t\t-n|--now\n".
        "\t\t\t現在の時刻の天気を表示。\n".
        "\t\t-m|--tomorrow\n".
        "\t\t\t明日の天気を表示。\n".
        "\t\t-a|--all\n".
        "\t\t\t3時間ごとと明日の両方の天気を表示。\n".
        "\t\t-h|--help\n".
        "\t\t\tこのテキストを表示。\n"
}

sub initialize {
    my $item = &get_contents( $url );
    $area = &get_area($item);
    @today = &get_point_data($item);
    @tomorrow  = &point_tomorrow($item);
}

#main
{
    &getopt();

    if ($show_help) {
        &show_help;
        exit 0;
    }

    if ($ARGV[$#ARGV]) {
        my $adres = $ARGV[$#ARGV];
        if ($adres =~ m|https://weather\.yahoo\.co\.jp/|) {
            $url = $adres;
        }
    }

    if ($weather_today) {
        &initialize;
        &print_forecast(\@today);
    }
    elsif ($weather_now) {
        &initialize;
        &weather_now;
    }
    elsif ($show_all) {
        &initialize;
        &print_forecast(\@today);
        $weather_tomorrow = 1;
        print "\n";
        &print_forecast(\@tomorrow);
    }
    elsif ($weather_tomorrow) {
        &initialize;
        &print_forecast(\@tomorrow);
    }
    else {
        &show_help;
    }
}
