# -*- Perl -*-

use strict;
use warnings;
use v5.10;

package ZCME::Atlassian::JIRA::REST::Issue;
use base qw(ZCME::REST::Object);
use Scalar::Util qw(looks_like_number);
use JSON qw(encode_json decode_json);
use Carp qw(carp croak);
use Storable qw(lock_store lock_retrieve);
use File::Path qw(make_path);
use Data::Dumper qw(Dumper);

use ZCME::Atlassian::JIRA::REST::Issue::Meta;
use ZCME::Atlassian::JIRA::REST::Issue::Attachment;
use ZCME::Atlassian::JIRA::REST::Issue::Comment;
use ZCME::Atlassian::JIRA::REST::Issue::RemoteLink;
use ZCME::Atlassian::JIRA::REST::Issue::Worklog;
use ZCME::Atlassian::JIRA::REST::Issue::Transition;

our $VERBOSE = 0;
our $DRY_RUN = 0;

sub new {
    my $class = shift;
    my $self=$class->SUPER::new(shift);
    my $key_or_content = shift;
    $self->{_update} = {};
    $self->{_createLinks} = [];
    $self->{_deleteLinks} = [];
    if(ref($key_or_content) eq 'HASH') {
	# Construct from an existing JSON blob.
	$self->{_content} = $key_or_content;
	$self->{_key} = $self->{_content}->{key};
    } else {
	$self->{_key} = $key_or_content;
	$self->refresh();
    }

    return $self;
}

sub unrest {
    my $self = shift;
    if(defined($self->{meta})) {
	$self->{meta}->unrest();
    }
    if(defined($self->{_subtasks})) {
	foreach my $subtask (@{$self->{_subtasks}}) {
	    $subtask->unrest();
	}
    }
    $self->SUPER::unrest();
}

sub rerest {
    my $self = shift;
    my $rest = shift;
    if(defined($self->{meta})) {
	$self->{meta}->rerest($rest);
    }
    if(defined($self->{_subtasks})) {
	foreach my $subtask (@{$self->{_subtasks}}) {
	    $subtask->rerest($rest);
	}
    }
    $self->SUPER::rerest($rest);
}

sub cache_file {
    my $class_or_self = shift;
    my $key;
    my $rest;
    if(ref($class_or_self)) {
	$key = $class_or_self->key();
	$rest = $class_or_self->rest_object();
    } else {
	$key = shift;
	$rest = shift;
    }
    my $cache_dir = $rest->cache_dir();
    return undef unless (defined($cache_dir));
    my($sub1,$sub2,$sub3) = ($key =~ m/^((([^\-]+)-.).?.?)/);
    my $dir = "$cache_dir/issues/$sub3/$sub2/$sub1";
    unless(-d $dir) {
	make_path($dir);
    }
    return "$dir/$key.storable";
}

sub cache_retrieve {
    my $class = shift;
    my $rest = shift;
    my $key = shift;
    my $updated = shift;

    my $cache_file = $class->cache_file($key, $rest);
    if(defined($cache_file) and -f $cache_file) {
	my $cache_obj = lock_retrieve($cache_file);
	$cache_obj->rerest($rest);
	# TODO: Consider a TTL value or using the file timestamp
	# rather than the updated value from the file.
	if($cache_obj->get('updated') ge $updated) {
	    return $cache_obj;
	}
    }
    return $class->new($rest, $key);
}

sub cache_store {
    my $self = shift;
    my $cache_file = $self->cache_file();
    defined($cache_file) or return; # Fail silently if cache is not configured. 
    die "Must save changes before caching." if $self->is_dirty();
    my $rest = $self->rest_object();
    $self->unrest();
    lock_store($self => $cache_file);
    $self->rerest($rest);
}

sub key { 
    my $self = shift;
    return $self->{_key};
}

sub _flatten {
    my @flat = ();
    foreach my $val (@_) {
	if(ref($val) eq 'ARRAY') {
	    push(@flat, _flatten(@$val));
	} else {
	    push(@flat, $val);
	}
    }
    return @flat;
}

sub _comma {
    return join(',', _flatten(shift));
}

sub expand {
    my $self = shift;
    my $expand = shift;
    unless(exists $self->{_content}->{$expand}) {
	my $resp = $self->rest('GET', ["issue/$self->{_key}", { expand => $expand}]);
	if(ref($resp) eq 'HASH') {
	    $self->{_content}->{$expand} = $resp->{$expand};
	    $self->cache_store();
	} else {
	    die "Invalid response from REST call while expanding $expand on $self->{_key}.";
	}
    }
}

