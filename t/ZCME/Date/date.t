#!/usr/bin/env perl 

use strict;
use warnings;

use FindBin;
BEGIN { 
    my $file = $FindBin::RealBin;
    $file =~ s{/t/.*$}{/setup.pl};
    require $file;
};

use Test::Simple tests => 4;
use Data::Dumper qw(Dumper);

use ZCME::Date;
my $date = ZCME::Date->new('2014-01-01');
ok($date->printf('%Y-%m-%d') eq '2014-01-01');
$date = ZCME::Date->new($date);
ok($date->printf('%Y-%m-%d') eq '2014-01-01');
$date = Date::Manip::Date->new('2014-01-01');
ok($date->printf('%Y-%m-%d') eq '2014-01-01');
$date = ZCME::Date->new($date);
ok($date->printf('%Y-%m-%d') eq '2014-01-01');
