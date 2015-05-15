#!/usr/bin/perl

# Always good practice
use strict;
# The threads module allows us to implement threading in our script
use threads;

use warnings;
use lib 'lib';

use Term::ReadKey;
use Net::SNMP;
use Net::Symon::NetBrite qw(:constants);
use Net::Symon::NetBrite::Zone;

##
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

my $strOut = new Net::Symon::NetBrite::Zone(
    rect => [0, 0, 25, 8],
    default_font  => 'proportional_5',
    default_color => COLOR_RED,
    initial_text  => sprintf('{scrolloff}{left}%s', $strOutPostfix),
);
my $bwOutDSL = new Net::Symon::NetBrite::Zone(
    rect => [26, 0, 40, 8],
    default_font  => 'proportional_5',
    default_color => COLOR_RED,
    initial_text  => sprintf('{scrolloff}{right}%d', 0),
);
my $bwOutLTE = new Net::Symon::NetBrite::Zone(
    rect => [41, 0, 70, 8],
    default_font  => 'proportional_5',
    default_color => COLOR_RED,
    initial_text  => sprintf('{scrolloff}{right}%d', 0),
);

my $strIn = new Net::Symon::NetBrite::Zone(
    rect => [0, 9, 25, 16],
    default_font  => 'proportional_5',
    default_color => COLOR_GREEN,
   initial_text  => sprintf('{scrolloff}{left}%s', $strInPostfix),
);
my $bwInDSL = new Net::Symon::NetBrite::Zone(
    rect => [26, 9, 40, 16],
    default_font  => 'proportional_5',
    default_color => COLOR_GREEN,
   initial_text  => sprintf('{scrolloff}{right}%d', 0),
);
my $bwInLTE = new Net::Symon::NetBrite::Zone(
    rect => [41, 9, 70, 16],
    default_font  => 'proportional_5',
    default_color => COLOR_GREEN,
   initial_text  => sprintf('{scrolloff}{right}%d', 0),
);

my $status = new Net::Symon::NetBrite::Zone(
    rect => [71, 0, 160, 16],
    default_font  => 'monospace_16',
    default_color => COLOR_GREEN,
    initial_text  => '{scrolloff}{center}' . $welcome,
);

##

# The number of threads used in the script
my $num_of_threads = 2;

# use the initThreads subroutine to create an array of threads.
my @threads = initThreads();

# Loop through the array:
#foreach(@threads){
#        # Tell each thread to perform our 'doOperation()' subroutine.
#		$_ = threads->create(\&doOperation);
#}

my $thr1 = threads->create(\&doOperation,"192.168.220.241");
my $thr2 = threads->create(\&doOperation,"192.168.220.242");
$thr1->join();
$thr2->join();

####################### SUBROUTINES ############################
sub initThreads{
	my @initThreads;
	for(my $i = 1;$i<=$num_of_threads;$i++){
		push(@initThreads,$i);
	}
	return @initThreads;
}

sub doOperation{
	my $key;

	# Get the thread id. Allows each thread to be identified.
	my $id = threads->tid();
	
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
		address => $_[0],
	);
	
	print "Connection to $_[0] Thread $id\n";
	
	$sign->zones(
		strout      => $strOut,
		bwoutdsl    => $bwOutDSL,
		bwoutlte    => $bwOutLTE,
		strin       => $strIn,
		bwindsl     => $bwInDSL,
		bwinlte     => $bwInLTE,
		status      => $status,
	);
	
	while ( !defined( $key = ReadKey(-1) ) ) {

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
		    printf "Got %s querying %s.\n", $session->error(), $_[0];
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

		
		$sign->message('bwindsl', sprintf '{scrolloff}{right}%.0f', $mbInDSL);
		$sign->message('bwoutdsl', sprintf '{scrolloff}{right}%.0f', $mbOutDSL);
		$sign->message('bwinlte', sprintf '{scrolloff}{right}%.0f', $mbInLTE);
		$sign->message('bwoutlte', sprintf '{scrolloff}{right}%.0f', $mbOutLTE);
				
		sleep 5;
	}
	
	threads->exit();
}

