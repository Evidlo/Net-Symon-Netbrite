#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';

use Term::ReadKey;
use Net::SNMP;
use Net::Symon::NetBrite qw(:constants);
use Net::Symon::NetBrite::Zone;

my $signAddr = shift || '192.168.220.242';
my $welcome  = shift || 'THECAMP!';

my $router   = '192.168.16.1';
my $comm     = 'public';
my $sver     = 'snmpv2c';
my $mibIn    = '.1.3.6.1.2.1.31.1.1.1.6';  # IF-MIB::ifHCInOctets
my $mibOut   = '.1.3.6.1.2.1.31.1.1.1.10'; # IF-MIB::ifHCOutOctets
my $ifIndexDSL  = '1'; # vr0, DSL
my $ifIndexLTE  = '8'; # vlan 3, LTE

my $strInPostfix  = 'k/i:';
my $strOutPostfix = 'k/o:';

my $ctrMax   = 18446744073709551615;
my $sleep    = 5; # number of seconds between updates
my $factor   = 1024; # Factor to shorten by, to get to kB/s

my $result;    # holds response

my $oldVarInDSL  = 0; # value from 5 secs ago
my $oldVarOutDSL = 0; # value from 5 secs ago
my $varInDSL     = 0; # holds response variable
my $varOutDSL    = 0; # holds response variable

my $oldVarInLTE  = 0; # value from 5 secs ago
my $oldVarOutLTE = 0; # value from 5 secs ago
my $varInLTE     = 0; # holds response variable
my $varOutLTE    = 0; # holds response variable

my $mbInDSL  = 0;  # mbit per sec in
my $mbOutDSL = 0;  # mbit per sec out

my $mbInLTE  = 0;  # mbit per sec in
my $mbOutLTE = 0;  # mbit per sec out

my $sign = Net::Symon::NetBrite->new(
    address => $signAddr,
);

my $strOut = new Net::Symon::NetBrite::Zone(
    rect => [0, 0, 27, 8],
    default_font  => 'proportional_5',
    default_color => COLOR_RED,
    initial_text  => sprintf('{scrolloff}{left}%s', $strOutPostfix),
);
my $bwOutDSL = new Net::Symon::NetBrite::Zone(
    rect => [28, 0, 42, 8],
    default_font  => 'proportional_5',
    default_color => COLOR_RED,
    initial_text  => sprintf('{scrolloff}{right}%d', 0),
);
my $bwOutLTE = new Net::Symon::NetBrite::Zone(
    rect => [43, 0, 60, 8],
    default_font  => 'proportional_5',
    default_color => COLOR_RED,
    initial_text  => sprintf('{scrolloff}{right}%d', 0),
);

my $strIn = new Net::Symon::NetBrite::Zone(
    rect => [0, 9, 27, 16],
    default_font  => 'proportional_5',
    default_color => COLOR_GREEN,
   initial_text  => sprintf('{scrolloff}{left}%s', $strInPostfix),
);
my $bwInDSL = new Net::Symon::NetBrite::Zone(
    rect => [28, 9, 42, 16],
    default_font  => 'proportional_5',
    default_color => COLOR_GREEN,
   initial_text  => sprintf('{scrolloff}{right}%d', 0),
);
my $bwInLTE = new Net::Symon::NetBrite::Zone(
    rect => [43, 9, 60, 16],
    default_font  => 'proportional_5',
    default_color => COLOR_GREEN,
   initial_text  => sprintf('{scrolloff}{right}%d', 0),
);

my $status = new Net::Symon::NetBrite::Zone(
    rect => [61, 0, 160, 16],
    default_font  => 'monospace_16',
    default_color => COLOR_GREEN,
    initial_text  => '{scrolloff}{center}' . $welcome,
);

    
$sign->zones(
    strout      => $strOut,
    bwoutdsl    => $bwOutDSL,
    bwoutlte    => $bwOutLTE,
    strin       => $strIn,
    bwindsl     => $bwInDSL,
    bwinlte     => $bwInLTE,
    status      => $status,
);

my $key;
ReadMode 4;

while ( !defined( $key = ReadKey(-1) ) ) {
    print "Setting Sign\n";
    set_bwsign();
    sleep $sleep;
}
$sign->reboot();

sub set_bwsign
{
    my ($session, $error) = Net::SNMP->session(
        -hostname  => $router,
        -community => $comm,
        -version   => $sver,
    );
    if (!defined $session) {
        printf "ERROR: %s.\n", $error;
        exit 1;
    }

    $result = $session->get_request(
        -varbindlist => 
        [ 
            "$mibIn.$ifIndexDSL",
            "$mibOut.$ifIndexDSL",
            "$mibIn.$ifIndexLTE",
            "$mibOut.$ifIndexLTE",
        ],
    );
    if (!defined $result) {
        printf "Got %s querying %s.\n", $session->error(), $signAddr;
        $session->close();
        exit 1;
    }
    $oldVarInDSL = $varInDSL;
    $oldVarOutDSL = $varOutDSL;
    $oldVarInLTE = $varInLTE;
    $oldVarOutLTE = $varOutLTE;
    $varInDSL  = $result->{"$mibIn.$ifIndexDSL"};
    $varOutDSL = $result->{"$mibOut.$ifIndexDSL"};
    $varInLTE  = $result->{"$mibIn.$ifIndexLTE"};
    $varOutLTE = $result->{"$mibOut.$ifIndexLTE"};

    $session->close();

    #print "Result In: $varIn\n";
    #print "Result Out: $varOut\n";

    if ($varInDSL < $oldVarInDSL) {
        $mbInDSL = (($ctrMax - $oldVarInDSL) + $varInDSL);
    } else {
        $mbInDSL  = ($varInDSL - $oldVarInDSL);
    }
    if ($varOutDSL < $oldVarOutDSL) {
        $mbOutDSL = (($ctrMax - $oldVarOutDSL) + $varOutDSL);
    } else {
        $mbOutDSL = ($varOutDSL - $oldVarOutDSL);
    }
    if ($varInLTE < $oldVarInLTE) {
        $mbInLTE = (($ctrMax - $oldVarInLTE) + $varInLTE);
    } else {
        $mbInLTE  = ($varInLTE - $oldVarInLTE);
    }
    if ($varOutLTE < $oldVarOutLTE) {
        $mbOutLTE = (($ctrMax - $oldVarOutLTE) + $varOutLTE);
    } else {
        $mbOutLTE = ($varOutLTE - $oldVarOutLTE);
    }
    
    $mbInDSL  /= $factor * $sleep;
    $mbOutDSL /= $factor * $sleep;
    
    $mbInLTE  /= $factor * $sleep;
    $mbOutLTE /= $factor * $sleep;

    printf "DSL MB IN: %.2f\n", $mbInDSL;
    printf "DSL MB OUT: %.2f\n", $mbOutDSL;
    printf "LTE MB IN: %.2f\n", $mbInLTE;
    printf "LTE MB OUT: %.2f\n", $mbOutLTE;

    $sign->message('bwindsl', sprintf '{scrolloff}{right}%.0f', $mbInDSL);
    $sign->message('bwoutdsl', sprintf '{scrolloff}{right}%.0f', $mbOutDSL);
    $sign->message('bwinlte', sprintf '{scrolloff}{right}%.0f', $mbInLTE);
    $sign->message('bwoutlte', sprintf '{scrolloff}{right}%.0f', $mbOutLTE);

}
