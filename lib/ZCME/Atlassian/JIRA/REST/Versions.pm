# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Versions;
use base qw(ZCME::REST::Object);
use ZCME::Atlassian::JIRA::REST::Version;
use Scalar::Util qw(looks_like_number);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak);

our $VERBOSE = 0;

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $key_or_content = shift;
    if(ref($key_or_content) eq 'ARRAY') {
	$self->{_content} = $key_or_content;
	$self->{_key} = $self->{_content}->[0]->{projectId};
	$self->_bless_content();
    } else {
	$self->{_key} = $key_or_content;
	$self->refresh();
    }
    $self->reset();
    return $self;
}

sub key { 
    my $self = shift;
    return $self->{_key};
}

sub refresh {
    my $self = shift;
    $self->{_content} = $self->rest('GET', "project/$self->{_key}/versions");
    $self->_bless_content();
}

sub _bless_content {
    my $self = shift;
    my $pkg = __PACKAGE__;
    $pkg =~ s/::Versions$//;
    @{$self->{_content}} = map { "${pkg}::Version"->new($self->rest_object(), $_) } @{$self->{_content}};
}

sub index {
    my $self = shift;
    my $n = shift;
    return $self->{_content}->[$n];
}

sub find {
    my $self = shift;
    my $name = shift;
    for(my $i=0;$i<scalar(@{$self->{_content}});$i++) {
	my $version = $self->index($i);
	if($version->name() eq $name) {
	    $self->{i} = $i;
	    return $version;
	}
    }
}

sub current {
    my $self = shift;
    return $self->index($self->{i});
}

sub reset {
    my $self = shift;
    $self->{i} = 0;
}

sub next {
    my $self = shift;
    my $retval = $self->current();
    $self->{i}++;
    return $retval;
}

sub prev {
    my $self = shift;
    $self->{i}--;
    return $self->current();
}

1;

__END__
