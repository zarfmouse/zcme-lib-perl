# -*- Perl -*- 

use strict;
use warnings;
use v5.10;
use utf8;
use IO::Handle;
STDOUT->autoflush(1);
STDERR->autoflush(1);
STDOUT->binmode(":utf8");
STDERR->binmode(":utf8");

my $dir;
BEGIN {
    $dir = __FILE__;
    $dir =~ s{/[^/]*$}{};
}

use lib "$dir/lib";
use lib "$dir/external/lib/perl5";
use local::lib "$dir/external";

1;

__END__

