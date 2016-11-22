# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Filter;
use base qw(ZCME::REST::Object);
use Scalar::Util qw(looks_like_number);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak);

our $VERBOSE = 0;

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $key_or_content = shift;
    if(ref($key_or_content) eq 'HASH') {
	$self->{_content} = $key_or_content;
	$self->{_key} = $self->{_content}->{id};
    } else {
	$self->{_key} = $key_or_content;
	$self->refresh();
    }
    return $self;
}

sub key { 
    my $self = shift;
    return $self->{_key};
}

sub refresh {
    my $self = shift;
    my $key = $self->key();
    $self->{_content} = $self->rest('GET', "filter/$key");
}

sub name {
    my $self = shift;
    return $self->{_content}->{name};
}

sub description {
    my $self = shift;
    return $self->{_content}->{description};
}

sub jql {
    my $self = shift;
    return $self->{_content}->{jql};
}

sub viewUrl {
    my $self = shift;
    return $self->{_content}->{viewUrl};
}

sub columns {
    my $self = shift;
    my $key = $self->key();
    my $columns = $self->rest("GET", "filter/$key/columns");
    return $columns;
}

1;

__END__
