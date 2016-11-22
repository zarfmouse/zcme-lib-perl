# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Issue::Worklog;
use base qw(ZCME::REST::Object);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak);

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $issue_key = shift;
    my $key_or_content = shift;

    die "Worklogs must be associated with issues" unless(defined($issue_key) and length($issue_key));
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
    $self->{_content} = $self->rest('GET', "issue/$self->{_issue_key}/worklog/$self->{_key}");
}

sub delete {
    my $self = shift;
    $self->rest('DELETE', "issue/$self->{_issue_key}/worklog/$self->{_key}");
}

sub save {
    my $self = shift;
    if($self->{_new}) {
	$self->{_content} = $self->rest('POST', "issue/$self->{_issue_key}/worklog", $self->{_content});
	$self->{_key} = $self->{_content}->{id};
    } else {
	$self->{_content} = $self->rest('PUT', "issue/$self->{_issue_key}/worklog/$self->{_key}", $self->{_content});	
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
    # TODO: Add Update
    return $self->rest_object()->get_user($self->{_content}->{author});
}

sub updateAuthor {
    my $self = shift;
    # TODO: Add Update
    return $self->rest_object()->get_user($self->{_content}->{updateAuthor});
}

sub started { 
    my $self = shift;
    # TODO: Add Update
    return ZCME::Date->new($self->{_content}->{started});
}

sub updated { 
    my $self = shift;
    # TODO: Add Update
    return ZCME::Date->new($self->{_content}->{updated});
}

sub created { 
    my $self = shift;
    # TODO: Add Update
    return ZCME::Date->new($self->{_content}->{created});
}

sub seconds {
    my $self = shift;
    # TODO: Add Update
    return $self->{_content}->{timeSpentSeconds};
}

sub hours {
    my $self = shift;
    return $self->seconds() / (60*60*1.0);
}

sub timeSpent {
    my $self = shift;
    # TODO: Add Update
    return $self->{_content}->{timeSpent};
}

sub comment {
    my $self = shift;
    # TODO: Add Update
    return $self->{_content}->{comment};    
}



1;

__END__


