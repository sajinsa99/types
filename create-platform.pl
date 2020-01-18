#!/usr/bin/env perl -w
##############################################################################
##############################################################################
##### declare uses
# for code quality
use strict;
use warnings;
use diagnostics;
use Carp qw(cluck confess); # to use instead of (warn die)

# for the script itself
use English qw( -no_match_vars ) ;
use Fatal qw(open close);
use autodie;
use Getopt::Long;
use File::Copy;
use File::Find;
use FindBin;
use lib $FindBin::Bin;

our $VERSION = '1.0';

##############################################################################
##############################################################################
##### declare vars

my $COMMA                       = q{,};
my $SEMICOLON                   = q{;};
my $EMPTY                       = q{};

my $current_dir                 = $EMPTY;
my $command_line                = $EMPTY;
my $global_ref_platform         = $EMPTY;
my $orig_param_create_platforms = $EMPTY;
my %h_create_platforms          = ();
my %list_template_files         = ();
my %list_type_files             = ();

# for options/parameters
my %all_ptions             = ();
my $options_parse_status   = $EMPTY;
my $param_create_platforms = $EMPTY;
my $param_delete_platforms = $EMPTY;
my $opt_help               = $EMPTY;



##############################################################################
##############################################################################
##### declare functions
sub git_status;
sub get_property_files;
sub check_duplicates;
sub create_new_platform;
sub create_property_file;
sub add_new_platform_in_type_file;
sub get_type_files;
sub delete_platform_in_type_file;
sub display_help;


##############################################################################
##############################################################################
##### get options/parameters
$command_line = "$PROGRAM_NAME @ARGV";
if( ! @ARGV ) { display_help() }
%all_ptions = (
    "r=s"   =>\$global_ref_platform,
    "cp=s"  =>\$param_create_platforms,
    "dp=s"  =>\$param_delete_platforms,
    "help"  =>\$opt_help,
);

$Getopt::Long::ignorecase = 0;
$options_parse_status = GetOptions(%all_ptions);
if($opt_help || ! $options_parse_status) {
    display_help();
    exit 0;
}

##############################################################################
##############################################################################
##### inits & checks
$current_dir          = $FindBin::Bin;
if( ! $global_ref_platform) {
    # use linuxx86_64 by default
    $global_ref_platform = 'linuxx86_64';
}

if($param_create_platforms && $param_delete_platforms) {
    confess "ERROR : options '-cp' & '-dp' cannot be used together : $ERRNO";
}



##############################################################################
##############################################################################
##### MAIN

if($param_delete_platforms) {
    find(\&get_type_files, $current_dir);
    foreach my $platform (sort split $COMMA , $param_delete_platforms) {
        local $ENV{PLATFORM_TBD} = $platform;
        find(\&get_property_files, $current_dir);
        foreach my $type_file ( sort keys %list_type_files) {
            delete_platform_in_type_file($type_file)
        }
        undef $ENV{PLATFORM_TBD} ;
    }
    git_status();
}

if($param_create_platforms) {
    $orig_param_create_platforms = $param_create_platforms ;
    check_duplicates();
    foreach my $ref_platform (sort keys %h_create_platforms) {
        print "\nreference     : " , $ref_platform , "\n";
        local $ENV{REF_PLATFORM} = $ref_platform;
        local $ENV{variant}      = @{$h_create_platforms{$ref_platform}{variant}}[0];
        print qq{variant       : $ENV{variant}\n};
        find(\&getlist_template_files, $current_dir);
        foreach my $elem (sort keys %{$h_create_platforms{$ref_platform}} ) {
            next if($elem =~ m/^variant$/ixms);
            (my $display_elem = $elem) =~ s/\_/ /xms;
            print $display_elem , " :\n";
            foreach my $new_platform (sort @{$h_create_platforms{$ref_platform}{$elem}} ) {
                print "\t\t" , $new_platform , "\n";
                create_new_platform($new_platform);
            }
        }
        %list_template_files = ();
        undef $ENV{REF_PLATFORM};
        undef $ENV{variant};
    }
    git_status();
}

print "END of $PROGRAM_NAME.\n\n";
exit 0;



##############################################################################
##############################################################################
##### functions
sub git_status {
    print "\ngit status\n";
    print   "==========\n";
    system "git status";
    print "\n\n";
    print "git --no-pager diff GIT*/type.properties\n";
    system "git --no-pager diff GIT*/type.properties";
    print "\n\n";
    print "WARNING : don't forget to update as well : jobbase/extensions/typedefs/BuildRuntime.properties !!!\n\n";
    print "Now up to you to complete/revert the work.\n\n";
    print "END of $PROGRAM_NAME.\n\n";
    exit 0;
}