sub refresh {
    my $self = shift;
    $self->{_content} = $self->rest('GET', "issue/$self->{_key}");
    delete $self->{_subtasks};    
    delete $self->{_parent};
    $self->{_update} = {};
    $self->{_createLinks} = [];
    $self->{_deleteLinks} = [];
    $self->cache_store();
}

sub _valname {
    my $val = shift;
    my $type = ref($val);
    if(not $type) {
	return $val;
    } elsif($type eq 'HASH') {
	foreach my $key (qw(key value name)) {
	    if(exists($val->{$key})) {
		return $val->{$key};
	    }
	}
    } else {
	croak "Don't know how to handle $type for ".encode_json($val);
    }
}

#
# EDITMETA
#

sub reset_meta { 
    my $self = shift;
    delete $self->{meta};
}

sub editmeta {
    my $self = shift;
    unless(exists $self->{meta}) {
	$self->expand('editmeta');
	my $meta_or_key = exists($self->{_content}->{editmeta}) ? $self->{_content}->{editmeta} : $self->key();
	$self->{meta} = (__PACKAGE__.'::Meta')->new($self->{_rest}, $meta_or_key);
    }
    return $self->{meta};
}

sub fieldval {
    my $self = shift;
    return $self->editmeta()->fieldval(@_);
}

sub allowed {
    my $self = shift;
    return $self->editmeta()->allowed(@_);
}

sub fieldkey {
    my $self = shift;
    my $field_name = shift;

    $self->expand('names');
    foreach my $key (keys %{$self->{_content}->{names}}) {
	if($self->{_content}->{names}->{$key} eq $field_name) {
	    return $key;
	}
    }

    my $field_key = $self->editmeta()->fieldkey($field_name);
    return $field_key if (defined($field_key) && ($field_key ne $field_name));
    $field_key = $self->{_rest}->fieldkey($field_name);
    return $field_key if (defined($field_key) && ($field_key ne $field_name));
    return $field_name;
}

#
# READ
#

# Get the value of a field by field name.
sub get {
    my $self = shift;
    my $name = shift;
    my $section = shift || 'fields';
    my $key = $self->fieldkey($name);

    my $issue = $self->{_content};
    if(exists $issue->{$section}->{$key}) {
	my $val = $issue->{$section}->{$key};
	if(ref($val) eq 'ARRAY') {
	    return [ map { _valname($_) } @$val ];
	} else {
	    return _valname($val);
	}
    } elsif(exists $issue->{$key}) {
	return $issue->{$key};
    } else {
	carp "Field $name not found in $issue->{key}." if $VERBOSE; #TODO: This will be over-triggered on issue creation.
	return undef;
    }
}

# Get the value of a field at a given date time.
# Only supports scalar fields and some fields will give incorrect
# results like "Rank" because actual changes aren't stores in the
# History.
sub get_last_value_on_date {
    my $self = shift;
    my $name = shift;
    my $date = ZCME::Date->new(shift)->mysql_date();

    my $orig_val = $self->get($name);
    if(ref($orig_val)) {
	die "Only scalar fields are supported by this function.";
    }

    my $create_date = $self->get_date('created')->mysql_date();
    if($date lt $create_date) {
	return undef;
    }

    my $val;
    foreach my $item ($self->changelog(-field => $name)) {
	my $change_date = $item->{date};
	if($change_date le $date) {
	    $val = $item->{toString};
	} elsif(not defined($val)) {
	    $val = $item->{fromString};
	    return $val;
	}
    }
    return defined($val) ? $val : $orig_val;
}

sub get_project_name {
    my $self = shift;
    return $self->{_content}->{fields}->{project}->{name};
}

sub get_rendered {
    my $self = shift;
    my $name = shift;
    $self->expand('renderedFields');
    return $self->get($name, 'renderedFields') || $self->get($name);
}

sub get_attachments {
    my $self = shift;
    my $attachments = $self->{_content}->{fields}->{attachment};
    if(defined($attachments)) {
	my @retval = map { (__PACKAGE__.'::Attachment')->new($self->{_rest}, $_) } @$attachments; 
	return \@retval;
    } else {
	return [];
    }
}

