# -*- Perl -*-

use strict;
use warnings;

package ZCME::HereDoc;

use Exporter qw(import);
our @EXPORT_OK = qw(here);

sub here {
    my $txt = shift;
    my $delim = shift || "\#";
    my $n = shift || 1;
    $txt =~ s/^$delim\s{$n}//mg;
    return $txt;
}
