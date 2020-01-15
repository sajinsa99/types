##############################################################################
##############################################################################
##### declare uses
# for code quality
use strict;
use warnings;
use diagnostics;
use Carp qw(cluck confess); # to use instead of (warn die)

# for the script itself
use Getopt::Long;
use File::Copy;
use File::Find;
use FindBin;
use lib $FindBin::Bin;



##############################################################################
##############################################################################
##### declare vars

use vars qw (
    $currentDir
    $commandLine
    $referencePlatform
    $orig_param_create_platforms
    %hCreatePlatforms
);

# for options/parameters
use vars qw (
    %Options
    $optionsParseStatus
    $param_create_platforms
    $param_delete_platforms
    $opt_DryRun
    $opt_UpdateTypeFile
    $opt_Force
    $opt_Help
);

##############################################################################
##############################################################################
##### declare functions
sub searchPropertyFilesToDelete();
sub checkDuplicates();
sub displayHelp();



##############################################################################
##############################################################################
##### get options/parameters
$opt_DryRun = 1;
$commandLine = "$0 @ARGV";
displayHelp() unless(@ARGV);
%Options = (
    "r=s"   =>\$referencePlatform,
    "cp=s"  =>\$param_create_platforms,
    "dp=s"  =>\$param_delete_platforms,
    "dr!"   =>\$opt_DryRun,
    "U"     =>\$opt_UpdateTypeFile,
    "F"     =>\$opt_Force,
    "help"  =>\$opt_Help,
);

$Getopt::Long::ignorecase = 0;
$optionsParseStatus = GetOptions(%Options);
if($opt_Help || ! $optionsParseStatus) {
    displayHelp();
    exit 0;
}


##############################################################################
##############################################################################
##### inits & checks
$currentDir          = $FindBin::Bin;
$referencePlatform ||= "linuxx86_64" ; # use linuxx86_64 by default

if($param_create_platforms && $param_delete_platforms) {
    confess "ERROR : options '-cp' & '-dp' cannot be used together : $!";
}
if($param_create_platforms) {
    $orig_param_create_platforms = $param_create_platforms ;
    checkDuplicates();
}



##############################################################################
##############################################################################
##### MAIN

if($param_delete_platforms) {
    foreach my $platform (sort split ',' , $param_delete_platforms) {
        local $ENV{PLATFORM_TBD} = $platform;
        find(\&searchPropertyFilesToDelete, $currentDir);
        undef $ENV{PLATFORM_TBD} ;
    }
    print "\ngit status\n";
    system "git status";
    print "\n";
    exit 0;
}

exit 0;



##############################################################################
##############################################################################
##### functions
sub searchPropertyFilesToDelete() {
    return unless( $File::Find::name );                 # skip folders
    return unless( -f $File::Find::name );                 # skip folders
    return if( $File::Find::name !~ /\.properties$/i );    # ensure file is a .properties file
    return if( $File::Find::name =~ /type.properties$/i ); # skip this special file, managed later
    my $this_platform_to_delete = $ENV{PLATFORM_TBD};
    my $flag = 0 ;
    if(open my $file_handle , '<' , $File::Find::name) {
        while(<$file_handle>) {
            if( $_ =~ /buildruntime\=\"$this_platform_to_delete\"/ ) {
                $flag = 1;
                last;
            }
        }
        close $file_handle;
        if($flag==1) {
            print "file to delete : $File::Find::name\n";
            if($opt_DryRun == 0) {
                unlink "$File::Find::name" or cluck "WARNING : cannot delete $File::Find::name : $!";
            }
        }
    }
}

sub checkDuplicates() {
    ($param_create_platforms) =~ s-\s+--g;     # if people want to add spaces for more readable
    ($param_create_platforms) =~ s-\=-:-g;     # if people prefer '=' instead of ':'
    ($param_create_platforms) =~ s-\(|\{-[-g;  # if people prefer () or {}
    ($param_create_platforms) =~ s-\)|\}-]-g;  # if people prefer () or {}

    my %checkDuplicateNewPlatforms;
    foreach my $key_list (split ';' , $param_create_platforms) {
        my ($ref_platform,$tmp_platforms);
        ($ref_platform,$tmp_platforms) = $key_list =~ /^\[(.+?)\:(.+?)\]$/i;
        if( ! defined $ref_platform) {
            $ref_platform    = $referencePlatform;
            ($tmp_platforms) = $key_list =~ /^\[\:(.+?)\]$/i;
        }
        my @new_platforms = split ',' , $tmp_platforms ;
        # search variant
        my $variant       = $ref_platform;
        my $flag          = 0;
        foreach my $platform (@new_platforms) {
            if($platform =~ /\|(.+?)$/i) {
                $variant = $1;
                $flag    = 1 ;
                last;
            }
        }
        if($flag == 1) {
            my $last_elem = pop @new_platforms;
            ($last_elem)  =~ s-\|.+?$--i;
            push @new_platforms , $last_elem ;
        }
        # search duplicate
        foreach my $platform (@new_platforms) {
            if( ! defined $checkDuplicateNewPlatforms{$platform} ) {
                $checkDuplicateNewPlatforms{$platform} = 1 ;
            }  else  {
                confess "\nERROR : $platform already listed in $orig_param_create_platforms : $!";
            }
        }
        push @{$hCreatePlatforms{$ref_platform}{variant}} , $variant;
        if(scalar @{$hCreatePlatforms{$ref_platform}{variant}} > 1) {
            confess "\nERROR : there is more than 1 variant for $ref_platform in $orig_param_create_platforms : $!";
        }
        push @{$hCreatePlatforms{$ref_platform}{new_platforms}} , @new_platforms;
    }
}

sub displayHelp() {
    print <<FIN_USAGE;

[synopsis]
$0 permit to create new platform (new buildruntime) in the jobbase.
It concists to create .properties files in jobbase/builds/types/<TYPE>/jobs/
It is based on a reference platform (by default : linuxx86_64) for creating new platform.

[options]
    -h  : to display this help
    -rp : to choose a specific reference platform, MANDATORY
    -np : to choose the new platform, MANDATORY
    -C  : ACTION : to create
          if -D is set as well, $0 will run only -D
    -U  : works with -C, update as well <type>/type.properties file, eg update as well GIT_DEV/type.properties file.
          $0 will create type.properties.new file, up to you to merge/move in/to type.properties file.
          if -F is set, it will move from type.properties.new to type.properties
    -F  : works with -C, if .properties files of new platform or <type>/type.properties already exist, to override them.
    -D  : ACTION : if .properties files of new platform already exist, to delete them, and exit.
          if -C or -U or -F are set as well, they will be ignored.

FIN_USAGE
}
