#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';

use Net::Symon::NetBrite qw(:constants);
use Net::Symon::NetBrite::Zone;

my $sign = Net::Symon::NetBrite->new(
    address => '192.168.220.241',
);

my $bwout = new Net::Symon::NetBrite::Zone(
    rect => [0, 0, 80, 8],
    default_font => 'proportional_5',
    default_color => COLOR_RED,
    initial_text => '{scrolloff}{right}Mbps OUT',
);

my $bwin = new Net::Symon::NetBrite::Zone(
    rect => [0, 9, 80, 16],
    default_font => 'proportional_5',
    default_color => COLOR_GREEN,
    initial_text => '{scrolloff}{right}Mbps IN',
);

my $gimplan = new Net::Symon::NetBrite::Zone(
    rect => [81, 0, 160, 16],
    default_font => 'monospace_16',
    default_color => COLOR_GREEN,
    initial_text => '{scrolloff}{right}GIMPLAN!',
);

    
$sign->zones(
    bwout => $bwout,
    bwin => $bwin,
    gimplan => $gimplan,
);

<>;
$sign->message('bwout', '{scrolloff}{right}10 Mbps OUT');
$sign->message('bwin', '{scrolloff}{right}20 Mbps IN');
<>;
$sign->message('bwout', '{scrolloff}{right}20 Mbps OUT');
$sign->message('bwin', '{scrolloff}{right}15 Mbps IN');
<>;
$sign->message('bwout', '{scrolloff}{right}40 Mbps OUT');
$sign->message('bwin', '{scrolloff}{right}47 Mbps IN');
<>;
$sign->message('bwout', '{scrolloff}{right}30 Mbps OUT');
$sign->message('bwin', '{scrolloff}{right}58 Mbps IN');
<>;
$sign->message('bwout', '{scrolloff}{right}10 Mbps OUT');
$sign->message('bwin', '{scrolloff}{right}15 Mbps IN');
<>;
$sign->reboot();

