# -*- Perl -*-

use strict;
use warnings;

package ZCME::LMS::DB;

use DBI;
use Data::Dumper;
use IPC::Cmd qw(can_run);

use ZCME::SecretsFile;
use ZCME::Tunnel;

sub new {
    my $class = shift;
    my %param = @_;
    my $self = bless {}, (ref($class)||$class);

    my $secrets = ZCME::SecretsFile->new(-filename => '.db_auth',
					 -account => $param{-account});    
    $self->{username} = $secrets->get('username');
    $self->{password} = $secrets->get('password');
    $self->{base_url} = $secrets->get('base_url');
    if($self->{base_url} =~ m[^(.+)://([^\/]+)(?:\:([0-9]+))?/(.+)$]) {
	($self->{driver}, $self->{hostname}, $self->{port}, $self->{database}) = ($1,$2,$3,$4);
    } else {
	die "Malformed DB URL: $self->{base_url}.";
    }

    if($param{'-tunnel'}) {
	my $localport = int(9000 + ($$ % 10000));
	$self->{tunnel} = ZCME::Tunnel->new(
	    -hostname => $param{-tunnel},
	    -port => $localport,
	    -host => $self->{hostname},
	    -hostport => $self->{port},
	    );
	$self->{port} = $localport;
	$self->{hostname} = '127.0.0.1';
    }

    return $self;
}

sub dsn {
    my $self = shift;
    my $dsn = "DBI:$self->{driver}:host=$self->{hostname}";
    if($self->{database}) {
	$dsn .= ";database=$self->{database}";
    }
    if($self->{port}) {
	$dsn .= ";port=$self->{port}";
    }
    return $dsn;
}

sub database {
    my $self = shift;
    return $self->{database};
}

sub hostname {
    my $self = shift;
    return $self->{hostname};
}

sub driver {
    my $self = shift;
    return $self->{driver};
}

sub port {
    my $self = shift;
    return $self->{port};
}

sub username { 
    my $self = shift;
    return $self->{username};
}

sub password { 
    my $self = shift;
    return $self->{password};
}

sub disconnect {
    my $self = shift;
    $self->{dbh} = undef;
    $self->{drh} = undef;
    return $self;
}

sub dbh {
    my $self=shift;
    unless(defined($self->{dbh})) {
	$self->{dbh} = DBI->connect($self->dsn(), 
				    $self->username(), 
				    $self->password(), 
				    { RaiseError => 1,
				      AutoCommit => 1,
				      mysql_enable_utf8 => 1});
	$self->{drh} = DBI->install_driver($self->driver());
    }
    return $self->{dbh};
}

sub launch_mysql {
    my $self = shift;
    system("mysql -P $self->{port} -h $self->{hostname} -p$self->{password} -u $self->{username} $self->{database}");
    return $self;
}

1;

