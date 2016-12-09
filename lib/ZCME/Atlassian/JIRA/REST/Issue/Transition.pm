# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Issue::Transition;
use base qw(ZCME::REST::Object);
use Data::Dumper qw(Dumper);
use Carp qw(croak);

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $issue = shift;
    my $key_or_content = shift;

    die "Transitions must be associated with issues" unless(defined($issue) and ref($issue));
    $self->{_issue} = $issue;

    if(ref($key_or_content) eq 'HASH') {
	# Construct from an existing JSON blob.
	$self->{_content} = $key_or_content;
	$self->{_key} = $self->{_content}->{id};
    } elsif(defined($key_or_content)) {
	$self->{_key} = $key_or_content;
	$self->refresh();
    } else {
	die "Invalid key or content: $key_or_content";
    }

    return $self;
}

sub key { 
    my $self = shift;
    return $self->{_key};
}

sub refresh {
    my $self = shift;
    my $issue_key = $self->{_issue}->key();
    $self->{_content} = $self->rest('GET', ["issue/$issue_key/transitions", {transitionId => $self->{_key}}])->[0];
}

sub name {
    my $self = shift;
    return $self->{_content}->{name};
}

sub to {
    my $self = shift;
    return $self->{_content}->{to}->{name};
}

sub hasScreen {
    my $self = shift;
    return $self->{_content}->{hasScreen};
}

sub meta {
    my $self = shift;
    unless(exists($self->{meta})) {
	my $pkg = __PACKAGE__;
	$pkg =~ s/::Transition$/::Meta/;
	$self->{meta} = $pkg->new($self->{_rest}, $self->{_content});
    }
    return $self->{meta};
}

sub fieldval {
    my $self = shift;
    return $self->meta()->fieldval(@_);
}

sub allowed {
    my $self = shift;
    return $self->meta()->allowed(@_);
}

sub fieldkey {
    my $self = shift;
    return $self->meta()->fieldkey(@_);
}

sub field_exists {
    my $self = shift;
    return $self->meta()->field_exists(@_);
}

sub set {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $val = $self->fieldval($key, shift);
    if(defined($val)) {
	$self->{_post}->{fields}->{$key} = $val;
    }
}

sub comment {
    my $self = shift;
    my $body = shift;
    my $visibility = shift;

    (not exists($self->{_post}->{update}->{comment})) || croak "Comment already set.";
    defined($body) || croak "Missing body.";

    my $comment = $self->{_issue}->new_comment();
    $comment->body($body);
    if(defined($visibility)) {
	(ref($visibility) eq 'ARRAY') || croak "visibility arg must be array ref";
	(scalar(@$visibility) == 2) || croak "type and value required for visibility";
	$comment->visibility($visibility->[0], $visibility->[1]);
    }
    $self->{_post}->{update}->{comment} = [ { 'add' => $comment->{_content} } ];
}

sub do {
    my $self = shift;
    (not $self->{_done}) || croak "Can't redo a transition.";

    $self->{_post}->{transition}->{id} = $self->key();

    my $issue_key = $self->{_issue}->key();
    $self->rest('POST', "issue/$issue_key/transitions", $self->{_post});
    $self->{_issue}->refresh();
    $self->{_done} = 1;
}

1;

__END__


