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
    %listTemplateFiles
);

# for options/parameters
use vars qw (
    %Options
    $optionsParseStatus
    $param_create_platforms
    $param_delete_platforms
    $opt_Help
);

##############################################################################
##############################################################################
##### declare functions
sub gitStatus();
sub searchPropertyFilesToDelete();
sub checkDuplicates();
sub createNewPlatform($);
sub createNewPropertyFile($$);
sub updateTypePropertyFile($$);
sub displayHelp();



##############################################################################
##############################################################################
##### get options/parameters
$commandLine = "$0 @ARGV";
displayHelp() unless(@ARGV);
%Options = (
    "r=s"   =>\$referencePlatform,
    "cp=s"  =>\$param_create_platforms,
    "dp=s"  =>\$param_delete_platforms,
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



##############################################################################
##############################################################################
##### MAIN

if($param_delete_platforms) {
    foreach my $platform (sort split ',' , $param_delete_platforms) {
        local $ENV{PLATFORM_TBD} = $platform;
        find(\&searchPropertyFilesToDelete, $currentDir);
        undef $ENV{PLATFORM_TBD} ;
    }
    gitStatus();
}

if($param_create_platforms) {
    $orig_param_create_platforms = $param_create_platforms ;
    checkDuplicates();
    foreach my $ref_platform (sort keys %hCreatePlatforms) {
        print "\nreference     : " , $ref_platform , "\n";
        local $ENV{REF_PLATFORM} = $ref_platform;
        local $ENV{variant}      = @{$hCreatePlatforms{$ref_platform}{variant}}[0];
        print "variant       : ", $ENV{variant} , "\n";
        find(\&getListTemplateFiles, $currentDir);
        foreach my $elem (sort keys %{$hCreatePlatforms{$ref_platform}} ) {
            next if($elem =~ /^variant$/i);
            (my $display_elem = $elem) =~ s-\_- -;
            print $display_elem , " :\n";
            foreach my $new_platform (sort @{$hCreatePlatforms{$ref_platform}{$elem}} ) {
                print "\t\t" , $new_platform , "\n";
                createNewPlatform($new_platform);
            }
        }
        %listTemplateFiles = ();
        undef $ENV{REF_PLATFORM};
        undef $ENV{variant};
    }
    gitStatus();
}

print "END of $0.\n\n";
exit 0;



##############################################################################
##############################################################################
##### functions
sub gitStatus() {
    print "\ngit status\n";
    print   "==========\n";
    system "git status";
    print "\n\n";
    print "git --no-pager diff GIT*/type.properties\n";
    system "git --no-pager diff GIT*/type.properties";
    print "\n\n";
    print "WARNING : don't forget to update as well : jobbase/extensions/typedefs/BuildRuntime.properties !!!\n\n";
    print "Now up to you to complete/revert the work.\n\n";
    print "END of $0.\n\n";
    exit 0;
}

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
            unlink "$File::Find::name" or cluck "WARNING : cannot delete $File::Find::name : $!";
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

sub getListTemplateFiles() {
    # search all files with buildruntime=reference_platform
    return unless( -f $File::Find::name );                 # skip folders
    return if( $File::Find::name !~ /\.properties$/i );    # ensure file is a .properties file
    return if( $File::Find::name =~ /P4\_$/i );            # skip P4, should not exist but in case . . .
    return if( $File::Find::name =~ /type.properties$/i ); # skip this special file, managed later
    if(open my $file_handle , '<' , $File::Find::name) {
        my $referencePlatform = $ENV{REF_PLATFORM};
        while(<$file_handle>) {
            if( $_ =~ /buildruntime\=\"$referencePlatform\"/ ) {
                (my $finalFile = $File::Find::name) =~ s-^$currentDir\/--i; # remove the base folder, for the display.
                (my $type = $finalFile) =~ s-\/.+?$--;
                push @{$listTemplateFiles{$type}} , $finalFile ;
                last;
            }
        }
        close $file_handle;
    }
}

sub createNewPlatform($) {
    my ($this_new_platform) = @_ ;
    foreach my $type ( sort keys %listTemplateFiles ) {
        print "\t\t- $type\n";
        foreach my $templateFile ( sort @{$listTemplateFiles{$type}} )  {
            createNewPropertyFile($this_new_platform, $templateFile);
        }
        if( -e "$currentDir/$type/type.properties") {
            updateTypePropertyFile($this_new_platform , "$type/type.properties");
        }
    }
}

sub createNewPropertyFile($$) {
    my ($this_platform, $this_TemplateFile) = @_ ;
    my $referencePlatform = $ENV{REF_PLATFORM};
    (my $tmp_file = $this_TemplateFile) =~ s/\-$referencePlatform/\-$this_platform/g;
    if(open my $newFile_handle , '>' , "$currentDir/$tmp_file") {
        if(open my $templateFile_handle , '<' , "$currentDir/$this_TemplateFile") {
            my $referencePlatform = $ENV{REF_PLATFORM};
            while(<$templateFile_handle>) {
                if(/\"$referencePlatform\"/i) {
                    s-\"$referencePlatform\"-\"$this_platform\"-;
                }
                print $newFile_handle $_ ;
            }
            close $templateFile_handle;
        }
        close $newFile_handle;
    }  else  {
        cluck "\tWARNING : cannot create $tmp_file : $!";
    }
}

sub updateTypePropertyFile($$) {
    my ($this_platform, $this_typePropertyFile) = @_ ;
    my $this_variant = $ENV{variant};
    my $linesToAdd = "
additional.variant.$this_platform.buildruntime=$this_platform
additional.variant.$this_platform.buildoptions=-V platform\=$this_variant -V mode\=opt
";
    my $ref_property_file = "$currentDir/$this_typePropertyFile";
    if(open my $File_handle , '<' , "$ref_property_file") {
        if(open my $newFile_handle , '>' , "$currentDir/$this_typePropertyFile.new") {
            while(<$File_handle>) {
                print $newFile_handle $_;
            }
            print $newFile_handle "\n";
            print $newFile_handle $linesToAdd;
            close $newFile_handle;
        }
        close $File_handle;
        rename "$currentDir/$this_typePropertyFile.new" , "$currentDir/$this_typePropertyFile"
            or cluck "WARNING : cannot rename '$this_typePropertyFile.new' to '$this_typePropertyFile' : $!\n";
    }
}

sub displayHelp() {
    print <<END_USAGE;

[synopsis]
$0 is a tool to create new platform (new buildruntime, aka jenkins label) in the xMake jobbase.
It would to create *.properties files in jobbase/builds/types/<TYPE>/jobs/ .
It is based on a reference platform (by default : linuxx86_64).

[options]
    -h  : to display this help
    -cp : to list of platforms to create (cannot be used with -dp)
          there is a special syntax, please refer to the README.md for further details.
    -dp : to list of platforms to delete (cannot be used with -cp)
          i.e.: -dp="platform,platformb"

END_USAGE
}
