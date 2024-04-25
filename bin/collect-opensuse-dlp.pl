#!/usr/bin/perl

# osc --apiurl=https://api.opensuse.org checkout devel:languages:perl
# perl collect-opensuse-dlp.pl devel:languages:perl
# -> cpanspec.yaml

use v5.38;
use feature 'signatures';
use autodie;
use YAML::PP;
use YAML::PP::Common qw/ YAML_LITERAL_SCALAR_STYLE :PRESERVE /;
use File::Find;

my $ypp_pres = YAML::PP->new( preserve => PRESERVE_SCALAR_STYLE );


my %pkg;
my %deps;
my %patches;
my %gendeps;

sub main ($dir, @args) {
    find \&wanted, $dir;
    my $test = $pkg{"perl-psh"};
    for my $p (sort keys %pkg) {
        unless ($pkg{ $p }->{conf}) {
            delete $pkg{ $p };
            next;
        }
        my $pkgconf = $pkg{ $p };
        $pkg{ $p }->{specfile} =~ s/\Q$dir//;
        my $conf = $pkg{ $p }->{conf};
        delete $conf->{patches};
        my $version = $pkg{ $p }->{version};
        if (my $preamble = $conf->{preamble}) {
            my @preamble = split m/\n/, $preamble;
            my $skip = 0;
            for my $line (@preamble) {
                if ($line =~ m/^%endif /) {
                    $skip = 0;
                    next;
                }
                next if $skip;
                next if $line =~ m/^ *$/;
                next if $line =~ m/^Obsoletes:/;
                next if $line =~ m/^Provides:/;
                next if $line =~ m/^Source/;
                next if $line =~ m/^ExcludeArch/;
                next if $line =~ m/^%define/;
                next if $line =~ m/^%requires_eq/;
                last if $line =~ m/^%post/;
                next if $line =~ m/^%package/;
                next if $line =~ m/^Summary:/;
                next if $line =~ m/^Group:/;
                next if $line =~ m/^Requires\(post\):/;
                last if $line =~ m/^%description/;
                next if $line =~ m/^ *#/;
                if ($line =~ m/^%if /) {
                    $skip = 1;
                    next;
                }
                if ($line =~ m/^(Build)?Requires: +(.*)/) {
                    my $type = $1 ? 'build' : 'runtime';
                    push @{ $deps{ $p }->{ $version }->{ $type } }, $2;
                    next;
                }
                if ($line =~ m/^(Recommends|Suggests): +(.*)/) {
                    push @{ $deps{ $p }->{ $version }->{lc $1} }, $2;
                    next;
                }
                die "!!!!! $p: '$line'";
            }
        }
        if (my $patchlist = delete $pkgconf->{patches}) {
            $patches{ $p }->{ $version } = $patchlist;
        }
        if (my $gendeps = delete $pkgconf->{gendeps}) {
            $gendeps{ $p }->{ $version } = $gendeps;
        }
    }
    YAML::PP::DumpFile('cpanspec.yaml', \%pkg);
    YAML::PP::DumpFile('deps.yaml', \%deps);
    $ypp_pres->dump_file('patches.yaml', \%patches);
    $ypp_pres->dump_file('gendeps.yaml', \%gendeps);
}

my %deptypes = (
    Requires => 'runtime',
    BuildRequires => 'build',
    Suggests => 'uggests',
    Recmmends => 'recommends',
);

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
        if (my $patches = $conf->{patches}) {
            for my $file (sort keys %$patches) {
                $file =~ s{.*/}{};
                $file =~ s/%name/$name/;
                next if $file =~ m/^%/;
                next unless -f $file; # :(
                my $opt = $patches->{ $file };
                open my $fh, '<:encoding(UTF-8)', $file;
                my $patch = do { local $/; <$fh> };
                close $fh;
                push @{ $pkg{ $name }->{patches} }, {
                    name => $file,
                    opt => $opt,
                    content => YAML::PP->preserved_scalar($patch, style => YAML_LITERAL_SCALAR_STYLE),
                };
            }
        }
    }
    elsif (m/\.spec$/) {
        $pkg{ $name }->{specfile} = $File::Find::name;
        open my $fh, '<', $_;
        my $spec = do { local $/; <$fh> };
        close $fh;
        my $version = '-';
        if ($spec =~ m/^Version:\s+(\S+)/m) {
            $version = $1;
        }
        else {
            warn "$name: no Version";
        }
        $pkg{ $name }->{version} = $version;
        my @req = $spec =~ m/^(Requires|BuildRequires|Suggests|Recmmends): +(\S+)/mg;
        my %gendeps;
        for (my $i = 0; $i < @req; $i += 2) {
            my ($type, $req) = @req[$i, $i+1];
            $type = $deptypes{ $type } or die "!!!!!!!!!! $type";
            push @{ $gendeps{ $type } }, $req;
        }
        push @{ $pkg{ $name }->{gendeps} }, \%gendeps;
    }

}

main(@ARGV);