sub upload_attachment {
    my $self = shift;
    my $filename = shift;
    my $username = $self->rest_object()->username();
    my $password = $self->rest_object()->password();
    my $base_url = $self->rest_object()->base_url();
    my $key = $self->key();
    
    # FIXES: bug_attachment_with_comma.t
    my $old_filename = $filename;
    $filename=~s/,/_/g;
    $filename=~s/;/_/g;
    unless($DRY_RUN or $old_filename eq $filename) {
	rename($old_filename, $filename);
    }

    my $cmd = qq(curl -s -u "$username:$password" -X POST -H "X-Atlassian-Token: nocheck" -F "file=\@$filename" $base_url/issue/$key/attachments);
    warn "Running: $cmd\n" if $VERBOSE;
    unless($DRY_RUN) {
	my $json_text = `$cmd`;
	die "FAILED to upload $filename to $key.\n" unless(length($json_text) > 0);
	my $attachments;
	eval {
	    $attachments = decode_json($json_text);
	};
	if($@) {
	    die "Attachment upload failed:\n$json_text\n";
	}
	# FIXES: bug_attachment_with_comma.t (cleanup)	
	unless($old_filename eq $filename) {
	    rename($filename, $old_filename);
	}
	unless(ref($attachments) eq 'ARRAY' and scalar(@$attachments) == 1) {
	    die "Unexpected response: ".encode_json($attachments);
	}
	push(@{$self->{_content}->{fields}->{attachment}}, $attachments->[0]);
	return (__PACKAGE__.'::Attachment')->new($self->{_rest}, $attachments->[0]);
    } else {
	return undef;
    }
}

sub new_comment {
    my $self = shift;
    return (__PACKAGE__.'::Comment')->new($self->{_rest}, $self->key());
}

# NOTE: There's meta data in the comments hash that makes it looks
# like it might be paginated but it is not. If Atlassian ever
# implements pagination then we'll need to deprecate this arrayref
# returning function and implement an iterator returning function.
# https://answers.atlassian.com/questions/16876471/rest-api-paging-on-comments
sub get_comments {
    my $self = shift;
    my $comments = $self->{_content}->{fields}->{comment}->{comments};
    if(defined($comments)) {
	my @retval = map { (__PACKAGE__.'::Comment')->new($self->{_rest}, $self->key(), $_) } @$comments; 
	return \@retval;
    } else {
	return [];
    }
}

sub get_transitions {
    my $self = shift;

    my $transitions = $self->{_content}->{transitions};
    unless(defined($transitions)) {
	$transitions = 
	    $self->{_content}->{transitions} = 
	    $self->rest('GET', ["issue/$self->{_key}/transitions", 
				{expand => "transitions.fields"}])->{transitions};
	$self->cache_store();
    }

    if(defined($transitions)) {
	my @retval = map { (__PACKAGE__.'::Transition')->new($self->{_rest}, $self, $_) } @$transitions;
	return \@retval;
    } else {
	return [];
    }
}

sub get_transition {
    my $self = shift;
    my %params = @_;
    
    my $test = sub {
	my $item = shift;
	my $found = 1;
	$found &&= $item->key() eq $params{-id} if(exists $params{-id});
	$found &&= $item->name() =~ m/^\Q$params{-name}/ if(exists $params{-name});
	$found &&= $item->to() eq $params{-to} if(exists $params{-to});
	return $found;
    };
    
    my @hits = grep {$test->($_)} @{$self->get_transitions()};
    if(scalar(@hits) == 1) {
	return $hits[0];
    } else {
	die "Invalid transition specification: ".Dumper(\%params);
    }
}


sub new_remote_link {
    my $self = shift;
    return (__PACKAGE__.'::RemoteLink')->new($self->{_rest}, $self->key());
}

sub get_remote_links {
    my $self = shift;
    my $remotelinks = $self->rest('GET', "issue/$self->{_key}/remotelink");
    if(defined($remotelinks)) {
	my @retval = map { (__PACKAGE__.'::RemoteLink')->new($self->{_rest}, $self->key(), $_) } @$remotelinks; 
	return \@retval;
    } else {
	return [];
    }
}

sub get_worklogs {
    my $self = shift;

    my $worklogs = $self->{_content}->{worklogs};
    unless(defined($worklogs)) {
	$worklogs = $self->{_content}->{worklogs} = $self->rest('GET', "issue/$self->{_key}/worklog")->{worklogs};
	$self->cache_store();
    }

    if(defined($worklogs)) {
	my @retval = map { (__PACKAGE__.'::Worklog')->new($self->{_rest}, $self->key(), $_) } @$worklogs;
	return \@retval;
    } else {
	return [];
    }
}

