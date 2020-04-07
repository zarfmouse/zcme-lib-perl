# -*- Perl -*-

use strict;
use warnings;

package ZCME::DB;

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
    if(defined($self->{base_url}) && $self->{base_url} =~ m[^(.+)://([^\/\:]+)(?:\:([0-9]+))?/(.+)$]) {
	($self->{driver}, $self->{hostname}, $self->{port}, $self->{database}) = ($1,$2,$3,$4);
    } else {
	foreach my $key (qw(database hostname port)) {
	    $self->{$key} = $secrets->get($key);
	}
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
    my $driver = $self->driver();
    my $host = $self->hostname();
    my $database = $self->database();
    my $port = $self->port();
    my $dsn = "DBI:$driver:host=$host";
    if(defined($database)) {
	$dsn .= ";database=$database";
    }
    if(defined($port)) {
	$dsn .= ";port=$port";
    }
    return $dsn;
}

sub database {
    my $self = shift;
    return $self->{database} || $ENV{MYSQL_DATABASE};
}

sub hostname {
    my $self = shift;
    return $self->{hostname} || $ENV{MYSQL_SERVICE_HOST};
}

sub driver {
    my $self = shift;
    return $self->{driver} || 'mysql';
}

sub port {
    my $self = shift;
    return $self->{port} || $ENV{MYSQL_SERVICE_PORT};
}

sub username { 
    my $self = shift;
    return $self->{username} || $ENV{MYSQL_USER}; 
}

sub password { 
    my $self = shift;
    return $self->{password} || $ENV{MYSQL_PASSWORD};
}

sub disconnect {
    my $self = shift;
    $self->{dbh}->disconnect() if defined($self->{dbh});
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
    my $port = $self->port();
    my $hostname = $self->hostname();
    my $username = $self->username();
    my $database = $self->database();
    my $password  = $self->password();
    system("mysql -P $port -h $hostname -p$password -u $username $database");
    return $self;
}

1;

