# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Group;
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
	$self->{_key} = $self->{_content}->{name};
    } else {
	$self->{_key} = $key_or_content;
	$self->refresh();
    }
    $self->{i} = 0;
    return $self;
}

sub key { 
    my $self = shift;
    return $self->{_key};
}

sub refresh {
    my $self = shift;
    my $index = shift || 0;
    my $expand = 'users';
    if($index > 0) {
	my $last = $index+$self->maxResults()-1;
	$expand.="[${index}:${last}]";
    }
    $self->{_content} = $self->rest('GET', ["group", { groupname => $self->{_key}, expand => $expand }]);
}

sub name {
    my $self = shift;
    return $self->{_content}->{name};
}

#
# User Iterator Methods
#

sub total {
    my $self = shift;
    return $self->{_content}->{users}->{size};
}

sub startAt { 
    my $self = shift;
    return $self->{_content}->{users}->{'start-index'};
}

sub endAt { 
    my $self = shift;
    return $self->{_content}->{users}->{'end-index'};
}

sub maxResults {
    my $self = shift;
    return $self->{_content}->{users}->{'max-results'};
}

sub _user_package {
    my $self = shift;
    my $pkg = __PACKAGE__;
    $pkg =~ s/\:\:Group$/::User/;
    return $pkg;
}

sub index {
    my $self = shift;
    my $i = shift;
    $i >= 0 || return undef;
    $i < $self->total() || return undef;

    if($i < $self->startAt() or $i > $self->endAt()) {
	$self->refresh($i);
    }
    my $rest_data = $self->{_content}->{users}->{items}->[$i - $self->startAt()];
    if(defined($rest_data)) {
	return $self->_user_package()->new($self->rest_object(), $rest_data);
    } else {
	return undef;
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


1;

__END__
