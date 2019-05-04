use 5.016;
use warnings;
use IO::Socket;

sub get {
	return "";
}

sub put {
	return "";
}

sub del {
	return "";
}

sub err {
	my $code = shift;
	return "";
}

# Usage: $0 -h <ip> -p <port> -d <root directory>
# обработка аргументов командной строки
my $root = "/home/andrey/server-data";
my $ip = "127.0.0.1";
my $port = "11111";

# TCP layer
my $lsocket = IO::Socket::INET->new(
	"PeerAddr" => $ip,
	"PeerPort" => $port,
	"Proto"    => "tcp",
	"Type"     => SOCK_STREAM,
) or die "Can't connect to server: $!";
listen $lsocket, SOMAXCONN or die $!;
while (accept my $csocket, $lsocket) {
	my $request = <$csocket>;
	# HTTP layer
	my ($method, $path) = $request =~ /^([A-Z]+)\s\/([^\s]+)\sHTTP/;
	if (lc $method eq "get") {
		syswrite $csocket, get $path;
	} elsif (lc $method eq "put") {
		syswrite $csocket, put $path;
	} elsif (lc $method eq "delete") {
		syswrite $csocket, del $path;
	} else {
		syswrite $csocket, err "415 Not allowed";
	}
	close $csocket;
}