# Get the value of a field by field name as a Date object.
sub get_date {
    my $self = shift;
    my $name = shift;
    my $val = $self->get($name);
    return undef unless defined $val;
    if(ref($val) eq 'ARRAY') {
	return [ map { ZCME::Date->new($_) } @$val ];
    } else {
	return ZCME::Date->new($val);
    }
}

# Get the value of a field by field name as a User object.
sub get_user {
    my $self = shift;
    my $name = shift;
    my $key = $self->fieldkey($name);

    my $issue = $self->{_content};
    if(exists $issue->{fields}->{$key}) {
	my $val = $issue->{fields}->{$key};
	if(ref($val) eq 'ARRAY') {
	    return [ map { $self->{_rest}->get_user($_) } @$val ];
	} else {
	    return $self->{_rest}->get_user($val);
	}
    } else {
	carp "Field $name not found in $issue->{key}." if $VERBOSE;
	return undef;
    }
}

sub browse_url {
    my $self = shift;
    return $self->rest_object()->server_url()."/browse/".$self->key();
}

sub _eq {
    my ($a,$b) = (shift,shift);
    unless(defined($a) or defined($b)) {
	return 1;
    }
    unless(defined($a) and defined($b)) {
	return undef;
    }
    my $numeric = shift || (looks_like_number($a) && looks_like_number($b));
    if(ref($a) eq 'ARRAY' and ref($b) eq 'ARRAY') {
	my $equals = scalar(@$a) == scalar(@$b);
	if($equals) {
	    for(my $i=0;$i<scalar(@$a);$i++) {
		$equals &&= _eq($a->[$i], $b->[$i]);
	    }
	}
	return $equals;
    } else {
	$a = _valname($a);
	$b = _valname($b);
	return $numeric ? $a == $b : $a eq $b;
    }
}

sub exists {
    my $self = shift;
    my $field_name = shift;
    my $value = shift;

    my $field_values = $self->get($field_name);
    if(ref($field_values) eq 'ARRAY') {
	foreach my $field_value (@$field_values) {
	    _eq($field_value, $value) and return 1;
	}
    } else {
	return _eq($field_values, $value);
    }
}

sub field_exists {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    return exists($self->{_content}->{fields}->{$key}) || exists($self->{_content}->{$key});
}

#
# CREATE/UPDATE
#

sub set {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $val = $self->fieldval($key, shift);
    my $oldval = $self->get($key);
    unless(_eq($val, $oldval)) {
	push(@{$self->{_update}->{$key}}, { 'set' => $val });
    }
}

sub add {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $val = $self->fieldval($key, shift);
    unless($self->exists($key => $val)) {
	push(@{$self->{_update}->{$key}}, { 'add' => $val });
    }
}

sub remove {
    my $self = shift;
    my $key = $self->fieldkey(shift);
    my $val = $self->fieldval($key, shift);
    if($self->exists($key => $val)) {
	push(@{$self->{_update}->{$key}}, { 'remove' => $val });
    }
}

sub edit {
    my $self = shift;
    croak "edit operation not yet implemented.";
}

sub save {
    my $self = shift;
    my $refresh = 0;
    return undef unless $self->is_dirty();
    if($VERBOSE) {
	warn "Updating $self->{_key}...\n";
	warn "\tCreate Links: ".encode_json($self->{_createLinks}) if @{$self->{_createLinks}};
	warn "\tDelete Links: ".encode_json($self->{_deleteLinks}) if @{$self->{_deleteLinks}};
	warn "\tUpdates: \n" if keys %{$self->{_update}};
	foreach my $key (keys %{$self->{_update}}) {
	    my $val = $self->{_update}->{$key};
	    my $old = $self->get($key);
	    defined($old) or $old = 'undefined';
	    my $key_name = $self->{_rest}->fieldname($key);
	    warn "\t\t$key ($key_name): $old -> ".encode_json($val)."\n";
	}
    }
    if($DRY_RUN) {
	warn "Not updating $self->{_key} during dry run.\n";
	return undef;
    }
    foreach my $link (@{$self->{_createLinks}}) {
	eval {
	    $self->rest('POST', 'issueLink', $link);
	};
	if($@) {
	    if($@ =~ /404 Not Found/) {
		warn "Other issue doesn't exist when adding link to $self->{_key}: ".encode_json($link);
		# Don't die. This is ok.
	    } else {
		warn "Got a fatal error trying to add link to $self->{_key}:".encode_json($link);
		die $@;
	    }
	}
    }
    $self->{_createLinks} = [];
    foreach my $id (@{$self->{_deleteLinks}}) {
	$self->rest('DELETE', "issueLink/$id");
    }
    $self->{_deleteLinks} = [];
    if(keys %{$self->{_update}}) {
	eval {
	    $self->rest('PUT', "issue/$self->{_key}", { update => $self->{_update} });
	};
	if($@) {
	    warn "Got a fatal error trying to apply update to $self->{_key}.\n";
	    warn encode_json($self->{_update});
	    die $@;
	}
	$self->{_update} = {};	
    }
    $self->refresh();
    return $self;
}


