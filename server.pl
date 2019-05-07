use 5.016;
use Socket ':all';
use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);

sub err {
	my $code = shift;
	my $data = shift;
	return "HTTP/1.1 $code\nContent-Length: " . length($data) . "\n\n$data\n";
}

sub get {
	my $path = shift;
	if (-d $path) {
		opendir my($dir), $path or return err "415 Not allowed", "Can't open a directory $path";
		my @lst = readdir $dir or  return err "415 Not allowed", "Can't read from a directory $path";
		my $data = "<!DOCTYPE html>\n<html><head><title>$path</title></head><body><ul>";
		for (@lst) {
			$data .= "<li>$_</li>" unless /\.\.?/;
		}
		$data .= "</ul></body></html>"; 
        closedir $dir or return err "415 Not allowed", "Can't close a directory $path";
		return "HTTP/1.1 200 OK\nContent-Length: ". length($data). "\n\n$data\n";
	}
	if (-f $path) {
		open my $fh, '<:raw', $path or return err "415 Not allowed", "Can't open a file $path";
		my $data = do { local $/; <$fh> };
		close $fh;
		return "HTTP/1.1 200 OK\n" .
				"Content-Type: multipart/form-data;\nContent-Length: ".
				length($data). "\n\n$data\n";
	}
	return err "404 Not found", "No such file or directory: $path";
}

sub put {
	my $path = shift;
	my $socket = shift;
	return err "415 Not allowed", "This file is already exist" if -e $path;
	open my $file, '>:raw', $path or return err "415 Not allowed", "Can't open a file $path";
	my $size = 0;
	while (<$socket>) {
		chomp;
		# if (m/Expect:\s+100\-continue/) {
		# 	print $client "HTTP/1.1 100 Continue\nContent-Length: 0\n\n\n";
		# }
		if (m/Content-Length:\s+(\d+)/) {
			$size = $1;
		}
		last if length $_ == 1;
	}
	while ($size > 0) {
		return err "500 Internal Server Error", "Recv failed: $!"
			unless defined recv $socket, my $buf, 1024, 0;
		print $file $buf or
			return err "500 Internal Server Error", "Can't print data $!\n";
		$size -= length $buf;
	}
	close $file or return err "415 Not allowed", "Can't close a file $path";
	return "HTTP/1.1 201 Created\nContent-Length: 0\n\n";
}

sub del {
	my $path = shift;
	if (-f $path) {
		my @res = qx(/bin/rm $path);
		if ($res[0]) {
			return err "415 Not allowed", "Can't remove a file $path";
		}
		my $data = "$path have been removed successfully!";
		return "HTTP/1.1 200 OK\nContent-Length: " . length($data) . "\n\n$data\n";
	} elsif (-d $path) {
		return err "415 Not allowed", "$path is a directory! Abort";
	}
	return err "404 Not found", "$path is not found";
}

my ($root, $ip, $port);
GetOptions(
	'host|h=s' => \$ip,
	'port|p=s' => \$port,
	'dir|d=s' => \$root,
);
die "Usage: $0 -h <ip> -p <port> -d <root directory>\n"
	unless defined $root and defined $ip and defined $port;


# TCP layer
socket my $server, AF_INET, SOCK_STREAM, IPPROTO_TCP or die $!;
setsockopt $server, SOL_SOCKET, SO_REUSEADDR, 1 or die $!;
bind $server, sockaddr_in($port, inet_aton($ip)) or die $!;
listen $server, SOMAXCONN or die $!;
while (accept my $client, $server) {
	my $pid = fork();
	die "Can't fork $!\n" unless defined $pid;
	if ($pid) {
		close $client;
	} else {
		close $server;
		my $request = <$client>;
		# HTTP layer
		my ($method, $path) = $request =~ /^([A-Z]+)\s+\/([^\s]+)?\s+HTTP/;
		$method //= "";
		$path //= "";
		$method = lc $method;
		if ($method eq "get") {
			syswrite $client, get "$root/$path";
		} elsif ($method eq "put") {
			syswrite $client, put "$root/$path", $client;
		} elsif ($method eq "delete") {
			syswrite $client, del "$root/$path";
		} else {
			syswrite $client, err "501 Not implemented", "No such method: $method";
		}
		close $client;
		exit;
	}
}
