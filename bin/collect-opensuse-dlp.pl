#!/usr/bin/perl

# osc --apiurl=https://api.opensuse.org checkout devel:languages:perl
# perl collect-opensuse-dlp.pl devel:languages:perl
# -> cpanspec.yaml

use v5.38;
use feature 'signatures';
use YAML::PP;
use File::Find;

my %pkg;

sub main ($dir, @args) {
    find \&wanted, $dir;
    my $test = $pkg{"perl-psh"};
    for my $p (keys %pkg) {
        unless ($pkg{ $p }->{conf}) {
            delete $pkg{ $p };
            next;
        }
        $pkg{ $p }->{spec} =~ s/\Q$dir//;
    }
    YAML::PP::DumpFile('cpanspec.yaml', \%pkg);
}


sub wanted {
    return if $File::Find::dir =~ m/\.osc/;
    return unless -f $_;
    my ($name) = $File::Find::name =~ m{/(perl-[^/]+)/};
    unless ($name) {
        return;
    }
    if ($_ eq 'cpanspec.yml') {
        my $conf = YAML::PP::LoadFile($_);
        $pkg{ $name }->{conf} = $conf;
    }
    elsif (m/\.spec$/) {
        $pkg{ $name }->{spec} = $File::Find::name;
    }

}

main(@ARGV);
