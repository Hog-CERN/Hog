#!/usr/bin/perl
use File::Spec;

$begin_file = ".vivado.begin.rst";
$end_file   = ".vivado.end.rst";
$error_file = ".vivado.error.rst";
$queue_file = ".Vivado_Synthesis.queue.rst";
$log_file = "runme.log";

if (-d $ARGV[0]) {
    $dir = $ARGV[0];
} else {
    die "[RunStatus] Directory $ARGV[0] does not exist.\n";
}

do {
    opendir(DIR, $dir) or die "[RunStatus] Could not open $dir: $!\n";
    while ($d = readdir DIR) {
	if (-d "$dir/$d" and $d =~! /\.+/ ) {
	    if (-f "$dir/$d/$end_file") {
		$map{$d} = "<font style=\"font-weight:bold;color:Green\";> done successfully </font>";
		$tails=40;
	    } elsif (-f "$dir/$d/$error_file") {
		$map{$d} = "<font style=\"font-weight:bold;color:Red\";> error </font>";
		$tails=100;
	    } elsif (-f "$dir/$d/$begin_file") {
		open BEG, "$dir/$d/$begin_file";
		@lines = <BEG>;
		close BEG;
		$pid = 0;
		for (@lines) {
		    if (/Pid=\"(\d+)\"/) {
			$pid = $1;
		    }
		}
		if ($pid == 0) {
		die "[RunStatus] Couldnt parse pid out of $dir/$d/$begin_file!\n";
		}
		$map{$d} = $pid;
		$tails=100;
	    } elsif (-f "$dir/$d/$queue_file") {
		$map{$d} = "queued";
		$tails=20;		
	    }
	    if (-f "$dir/$d/$log_file") {
		$log{$d} = `tail -$tails $dir/$d/$log_file`;
	    } else {
		$log{$d} = `No log file found`;
	    }
	    
	}
	
    }
    
    open OUT, ">$ARGV[1]" or die "[RunStatus] Could not open $ARGV[1]: $! \n"; 
    print OUT "<h2> Project: $dir </h2>\n";
    $AllDone = 1;
    for $key (keys(%map)) {
	print OUT "<strong> Run $key </strong>\n";
	if ($map{$key} =~ /\d+/) {
	    print OUT "<font style=\"font-weight:bold;color:Orange\";> is running with PID=$map{$key}</font>";
	    $alive = kill 0, $map{$key};
	    if ($alive) {
		print OUT "<font style=\"font-weight:bold;color:Green\";> Process $map{$key} is alive</font>";
	    } else {
		print OUT "<font style=\"font-weight:bold;color:Red\";> Process $map{$key} is dead</font>";
	    } 
	} else {
	    print OUT "$map{$key}";
	}
	if ($log{$key}) {
	    print OUT "<label for=\"$key\"> <font style=\"color:white;background-color:#36c\";> view </font> </label>\n";
	    print OUT "<input type=\"checkbox\" id=\"$key\" style=\"display:none;\">\n";
	    print OUT "<div id=\"hidden\"><pre>\n";
	    print OUT $log{$key};
	    print OUT "</pre></div>\n";	
	}
	print OUT "<br>\n";
	if ($map{$key} eq "queued" or $map{$key} =~ /\d+/) {
	    $AllDone = 0;
	}
    }
    print OUT "<hr>\n";
    close OUT;
    sleep 5;
} until ($AllDone == 1);

open OUT, ">>$ARGV[1]" or die "[RunStatus] Could not open $ARGV[1]: $! \n"; 
print OUT "<p> All done for: $dir </p>\n";
close OUT;
