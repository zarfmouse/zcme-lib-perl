# -*- Perl -*- 

use strict;
use warnings;
use v5.10;
use utf8;
use IO::Handle;
STDOUT->autoflush(1);
STDERR->autoflush(1);
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $dir;
BEGIN {
    $dir = __FILE__;
    $dir =~ s{/[^/]*$}{};
}

use lib "$dir/lib";
use lib "$dir/../extlib/lib/perl5";

1;

__END__

