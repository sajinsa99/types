# platforms.pl


## Purpose
The script "platforms.pl" is a perl script which is able to :  
+ add new build runtimes (aka jenkins label)  
+ delete build runtimes  (aka jenkins label)  

These 2 actions are applying some change(s) in the xMake jobbase.

## Quality & robustness of the script
The perl script includes the 3 following perl packages :  
+ strict      => for restricting unsafe constructs
+ warnings    => for controling optional warnings
+ diagnostics => for producing  verbose warning diagnostics  

And on January 2020, the script passed the perl critic, from [perlcritic](http://perlcritic.com/),  
with the severity check level 1 ("brutal"), the results are :  
Total violations: 15  
Severity 5: 0  
Severity 4: 0  
Severity 3: 0  
Severity 2: 0  
Severity 1: 15  
(Severity 5 level, is the most dangerous and risky)

## Prerequisite
- Perl, with the minimal version "5.__18__" installed (should be in the PATH, no need any extra perl module installed).  
- Git and your credentials (ssh keys) installed and configured.  

And that's all.

## Recommandations
Better is to have a clean repo (nothing to add, nothing to commit, 'git pull' done) before running the script.
To ensure a clean state, you could run :
```
git clean -x -d -f
git checkout -f --
git pull
git status
```

## Add new platform(s).
By default, the script will use the 'linuxx86_64' as reference platform for adding a new platform,  
but you can choose another one, see syntax and "how to" sections below.  
The reference platform will be used as a template to add new build runtimes.  
Without specifying any variant, the script will use the reference platform as variant.  
opton '-ap'.  

#### syntax
__WARNING__ the double quotes are <span style="color:red">MANDATORY</span>.  
general form :  
-ap="(set1)"  
or  
-ap="(set1);(set2);..."  
Please use the semicolon character (;) as separator for having multiple set.  

#### how to declare a set of new builds :
-ap="(ref1:platformA,platformB|variant1)"  
'ref1' : the reference platform, followed by the character ':'  
platformA, platformB : the list of new build runtimes to add, please use the comma character (,) as sparator.  
'|variant' : to specify the variant, prefix it with the character pipe (|), so after the list of new build runtimes.  
__WARNING__ you have to have uniq platform in new build runtimes, and in reference platform, and in variant.  
<s>-ap="(ref1:platformA,platformB|variant1);(ref2:platformC,platformD|platformB)"</s> (here platformB is duplicate)  
<s>-ap="(ref1:platformA,platformB|variant1);(ref2:platformC,platformD|ref1)"</s> (here ref1 is duplicate)  
<s>-ap="(ref1:platformA,platformC|variant1);(ref2:platformC,platformD|platformB)"</s> (here platformC is duplicate)  

#### details :  
-ap="(ref1:platformA,platformB|variant1);(ref2:platformC,platformD|variant2)"  
or  
-ap="(:platformA,platformB|variant1);(ref2:platformC,platformD|variant2)"  
or  
-ap="(:platformA,platformB);(ref2:platformC,platformD|variant2)"  

