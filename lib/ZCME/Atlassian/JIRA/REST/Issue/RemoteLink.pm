# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Issue::RemoteLink;
use base qw(ZCME::REST::Object);
use Data::Dumper qw(Dumper);
use Carp qw(carp croak);

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $issue_key = shift;
    my $key_or_content = shift;
    
    die "RemoteLinks must be associated with issues" unless(defined($issue_key) and length($issue_key));
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
    $self->{_content} = $self->rest('GET', "issue/$self->{_issue_key}/remotelink/$self->{_key}");
}

sub delete {
    my $self = shift;
    $self->rest('DELETE', "issue/$self->{_issue_key}/remotelink/$self->{_key}");
}

sub save {
    my $self = shift;
    if($self->{_new}) {
	$self->{_content} = $self->rest('POST', "issue/$self->{_issue_key}/remotelink", $self->{_content});
	$self->{_key} = $self->{_content}->{id};
	delete $self->{_new};
    } else {
	$self->{_content} = $self->rest('PUT', "issue/$self->{_issue_key}/remotelink/$self->{_key}", $self->{_content});	
    }
}

sub globalId {
    my $self = shift;
    my $val = shift;
    if(defined($val)) {
	$self->{_content}->{globalId} = $val;
    } else {
	return $self->{_content}->{globalId};
    }
}

sub application {
    my $self = shift;
    my $type = shift;
    my $name = shift;
    if(defined($type)) {
	$self->{_content}->{application} = {
	    type => $type,
	    name => $name,
	};
    } else {
	return ($self->{_content}->{application}->{type}, $self->{_content}->{application}->{name});
    }
}

sub relationship {
    my $self = shift;
    my $val = shift;
    if(defined($val)) {
	$self->{_content}->{relationship} = $val;
    } else {
	return $self->{_content}->{relationship};
    }
}

sub url {
    my $self = shift;
    my $val = shift;
    if(defined($val)) {
	$self->{_content}->{object}->{url} = $val;
    } else {
	return $self->{_content}->{object}->{url};
    }
}

sub title {
    my $self = shift;
    my $val = shift;
    if(defined($val)) {
	$self->{_content}->{object}->{title} = $val;
    } else {
	return 	$self->{_content}->{object}->{title};
    }
}

sub summary {
    my $self = shift;
    my $val = shift;
    if(defined($val)) {
	$self->{_content}->{object}->{summary} = $val;
    } else {
	return 	$self->{_content}->{object}->{summary};
    }
}

# TODO: Status, Icons

1;

__END__

https://developer.atlassian.com/jiradev/jira-platform/guides/other/guide-jira-remote-issue-links/jira-rest-api-for-remote-issue-links

{
    "globalId": "system=http://www.mycompany.com/support&id=1",
    "application": {                                            
         "type":"com.acme.tracker",                      
         "name":"My Acme Tracker"
    },
    "relationship":"causes",                           
    "object": {                                            
        "url":"http://www.mycompany.com/support?id=1",     
        "title":"TSTSUP-111",                             
        "summary":"Crazy customer support issue",        
        "icon": {                                         
            "url16x16":"http://www.openwebgraphics.com/resources/data/3321/16x16_voice-support.png",    
            "title":"Support Ticket"     
        },
        "status": {                                           
            "resolved": true,                                          
            "icon": {                                                       
                "url16x16":"http://www.openwebgraphics.com/resources/data/47/accept.png",
                "title":"Case Closed",                                     
                "link":"http://www.mycompany.com/support?id=1&details=closed"
            }
        }
    }
}
