use 5.016;
use Socket ':all';

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

#TODO: fix this subroutine
# sub put {
# 	my $path = shift;
# 	my $socket = shift;
# 	return err "415 Not allowed", "This file is already exist" if -x $path;
# 	open my $fh, '>:raw', $path or return err "415 Not allowed", "Can't open a file $path";
# 	my $size = 0;
# 	while (<$socket>) {
# 		next unless $size = m/Content-Length:\s+([\d+])/;
# 		last if m/^\n$/;
# 	}
# 	say $size;
# 	# print $fh, $request or return err "415 Not allowed", "Can't write a file $path";
# 	close $fh or return err "415 Not allowed", "Can't close a file $path";
# 	return "HTTP/1.1 200 OK\nContent-Length: 0\n\n";
# }

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

# Usage: $0 -h <ip> -p <port> -d <root directory>
# обработка аргументов командной строки
my $root = "/home/andrey/server-data";
my $ip = "127.0.0.1";
my $port = "11111";

# TCP layer
socket my $lsocket, AF_INET, SOCK_STREAM, IPPROTO_TCP or die $!;
setsockopt $lsocket, SOL_SOCKET, SO_REUSEADDR, 1 or die $!;
bind $lsocket, sockaddr_in($port, inet_aton($ip)) or die $!;
listen $lsocket, SOMAXCONN or die $!;
while (accept my $csocket, $lsocket) {
	my $request = <$csocket>;
	# HTTP layer
	my ($method, $path) = $request =~ /^([A-Z]+)\s+\/([^\s]+)?\s+HTTP/;
	$method //= "";
	$path //= "";
	$method = lc $method;
	if ($method eq "get") {
		syswrite $csocket, get "$root/$path";
	} elsif ($method eq "put") {
		syswrite $csocket, put "$root/$path", $csocket;
	} elsif ($method eq "delete") {
		syswrite $csocket, del "$root/$path";
	} else {
		syswrite $csocket, err "501 Not implemented", "No such method: $method";
	}
	close $csocket;
}
