#!/usr/bin/perl
use warnings;
use strict;
use File::Basename qw(dirname basename fileparse);
use File::Spec;
use File::Copy;
use File::Path;
use File::Find qw( find );

require "remove_unwanted_addins.pl";

my $buildRepoRoot = File::Spec->rel2abs( dirname($0) );
my $root = File::Spec->rel2abs( File::Spec->updir() );
my $mdSource = "$root/monodevelop/main/build";
my $nant = "";

main();

sub main {
	prepare_sources();
	setup_nant();

	# Build MonoDevelop
	build_monodevelop();
	remove_unwanted_addins();

	# Build Unity Add-ins
	build_debugger_addin();
	build_boo();
	build_boo_extensions();
	build_unityscript();
	build_boo_unity_addins();

	package_monodevelop();
}

sub prepare_sources {
	chdir $root;
	die ("Must grab MonoDevelop checkout from github first") if !-d "monodevelop";
	die ("Must grab Unity MonoDevelop Soft Debugger source from github first") if !-d "MonoDevelop.Debugger.Soft.Unity";
	die ("Must grab Unity Add-ins for Boo and Unity source from github first") if !-d "MonoDevelop.Boo.UnityScript.Addins";
	die ("Must grab Boo implementation") if !-d "boo";
	die ("Must grab Boo extensions") if !-d "boo-extensions";
	die ("Must grab Unityscript implementation") if !-d "unityscript";

	system("rm -rf $buildRepoRoot/dependencies/Mono.framework");
	system("unzip -d $buildRepoRoot/dependencies $buildRepoRoot/dependencies/monoframework-osx.zip") && die("Failed to unpack monoframework-osx.zip");
}

sub setup_nant 
{
	$ENV{PKG_CONFIG_PATH}="/Library/Frameworks/Mono.framework/Versions/Current/lib/pkgconfig";
	$nant = "mono --runtime=v4.0.30319 $buildRepoRoot/dependencies/nant-0.93-nightly-2015-02-12/bin/NAnt.exe";
}

sub build_monodevelop {
	chdir "$root/monodevelop";

	open(my $fh, '>', 'profiles/unity');
	print $fh "main --disable-update-mimedb --disable-update-desktopdb --disable-gnomeplatform --enable-macplatform --disable-tests --disable-git --disable-subversion\n";
	close $fh;

	system("./configure --profile=unity");

	# monodevelop/main/external/Makefile copies Xamarin.Mac files from the system installed 
	# framework. We remove the Makefile copy and copy our own local copies instead.
	system("cp dependencies/libxammac.dylib ../monodevelop/main/external/");
	system("cp dependencies/Xamarin.Mac.dll ../monodevelop/main/external/");
	system("cp dependencies/Xamarin.Mac.dll.mdb ../monodevelop/main/external/");

	system("sed -i -e 's/all: Xamarin.Mac.dll/all:/g' ../monodevelop/main/external/Makefile");

	system("make") && die("Failed building MonoDevelop");
	mkpath("main/build/bin/branding");
	copy("$buildRepoRoot/dependencies/Branding.xml", "main/build/bin/branding/Branding.xml") or die("failed copying branding");
}

sub build_debugger_addin {
	my $addinsdir = "$root/monodevelop/main/build/Addins/";
	chdir "$root/MonoDevelop.Debugger.Soft.Unity";
	mkpath "$addinsdir/MonoDevelop.Debugger.Soft.Unity";
	system("xbuild /property:Configuration=Release /t:Rebuild /p:OutputPath=\"$addinsdir/MonoDevelop.Debugger.Soft.Unity\"") && die("Failed building Unity debugger addin");
}

sub build_boo {
	my $externalDir = "$root/MonoDevelop.Boo.UnityScript.Addins/external";
	chdir "$root/boo";
	system("$nant rebuild") && die ("Failed to build Boo");
	mkpath "$externalDir/Boo";
	system("rsync -av --exclude=*.mdb  \"$root/boo/build/\" \"$externalDir/Boo\"");
}

sub build_boo_extensions {
	chdir "$root/boo-extensions";
	system("$nant rebuild") && die ("Failed to build Boo");
}

sub build_unityscript {
	my $externalDir = "$root/MonoDevelop.Boo.UnityScript.Addins/external";
	chdir "$root/unityscript";
	rmtree "$root/unityscript/bin";
	system("$nant rebuild") && die ("Failed to build UnityScript");
	mkpath "$externalDir/UnityScript";
	system("rsync -av --exclude=*.mdb --exclude=*Tests* --exclude=nunit* \"$root/unityscript/bin/\" \"$externalDir/UnityScript\"");
}

sub build_boo_unity_addins {
	my $addinsdir = "$root/monodevelop/main/build/Addins/";
	chdir "$root/MonoDevelop.Boo.UnityScript.Addins";
	mkpath "$addinsdir/MonoDevelop.Boo.UnityScript.Addins";
	system("xbuild /property:Configuration=Release /t:Rebuild /p:OutputPath=\"$addinsdir/MonoDevelop.Boo.UnityScript.Addins\"") && die("Failed building Unity debugger addin");
}

sub package_monodevelop {
	my $buildresult = "$buildRepoRoot/buildresult";
	system("rm -rf $buildresult") if (-d $buildresult);
	mkpath($buildresult);

	my $targetapp = "$buildresult/MonoDevelop.app";
	my $monodevelopbuild = "$root/monodevelop/main/build";
	my $monodeveloptarget = "$targetapp/Contents/MacOS/lib/monodevelop";

	system("cp -R $buildRepoRoot/dependencies/template.app \"$targetapp\"");

	system("mkdir -p \"$targetapp/Contents/Frameworks/\"");
	system("cp -R $buildRepoRoot/dependencies/Mono.framework \"$targetapp/Contents/Frameworks/\"");
	
	mkpath($monodeveloptarget);
	system("cp -r $monodevelopbuild/Addins \"$monodeveloptarget/\"");
	system("cp -r $monodevelopbuild/bin \"$monodeveloptarget/\"");
	system("cp -r $monodevelopbuild/data \"$monodeveloptarget/\"");

	system("rm -rf $buildRepoRoot/dependencies/Mono.framework");

	# Archive the app for placement in unity installer
	chdir "$buildresult";
	unlink "MonoDevelop.dmg", "MonoDevelop.app.tar.gz";

	print "Creating MonoDevelop.app.tar.gz\n";
	system("tar -pczf MonoDevelop.app.tar.gz --exclude=.svn MonoDevelop.app");

	# Create seperate monodevelop installer as well
	chdir "$mdSource/MacOSX/";
	system("sh make-dmg-bundle.sh $buildresult/MonoDevelop.app");

	my $dmg = glob "MonoDevelop-*.dmg";
	move "$mdSource/MacOSX/$dmg", "$buildresult/MonoDevelop.dmg" or die $!;
}
