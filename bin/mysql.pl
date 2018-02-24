#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
BEGIN {require "$RealBin/../setup.pl"};

use ZCME::DB;
my $db = ZCME::DB->new();
$db->launch_mysql();
