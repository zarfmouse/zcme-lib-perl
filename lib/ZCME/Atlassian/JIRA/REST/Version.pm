# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Version;
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
    $self->{_content} = $self->rest('GET', "version/$self->{_key}");
}

sub name {
    my $self = shift;
    return $self->{_content}->{name};
}

sub release_date {
    my $self = shift;
    return $self->{_content}->{releaseDate};
}

sub is_kanban {
    my $self = shift;

    my $name = $self->name();
    if($name =~ /^[0-9]+\.[0-9]+\.5$/) {
	return 1;
    } else {
	return 0;
    }
}

1;

__END__
