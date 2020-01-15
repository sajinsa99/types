#### standard perl could be use no need to install any specific perl module


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
    $referencePlatform
    @ListNewPlatforms
    %listTemplateFiles
);

# for options/parameters
use vars qw (
    $paramNewPlatforms
    $paramVariantPlatform
    $optCreate
    $optUpdateTypeFile
    $optHelp
    $optForce
    $optDelete
);



##############################################################################
##############################################################################
##### declare functions
sub getListTemplateFiles();
sub createNewPlatform($);
sub createNewFile($$$);
sub cleanPlatform($);
sub updateTypePropertyFile($$);
sub displayHelp();



##############################################################################
##############################################################################
##### get options/parameters
$Getopt::Long::ignorecase = 0;
GetOptions(
    "rp=s"   =>\$referencePlatform,
    "np=s"   =>\$paramNewPlatforms,
    "vp=s"   =>\$paramVariantPlatform,
    "C"      =>\$optCreate,
    "U"      =>\$optUpdateTypeFile,
    "F"      =>\$optForce,
    "D"      =>\$optDelete,
    "help"   =>\$optHelp,
);



##############################################################################
##############################################################################
##### inits & checks
$currentDir          = $FindBin::Bin;
#$referencePlatform ||= "linuxx86_64" ; # use linuxx86_64 by default

if($optHelp) {
    displayHelp();
    exit 0;
}

unless($paramNewPlatforms) {
    print "\n\nERRROR : need to specify the new platform name using option -np=xxx\n\n";
    displayHelp();
    exit 1;
}

unless($referencePlatform) {
    print "\n\nERRROR : need to specify a \"reference\" platform name using option -rp=xxx\n\n";
    displayHelp();
    exit 1;
}

unless($paramVariantPlatform) {
	$paramVariantPlatform = $referencePlatform ;
}

@ListNewPlatforms = split ',' , $paramNewPlatforms;

foreach my $newPlatform (sort @ListNewPlatforms) {
	if ( $referencePlatform =~ /^$newPlatform$/i ) {
	    print "\n\nERRROR : new platform '$newPlatform' is the same than reference platform '$referencePlatform', nothing to do to be safe\n\n";
	    displayHelp();
	    exit 1;
	}
}




##############################################################################
##############################################################################
##### MAIN

# 1 get list of existing properties files used as templates
find(\&getListTemplateFiles, $currentDir);

# 2 clean or create new platform
if( scalar keys %listTemplateFiles > 0 ) {
    if($optDelete) {
        print "\n => ACTION : delete property files if exist, for new platform : @ListNewPlatforms\n";
        foreach my $newPlatform (sort @ListNewPlatforms) {
        	cleanPlatform($newPlatform);
        }
    }  else  {
    	foreach my $newPlatform (sort @ListNewPlatforms) {
	        if($optCreate) {
	            print "\n => ACTION : create property files for new platform : $newPlatform\n";
	            createNewPlatform($newPlatform);
	        }  else  {
	            print "\nAs -C, neither -D are not set, just list template files:\n";
	            foreach my $type ( sort keys %listTemplateFiles ) {
	                print "\n\t$type\n";
	                foreach my $templateFile ( sort @{$listTemplateFiles{$type}} ) {
	                    print "$templateFile\n";
	                }
	            }
	        }
	    }
    }
}  else  {
    print "\n\tWARNING : no file found for reference platform '$referencePlatform'\n\n";
}
exit 0;



##############################################################################
##############################################################################
##### functions
sub getListTemplateFiles() {
    # search all files with buildruntime=reference_platform
    return unless( -f $File::Find::name );                 # skip folders
    return if( $File::Find::name !~ /\.properties$/i );    # ensure file is a .properties file
    return if( $File::Find::name =~ /P4\_$/i );            # skip P4, should not exist but in case . . .
    return if( $File::Find::name =~ /type.properties$/i ); # skip this special file, managed later
    if(open my $file_handle , '<' , $File::Find::name) {
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
        print "\n\t$type\n";
        foreach my $templateFile ( sort @{$listTemplateFiles{$type}} )  {
            (my $newFile = $templateFile) =~ s-$referencePlatform-$this_new_platform-;
            print "new file : $newFile\n";
            if( -e "$currentDir/$newFile") {
                print "WARNING : $newFile already exists !!!\n";
                if($optForce) {
                    print "  as -F is set, $newFile will be overriden !!!\n";
                    createNewFile($this_new_platform, $templateFile, $newFile);
                }
            }  else  {
                createNewFile($this_new_platform, $templateFile, $newFile);
            }
        }
        if( -e "$currentDir/$type/type.properties") {
            if($optUpdateTypeFile) {
                updateTypePropertyFile($this_new_platform , "$type/type.properties");
            }  else  {
                print "\nWARNING : don't forget to update, or not, $type/type.properties.\n";
            }
        }
    }
    print "\nWARNING : don't forget to update as well : jobbase/extensions/typedefs/BuildRuntime.properties !!!\n\n";
}

sub createNewFile($$$) {
    my ($this_platform, $this_TemplateFile, $this_NewFile) = @_ ;
    if(open my $newFile_handle , '>' , "$currentDir/$this_NewFile") {
        if(open my $templateFile_handle , '<' , "$currentDir/$this_TemplateFile") {
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
        cluck "\tWARNING : cannot create '$this_NewFile' : $!\n";
    }
}

sub updateTypePropertyFile($$) {
    my ($this_platform, $this_typePropertyFile) = @_ ;
    my $linesToAdd = "
additional.variant.$this_platform.buildruntime=$this_platform
additional.variant.$this_platform.buildoptions=-V platform\=$paramVariantPlatform -V mode\=opt
";
	my $ref_property_file = "$currentDir/$this_typePropertyFile";
	if( -e "$currentDir/$this_typePropertyFile.new") {
		$ref_property_file = "$currentDir/$this_typePropertyFile.new.orig";
		system "cp -pf $currentDir/$this_typePropertyFile.new $currentDir/$this_typePropertyFile.new.orig"
	}
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
        system "rm -f $currentDir/$this_typePropertyFile.new.orig";
        if($optForce) {
            rename "$currentDir/$this_typePropertyFile.new" , "$currentDir/$this_typePropertyFile"
                or cluck "WARNING : cannot rename '$this_typePropertyFile.new' to '$this_typePropertyFile' : $!\n";
        }  else  {
            print "$this_typePropertyFile.new created, please merge/rename it in/to $this_typePropertyFile.\n";
        }
    }
}

sub cleanPlatform($) {
	my ($this_platform) = @_ ;
    foreach my $type ( sort keys %listTemplateFiles ) {
        print "\n\t$type\n";
        foreach my $templateFile ( sort @{$listTemplateFiles{$type}} ) {
            (my $newFile = $templateFile) =~ s-$referencePlatform-$this_platform-;
            if( -e "$currentDir/$newFile" ) {
                print "file to clean : $newFile\n";
                unlink "$currentDir/$newFile"
                    or cluck "WARNING : cannot unlink '$currentDir/$newFile' : $!\n";
            }
        }
        if( -e "$currentDir/$type/type.properties.new") {
            print "file to clean : $type/type.properties.new\n";
            unlink "$currentDir/$type/type.properties.new"
                or cluck "WARNING : cannot unlink '$currentDir/$type/type.properties.new' : $!\n";
        }  else  {
            print "WARNING : maybe you have to revert yourself : $type/type.properties !!!\n";
        }
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
