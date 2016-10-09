# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::REST::Object;
use Carp qw(carp croak);

our $VERBOSE = 0;

sub new {
    my $class = shift;
    my $self = bless {}, (ref($class)||$class);
    $self->{_rest} = shift;

    return $self;
}

sub rest_object {
    my $self = shift;
    return $self->{_rest};
}

sub rest { 
    my $self = shift;
    defined($self->{_rest}) or carp "No REST object available.";
    return $self->{_rest}->rest(@_);
}

sub unrest {
    my $self = shift;
    $self->{_rest} = undef;
}

sub rerest {
    my $self = shift;
    $self->{_rest} = shift;
}

1;

__END__
