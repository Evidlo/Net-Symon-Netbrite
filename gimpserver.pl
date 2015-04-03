#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';

use Term::ReadKey;
use Net::SNMP;
use Net::Symon::NetBrite qw(:constants);
use Net::Symon::NetBrite::Zone;

my $signAddr = shift || '192.168.220.242';
my $welcome  = shift || 'GIMPLAN!';

my $router   = '192.168.220.254';
my $comm     = 'public';
my $sver     = 'snmpv2c';
#my $mibIn    = '.1.3.6.1.2.1.2.2.1.10';   # IF-MIB::ifInOctets
#my $mibOut   = '.1.3.6.1.2.1.2.2.1.16';   # IF-MIB::ifOutOctets
my $mibIn    = '.1.3.6.1.2.1.31.1.1.1.6';  # IF-MIB::ifHCInOctets
my $mibOut   = '.1.3.6.1.2.1.31.1.1.1.10'; # IF-MIB::ifHCOutOctets
my $ifIndex  = '510';

my $strInPostfix  = 'k IN ';
my $strOutPostfix = 'k OUT';

my $ctrMax   = 18446744073709551615;
my $sleep    = 5; # number of seconds between updates
#my $factor   = 1048576; # Factor to shorten by, to get to MB/s
my $factor   = 1024; # Factor to shorten by, to get to kB/s

my $result;    # holds response

my $oldVarIn  = 0; # value from 5 secs ago
my $oldVarOut = 0; # value from 5 secs ago
my $varIn     = 0; # holds response variable
my $varOut    = 0; # holds response variable

my $mbIn  = 0;  # mbit per sec in
my $mbOut = 0;  # mbit per sec out

my $sign = Net::Symon::NetBrite->new(
    address => $signAddr,
);

my $bwOut = new Net::Symon::NetBrite::Zone(
    rect => [0, 0, 80, 8],
    default_font  => 'proportional_5',
    default_color => COLOR_RED,
    initial_text  => '{scrolloff}{right}'.$strOutPostfix,
);

my $bwIn = new Net::Symon::NetBrite::Zone(
    rect => [0, 9, 80, 16],
    default_font  => 'proportional_5',
    default_color => COLOR_GREEN,
    initial_text  => '{scrolloff}{right}' . $strInPostfix,
);

my $status = new Net::Symon::NetBrite::Zone(
    rect => [81, 0, 160, 16],
    default_font  => 'monospace_16',
    default_color => COLOR_GREEN,
    initial_text  => '{scrolloff}{right}' . $welcome,
);

    
$sign->zones(
    bwout  => $bwOut,
    bwin   => $bwIn,
    status => $status,
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
            "$mibIn.$ifIndex",
            "$mibOut.$ifIndex",
        ],
    );
    if (!defined $result) {
        printf "Got %s querying %s.\n", $session->error(), $signAddr;
        $session->close();
        exit 1;
    }
    $oldVarIn = $varIn;
    $oldVarOut = $varOut;
    $varIn  = $result->{"$mibIn.$ifIndex"};
    $varOut = $result->{"$mibOut.$ifIndex"};

    $session->close();

    print "Result In: $varIn\n";
    print "Result Out: $varOut\n";

    if ($varIn < $oldVarIn) {
        $mbIn = (($ctrMax - $oldVarIn) + $varIn);
    } else {
        $mbIn  = ($varIn - $oldVarIn);
    }
    if ($varOut < $oldVarOut) {
        $mbOut = (($ctrMax - $oldVarOut) + $varOut);
    } else {
        $mbOut = ($varOut - $oldVarOut);
    }
    
    $mbIn  /= $factor * $sleep;
    $mbOut /= $factor * $sleep;

    printf "MB IN: %.2f\n", $mbIn;
    printf "MB OUT: %.2f\n", $mbOut;

    $sign->message('bwin', sprintf '{scrolloff}{right}%.0f %s', $mbIn, $strInPostfix);
    $sign->message('bwout', sprintf '{scrolloff}{right}%.0f %s', $mbOut, $strOutPostfix);


}
