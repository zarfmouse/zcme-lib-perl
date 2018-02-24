#!/usr/bin/env perl 

use strict;
use warnings;

use FindBin;
BEGIN { 
    my $file = $FindBin::RealBin;
    $file =~ s{/t/.*$}{/setup.pl};
    require $file;
};

use Test::More tests => 4;

my $data = {
   str => 'abc',
   num => 42.3,
};

use JSON;
use Data::Dumper qw(Dumper);

my $json = encode_json($data);
diag($json);
like($json, qr/"num"\:42/, 'number');
like($json, qr/"str"\:"abc"/, 'string');

Dumper($data);
$json = encode_json($data);
diag($json);
like($json, qr/"num"\:42/, 'number');
like($json, qr/"str"\:"abc"/, 'string');

__END__
