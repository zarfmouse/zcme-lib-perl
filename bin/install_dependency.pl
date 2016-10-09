#!/usr/bin/env perl

$|=1;

use strict;
use warnings;

use FindBin qw($RealBin);
require "$RealBin/../setup.pl";
use CPAN;

my @modules = @ARGV ? @ARGV : qw(Bundle::LWP Net:HTTP JSON JSON::PP Mozilla::CA XML::Parser XML::SAX Carp::Always Math::Round HTTP::Request File::ChangeNotify CGI);

foreach my $module (@modules) {
    print "Installing $module...\n\n";
    CPAN::Shell->install($module);
    print "...\n\n$module Done.\n\n";
}