sub is_dirty {
    my $self = shift;
    my $key = shift;
    if(defined($key)) {
	$key = $self->fieldkey($key);
	if(exists($self->{_update}) and exists($self->{_update}->{$key})) {
	    return 1;
	} else {
	    return undef;
	}
    } else {
	if(exists($self->{_update}) and keys %{$self->{_update}}) {
	    return 1;
	}
	if(exists($self->{_deleteLinks}) and scalar(@{$self->{_deleteLinks}})) {
	    return 1;
	}
	if(exists($self->{_createLinks}) and scalar(@{$self->{_createLinks}})) {
	    return 1;
	}
	return undef;
    }
}

#
# DELETE
#

sub delete {
    my $self = shift;
    my $deleteSubtasks = shift;
    my $url = "issue/$self->{_key}";
    if($deleteSubtasks) {
	$url = [$url, {deleteSubtasks => 'true'}];
    }
    $self->rest('DELETE', $url);
    $self->{_content} = undef;
    $self->{_update} = undef;
}

#
# Parents and Sub-Tasks
#

sub is_subtask {
    my $self = shift;
    return exists($self->{_content}->{fields}->{parent});
}

sub has_subtasks {
    my $self = shift;
    return ( 
	(exists $self->{_content}->{fields}->{subtasks})
	&&
	(scalar(@{$self->{_content}->{fields}->{subtasks}}) > 0)
	);
}

sub parent_key {
    my $self = shift;
    return undef unless $self->is_subtask();
    return $self->{_content}->{fields}->{parent}->{key};
}

sub parent {
    my $self = shift;
    return undef unless $self->is_subtask();
    return $self->new($self->{_rest}, $self->parent_key());
}

sub subtask_keys {
    my $self = shift;
    return undef if $self->is_subtask();
    return map {$_->{key}} @{$self->{_content}->{fields}->{subtasks}};
}

sub subtasks {
    my $self = shift;
    return undef if $self->is_subtask();
    unless(exists $self->{_subtasks}) {
	my $retval = [];
	my $key = $self->key();
	# Although we could consult {fields}->{subtasks}, it would
	# require us to fetch JSON for each subtask. Search() function
	# allows us to fetch them all at once and save network
	# queries.
	my $issues = $self->{_rest}->search(qq(parent = $key));
	while(my $issue = $issues->next()) {
	    push(@{$retval}, $issue);
	}
	$self->{_subtasks} = $retval;
    }
    return $self->{_subtasks};
}

#
# Issue Links
#

sub _key {
    my $key = shift;
    if(ref($key)) {
	$key = $key->key();
    }
    return $key;
}

sub link {
    my $self = shift;
    my $type = shift;
    my($linkname, $direction) = $self->{_rest}->link_type($type);
    my $key = _key(shift);

    my($inward,$outward);
    if($direction eq 'outward') {
	$inward = $self->key();
	$outward = $key;
    } else {
	$inward = $key;
	$outward = $self->key();
    }
    return undef if $self->link_exists($type, $key);
    push(@{$self->{_createLinks}}, 
	 { 
	     type => { name => $linkname },
	     inwardIssue => { key => $inward },
	     outwardIssue => { key => $outward },
	 });
    return 1;
}

sub link_exists {
    my $self = shift;
    my $type = shift;
    my $key = _key(shift);
    foreach my $haystack ($self->linked_issue_keys($type)) {
	return 1 if($haystack eq $key);
    }
    return undef;
}

