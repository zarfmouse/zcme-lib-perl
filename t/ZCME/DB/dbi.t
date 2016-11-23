#!/usr/bin/env perl 

use strict;
use warnings;

use FindBin;
BEGIN { 
    my $file = $FindBin::RealBin;
    $file =~ s{/t/.*$}{/setup.pl};
    require $file;
};

use Test::More tests => 2;

use ZCME::DB;

my $db = ZCME::LMS::DB->new();
my $dbh = $db->dbh();

isa_ok($dbh, 'DBI::db');
my $sth = $dbh->prepare("show databases");
$sth->execute();
my $n = 0;
my %database;
while(my $row = $sth->fetchrow_hashref()) {
    $database{$row->{Database}} = 1;
}
my $database = $db->database();
ok($database{$database}, "$database exists");






