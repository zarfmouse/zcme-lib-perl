# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Issue::Comment;
use base qw(ZCME::REST::Object);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak);

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $issue_key = shift;
    my $key_or_content = shift;

    die "Comments must be associated with issues" unless(defined($issue_key) and length($issue_key));
    $self->{_issue_key} = $issue_key;

    if(ref($key_or_content) eq 'HASH') {
	# Construct from an existing JSON blob.
	$self->{_content} = $key_or_content;
	$self->{_key} = $self->{_content}->{id};
    } elsif(defined($key_or_content)) {
	$self->{_key} = $key_or_content;
	$self->refresh();
    } else {
	$self->{_new} = 1;
    }

    return $self;
}

sub key { 
    my $self = shift;
    return $self->{_key};
}

sub refresh {
    my $self = shift;
    $self->{_content} = $self->rest('GET', "issue/$self->{_issue_key}/comment/$self->{_key}");
}

sub delete {
    my $self = shift;
    $self->rest('DELETE', "issue/$self->{_issue_key}/comment/$self->{_key}");
}

sub save {
    my $self = shift;
    if($self->{_new}) {
	$self->{_content} = $self->rest('POST', "issue/$self->{_issue_key}/comment", $self->{_content});
	$self->{_key} = $self->{_content}->{id};
	delete $self->{_new};
    } else {
	$self->{_content} = $self->rest('PUT', "issue/$self->{_issue_key}/comment/$self->{_key}", $self->{_content});	
    }
}

sub body {
    my $self = shift;
    my $body = shift;
    if(defined($body)) {
	$self->{_content}->{body} = $body;
    } else {
	return $self->{_content}->{body};
    }
}

sub visibility {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    if(defined($type)) {
	$self->{_content}->{visibility} = {
	    type => $type,
	    value => $value
	};
    } else {
	return ($self->{_content}->{visibility}->{type}, $self->{_content}->{visibility}->{value});
    }
}

sub author {
    my $self = shift;
    return $self->rest_object()->get_user($self->{_content}->{author});
}

sub updateAuthor {
    my $self = shift;
    return $self->rest_object()->get_user($self->{_content}->{updateAuthor});
}

sub updated { 
    my $self = shift;
    return ZCME::Date->new($self->{_content}->{updated});
}

sub created { 
    my $self = shift;
    return ZCME::Date->new($self->{_content}->{created});
}


1;

__END__