sub unlink {
    my $self = shift;
    my $type = shift;
    my($linkname, $direction) = $self->{_rest}->link_type($type);
    my $key = _key(shift);
    return undef unless $self->link_exists($type, $key);
    foreach my $link (@{$self->{_content}->{fields}->{issuelinks}}) {
	if( ($link->{type}->{name} eq $linkname) and ($link->{"${direction}Issue"}->{key} eq $key) ) {
	    push(@{$self->{_deleteLinks}}, $link->{id});
	    return 1;
	}
    }
    return undef;
}

sub linked_issue_keys {
    my $self = shift;
    my $link_type = shift;
    my @keys;
    foreach my $link (@{$self->{_content}->{fields}->{issuelinks}}) {
	if($link->{type}->{inward} eq $link_type) {
	    if(exists($link->{inwardIssue})) {
		push(@keys, $link->{inwardIssue}->{key});
	    }
	} elsif($link->{type}->{outward} eq $link_type) {
	    if(exists($link->{outwardIssue})) {
		push(@keys, $link->{outwardIssue}->{key});
	    }
	}
    }
    return @keys;
}

sub linked_issues {
    my $self = shift;
    my $link_type = shift;
    my @keys = $self->linked_issue_keys($link_type);
    my @issues = ();
    if(scalar(@keys) > 0) {
	my $keys = join(',', @keys);
	my $issues = $self->{_rest}->search(qq(issue in ($keys)));
	while(my $issue = $issues->next()) {
	    push(@issues, $issue);
	}
    }
    return \@issues;
}


#
# CHANGELOG
#

sub date_field_changed {
    my $self = shift;
    my %params = @_;
    my @changes = $self->changelog(%params);
    my @retval = map {$_->{date}} @changes;
    if(exists $params{-index}) {
	return $retval[0];
    } else {
	return @retval;
    }
}

sub changelog {
    my $self = shift;
    my %params = @_;
    my $field = $params{-field};
    my $from = $params{-from};
    my $to = $params{-to};
    my $author = $params{-author};
    my $index = $params{-index};
    my $limit_date = $params{-date};
    my $max_date = $params{-maxdate};

    $self->expand('changelog');

    my $fieldname;
    my $fieldkey;
    if(defined($field)) {
	$fieldname = $self->{_rest}->fieldname($field);
	$fieldkey = $self->{_rest}->fieldkey($field);
    }

    my @retval = ();
    foreach my $history (@{$self->{_content}->{changelog}->{histories}}) {
	my ($date) = ($history->{created} =~ m/^([0-9]{4}-[0-9]{2}-[0-9]{2})/);
	next if defined($limit_date) && $date ne $limit_date;
	next if defined($max_date) && $date gt $max_date;
	next if defined($author) && $history->{author}->{name} ne $author;
	foreach my $item (@{$history->{items}}) {
	    next if defined($field) && 
		$item->{field} ne $fieldkey &&
		$item->{field} ne $fieldname;
	    next if defined($from) && 
		$item->{fromString} ne $from && 
		$item->{from} ne $from;
	    next if defined($to) && 
		$item->{toString} ne $to && 
		$item->{to} ne $to;
	    $item->{date} = $date;
	    $item->{dateTime} = $history->{created};
	    $item->{author} = $history->{author}->{name};
	    push(@retval, $item);
	}
    }
    if(defined($index)) {
	return $retval[$index];
    } else {
	return @retval;
    }
}

#
# LOCAL VALUES
#

sub set_computed {
    my $self = shift;
    my $key = shift or croak "Key required";
    my $val = shift;
    $self->{_computed}->{$key} = $val;
}

sub get_computed {
    my $self = shift;
    my $key = shift or croak "Key required";
    if(exists $self->{_computed}->{$key}) {
	return $self->{_computed}->{$key};
    } else {
	carp "No such computed key $key." if $VERBOSE;
    }
}

sub add_event {
    my $self = shift;
    my $key = shift or croak "Key required";
    my $date = shift;
    unless($date =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
	croak "Invalid date $date.";
    }
    $self->{_events}->{$key}->{$date} = 1;
}

sub get_event_keys {
    my $self = shift;
    return sort keys %{$self->{_events}};
}

sub get_event_dates {
    my $self = shift;
    my $key = shift or croak "Key required";
    if(exists $self->{_events}->{$key}) {
	return sort keys %{$self->{_events}->{$key}};
    } else {
	return ();
    }
}

sub clear_event_dates {
    my $self = shift;
    my $key = shift or croak "Key required";
    $self->{_events}->{$key}={};
}

1;

__END__
