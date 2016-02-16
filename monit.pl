#!/usr/bin/env perl

use strict;
use List::Util qw(sum);
use Fcntl;
use JSON;
#use JSON qw( encode_json );
use Data::Dumper;

my $json = JSON->new->allow_nonref;

for (my $i=1;$i<=1;$i++) {
	my $cores = getCores();
	my $cpu = getCpuUtil();
	my ($mt,$mf,$um) = getMemInfo();

	my $output = { 'cores' => $cores, 'cpu' => $cpu, 'totalmem' => $mt, 'usedmem' => $um };
	my $response = to_json( $output );
	print $response."\n";
}

sub getCores {
	chomp(my $cpu_count = `cat /proc/cpuinfo | grep -c -P '^processor\\s+:'`);
	return $cpu_count;
}

sub getMemInfo {
        my ($mt,$mf,$um,$line);
        open MEM, "</proc/meminfo" or die "Can't open file $!";
	while ($line = <MEM>) {
		chomp($line);
		my ($key,$values) = split /:/,$line;
		if ($key =~ /MemTotal/) {
			$values =~ s/ kB//;
			$values =~ s/^[ \t]*//;s/[ \t]*$//;
			$mt = $values/1024;
			$mt = sprintf "%.02f", $mt;
		} elsif ($key =~ /MemFree/) {
			$values =~ s/ kB//;
			$values =~ s/^[ \t]*//;s/[ \t]*$//;
			$mf = $values/1024;
			$mf = sprintf "%.02f", $mf;
		}
	}
        close MEM;
	$um = $mt-$mf;
	return $mt,$mf,$um;
}


sub getCpuUtil {
    open (my $STAT, "/proc/stat") or die ("Cannot open /proc/stat\n");
  seek ($STAT, Fcntl::SEEK_SET, 0);
  while (<$STAT>)
  {
    next unless ("$_" =~ m/^cpu\s+/);

    my @cpu_time_info = split (/\s+/, "$_");
    shift @cpu_time_info;
    my $total = sum(@cpu_time_info);
    my $idle = $cpu_time_info[3];
    
    my $pcpu = readCpu();
    my ($idle_old,$total_old) = split(/;/,$pcpu);

    my $del_idle = $idle - $idle_old;
    my $del_total = $total - $total_old;

    my $usage = 100 * (($del_total - $del_idle)/$del_total);

    my $util = sprintf ("%0.2f%", $usage);

    $idle_old = $idle;
    $total_old = $total;
    writeCpu($idle_old,$total_old);
    return $util;
  }
    close ($STAT);
}

sub writeCpu {
	my $idle_old = shift;
	my $total_old = shift;
	open (FH, "+>/tmp/test.tmp") or die "Can't Open file";
		print FH "$idle_old;$total_old";
	close FH;
}

sub readCpu {
	open (FH, "</tmp/test.tmp") or die "Can't Open file";
		foreach my $str (<FH>) {
			return $str;
		}
	close FH;
}

