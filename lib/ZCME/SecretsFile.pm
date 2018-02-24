use strict;
use warnings;
use utf8;

package ZCME::SecretsFile;
use Carp qw(croak);
use Storable qw(lock_store lock_retrieve);
use File::Basename qw(basename);
use IO::File;

sub new {
    my $class = shift;
    my %params = @_;
    my $self = bless {}, (ref($class)||$class);
    
    my $filename = $params{-filename} || croak "-filename required";
    my $dir = $params{-dir} || $ENV{'ZCME_SECRETS_DIR'} || $ENV{'HOME'} || croak "-dir or HOME required";
    $self->{_account} = $params{-account} || $ENV{'ZCME_SECRETS_DEFAULT_ACCOUNT'};

    my $file = $self->{_file} = "$dir/$filename";
    if(-d $file) {
	$self->{_data} = {};
	&_add_keys_from_dir_to_data($self->{_data}, $file);
	chmod(0700, $file);
    } elsif(-f $file) {
	$self->{_data} = lock_retrieve($file);
	($self->{_data} and ref($self->{_data}) eq 'HASH') 
	    or die "Invalid secrets file: $file";
	chmod(0600, $file);
    } else {
	$self->{_data} = { };
	lock_store($self->{_data} => $file);
	chmod(0600, $file);
    }


    $self->{_account} ||= $self->{_data}->{default_account};
    unless(defined($self->{_account})) {
	croak "-account or default_account required";
    }
    return $self;
}

sub _add_keys_from_dir_to_data {
    my $data = shift;
    my $dir = shift;
    foreach my $file (glob("$dir/*")) {
	my $key = basename($file);
	if(-d $file) {
	    $data->{$key} = {};
	    &_add_keys_from_dir_to_data($data->{$key}, $file);
	} elsif(-f $file) {
	    my $val = join("\n", IO::File->new($file)->getlines());
	    $data->{$key} = $val;
	} else {
	    die "Unexpected file type for $file.";
	}
    }
}

sub account {
    my $self = shift;
    my $account = shift;
    if(defined($account)) {
	$self->{_account} = $account;
    }
    return $self->{_account};
}

sub set {
    my $self = shift;
    my $key = shift;
    my $val = shift;
    $self->{_data}->{$self->account()}->{$key} = $val;
    if(-f $self->{_file}) {
	lock_store($self->{_data} => $self->{_file});
    } elsif(-d $self->{_file}) {
	die "Directory type SecretsFiles are read-only.";
    }
}

sub get {
    my $self = shift;
    my $key = shift;
    return $self->{_data}->{$self->account()}->{$key};
}

1;
__END__