sub get_property_files {
    if( ! $File::Find::name )    { return }                        # skip folders
    if( ! -f $File::Find::name ) { return }                        # skip folders
    if( $File::Find::name !~ m/[.]properties$/ixms )   { return }  # ensure file is a .properties file
    if( $File::Find::name =~ m/type.properties$/ixms ) { return }  # skip this special file, managed later
    my $file_handle;
    my $flag = 0 ;
    my $this_platform_to_delete = $ENV{PLATFORM_TBD};
    open $file_handle , q{<} , "$File::Find::name" or confess "ERROR : cannot open $File::Find::name : $ERRNO";
    while(<$file_handle>) {
        if( $ARG =~ m/buildruntime\=\"$this_platform_to_delete\"/xms ) {
            $flag = 1;
            last;
        }
    }
    close $file_handle;
    if($flag==1) {
        print "file to delete : $File::Find::name\n";
        unlink "$File::Find::name" or cluck "WARNING : cannot delete $File::Find::name : $ERRNO";
    }
    return;
}

sub check_duplicates {
    ($param_create_platforms) =~ s/\s+//gxms;      # if people want to add spaces for more readable
    ($param_create_platforms) =~ s/[=]/:/gxms;     # if people prefer '=' instead of ':'
    ($param_create_platforms) =~ s/[\(\{]/[/gxms;  # if people prefer () or {}
    ($param_create_platforms) =~ s/[\)\}]/]/gxms;  # if people prefer () or {}

    my %check_duplicate_new_platforms;
    foreach my $key_list (split $SEMICOLON , $param_create_platforms) {
        my ($ref_platform,$tmp_platforms);
        ($ref_platform,$tmp_platforms) = $key_list =~ m/^[[](.+?)[:](.+?)[]]$/ixms;
        if( ! defined $ref_platform) {
            $ref_platform    = $global_ref_platform;
            ($tmp_platforms) = $key_list =~ m/^\[\:(.+?)\]$/ixms;
        }
        my @new_platforms = split $COMMA , $tmp_platforms ;
        # search variant
        my $variant       = $ref_platform;
        my $flag          = 0;
        foreach my $platform (@new_platforms) {
            if($platform =~ m/[|](.+?)$/ixms) {
                $variant = $1;
                $flag    = 1 ;
                last;
            }
        }
        if($flag == 1) {
            my $last_elem = pop @new_platforms;
            ($last_elem)  =~ s/[|].+?$//ixms;
            push @new_platforms , $last_elem ;
        }
        # search duplicate
        foreach my $platform (@new_platforms) {
            if( ! defined $check_duplicate_new_platforms{$platform} ) {
                $check_duplicate_new_platforms{$platform} = 1 ;
            }  else  {
                confess "\nERROR : $platform already listed in $orig_param_create_platforms : $ERRNO";
            }
        }
        push @{$h_create_platforms{$ref_platform}{variant}} , $variant;
        if(scalar @{$h_create_platforms{$ref_platform}{variant}} > 1) {
            confess "\nERROR : there is more than 1 variant for $ref_platform in $orig_param_create_platforms : $ERRNO";
        }
        push @{$h_create_platforms{$ref_platform}{new_platforms}} , @new_platforms;
    }
    return;
}

sub getlist_template_files {
    # search all files with buildruntime=reference_platform
    if( ! -f $File::Find::name ) { return }                         # skip folders
    if( $File::Find::name =~ m/[.]git/ixms ) { return }             # skip .git folder
    if( $File::Find::name !~ m/[.]properties$/ixms )    { return }  # ensure file is a .properties file
    if( $File::Find::name =~ m/P4\_$/ixms )            { return }   # skip P4, should not exist but in case . . .
    if( $File::Find::name =~ m/type.properties$/ixms ) { return }   # skip this special file, managed later
    my $file_handle;
    if(open $file_handle , q{<} , $File::Find::name) {
        my $this_ref_platform = $ENV{REF_PLATFORM};
        while(<$file_handle>) {
            if( $ARG =~ m/buildruntime\=\"$this_ref_platform\"/xms ) {
                (my $final_file = $File::Find::name) =~ s/^$current_dir\///ixms; # remove the base folder, for the display.
                (my $type = $final_file) =~ s/\/.+?$//xms;
                push @{$list_template_files{$type}} , $final_file ;
                last;
            }
        }
        close $file_handle;
    }
    return;
}

