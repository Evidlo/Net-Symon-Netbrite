# Symon Sign

Here's how I got the sign working on Debian

    # set up address to talk to sign.  Use interface name for your ethernet port
    sudo ip addr add 10.164.3.86/24 dev enp0s25

    # install perl deps
    sudo apt install libmodule-build-perl libdigest-crc-perl

    # not sure what this stuff is doing
    perl Build.PL
    ./Build installdeps
    ./Build manifest
    
    # write to the sign (edit the script to use the correct ip address)
    perl signserver.pl