sub create_new_platform {
    my ($this_new_platform) = @ARG ;
    foreach my $type ( sort keys %list_template_files ) {
        print "\t\t- $type\n";
        foreach my $template_file ( sort @{$list_template_files{$type}} )  {
            create_property_file($this_new_platform, $template_file);
        }
        if( -e "$current_dir/$type/type.properties") {
            add_new_platform_in_type_file($this_new_platform , "$type/type.properties");
        }
    }
    return;
}

sub create_property_file {
    my ($this_platform, $this_template_file) = @ARG ;
    my $this_ref_platform = $ENV{REF_PLATFORM};
    (my $tmp_file = $this_template_file) =~ s/\-$this_ref_platform/\-$this_platform/gxms;
    my $new_file_handle ;
    if(open $new_file_handle , q{>} , "$current_dir/$tmp_file") {
        my $template_file_handle;
        if(open $template_file_handle , q{<} , "$current_dir/$this_template_file") {
            while(<$template_file_handle>) {
                if(m/\"$this_ref_platform\"/ixms) {
                    s/\"$this_ref_platform\"/\"$this_platform\"/xms;
                }
                print {$new_file_handle} "$ARG" ;
            }
            close $template_file_handle;
        }
        close $new_file_handle;
    }  else  {
        cluck "\tWARNING : cannot create $tmp_file : $ERRNO";
    }
    return;
}

sub add_new_platform_in_type_file {
    my ($this_platform, $this_type_property_file) = @ARG ;
    my $this_variant = $ENV{variant};
    my $lines_to_add =  "\n" .
"additional.variant.$this_platform.buildruntime=$this_platform\n" .
"additional.variant.$this_platform.buildoptions=-V platform\=$this_variant -V mode\=opt";
    my $ref_property_file = "$current_dir/$this_type_property_file";
    my $file_handle;
    if(open $file_handle , q{<} , "$ref_property_file") {
        my $new_file_handle;
        if(open $new_file_handle , q{>} , "$current_dir/$this_type_property_file.new") {
            while(<$file_handle>) {
                print {$new_file_handle} "$ARG";
            }
            print {$new_file_handle} "\n";
            print {$new_file_handle} "$lines_to_add";
            print {$new_file_handle} "\n";
            close $new_file_handle;
        }
        close $file_handle;
        rename "$current_dir/$this_type_property_file.new" , "$current_dir/$this_type_property_file"
            or cluck "WARNING : cannot rename '$this_type_property_file.new' to '$this_type_property_file' : $ERRNO\n";
    }
    return;
}

sub get_type_files {
    if( $File::Find::name =~ m/[.]git/ixms ) { return }            # skip .git folder
    if( ! $File::Find::name )    { return }                        # skip folders
    if( ! -f $File::Find::name ) { return }                        # skip folders
    if( $File::Find::name !~ m/[.]properties$/ixms )   { return }  # ensure file is a .properties file
    if( $File::Find::name =~ m/type[.]properties$/ixms ) {
        (my $type_file = $File::Find::name) =~ s/^$current_dir\///xms;
        $list_type_files{$type_file} = 1 ;
        return
    }
    return;
}

sub delete_platform_in_type_file {
    my ($this_type_property_file) = @ARG ;
    my $delete_platform = $ENV{PLATFORM_TBD} ;
    my $ref_property_file = "$current_dir/$this_type_property_file";
    my $file_handle;
    if(open $file_handle , q{<} , "$ref_property_file") {
        my $new_file_handle;
        if(open $new_file_handle , q{>} , "$current_dir/$this_type_property_file.new") {
            while(<$file_handle>) {
                if($ARG =~ m/[.]$delete_platform[.]/xms) {
                    next ;
                }
                print {$new_file_handle} "$ARG";
            }
            close $new_file_handle;
        }
        close $file_handle;
        rename "$current_dir/$this_type_property_file.new" , "$current_dir/$this_type_property_file"
            or cluck "WARNING : cannot rename '$this_type_property_file.new' to '$this_type_property_file' : $ERRNO\n";
    }
    return;
}

sub display_help {
    print << 'END_USAGE';

[synopsis]
$PROGRAM_NAME is a tool to create new platform (new buildruntime, aka jenkins label) in the xMake jobbase.
It would to create *.properties files in jobbase/builds/types/<TYPE>/jobs/ .
It is based on a reference platform (by default : linuxx86_64).

[options]
    -h  : to display this help
    -cp : to list of platforms to create (cannot be used with -dp)
          there is a special syntax, please refer to the README.md for further details.
    -dp : to list of platforms to delete (cannot be used with -cp)
          i.e.: -dp="platform,platformb"

END_USAGE
    return;
}
