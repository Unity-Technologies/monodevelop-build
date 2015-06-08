#!/usr/bin/perl
use warnings;
use strict;
use File::Basename qw(dirname basename fileparse);
use File::Spec;
use File::Copy;
use File::Path;
use File::Find qw( find );

my $buildRepoRoot = File::Spec->rel2abs( dirname($0) );
my $root = File::Spec->rel2abs( File::Spec->updir() );
my $mdSource = "$root/monodevelop/main/build";
my $nant = "";

main();

sub main {
	prepare_sources();
	setup_nant();
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

sub IsWhiteListed {
	my ($path) = @_;
	print "IsWhite: $path\n";
	return 1 if $path =~ /main\/build\/Addins$/;
	return 1 if $path =~ /main\/build\/Addins\/MacPlatform.xml/;
	return 1 if $path =~ /main\/build\/Addins\/BackendBindings$/;

	return 1 if $path =~ /ICSharpCode.NRefactory/;
	return 1 if $path =~ /ILAsmBinding/;
	return 1 if $path =~ /MonoDevelop.CSharpBinding./;
		
	return 1 if $path =~ /DisplayBindings$/;
	return 1 if $path =~ /DisplayBindings\/AssemblyBrowser/;
	return 1 if $path =~ /DisplayBindings\/HexEditor/;
	return 1 if $path =~ /DisplayBindings\/SourceEditor/;
	return 1 if $path =~ /\/MonoDevelop.Debugger$/;

	return 1 if $path =~ /MonoDevelop.Debugger\/MonoDevelop.Debugger./;
	return 1 if $path =~ /MonoDevelop.Debugger.Soft/;
	
	return 1 if $path =~ /MonoDevelop.DesignerSupport/;
	return 1 if $path =~ /MonoDevelop.Refactoring/;
	return 1 if $path =~ /MonoDevelop.RegexToolkit/;
	return 1 if $path =~ /WindowsPlatform/;
	return 1 if $path =~ /NUnit/;
	return 1 if $path =~ /\/Xml/;
	
	return 0;
}

sub IsBlackListed {
	my ($path) = @_;
	return 1 if $path =~ /.DS_Store/;
	return 1 if $path =~ /MonoDevelop.CBinding/;
	return 1 if $path =~ /Addins\/AspNet/;
	return 1 if $path =~ /MonoDevelop.DocFood/;
	return 1 if $path =~ /MonoDevelop.VBNetBinding/;
	return 1 if $path =~ /ChangeLogAddIn/;
	return 1 if $path =~ /DisplayBindings\/Gettext/;
	return 1 if $path =~ /MonoDevelop.Deployment/;	
	return 1 if $path =~ /MonoDevelop.GtkCore/;
	return 1 if $path =~ /MonoDevelop.PackageManagement/;
	return 1 if $path =~ /MonoDevelop.TextTemplating/;
	return 1 if $path =~ /MonoDevelop.WebReferences/;
	return 1 if $path =~ /MonoDeveloperExtensions/;
	return 1 if $path =~ /VersionControl/;

	return 1 if $path =~ /Addins\/MonoDevelop.Autotools/;

	return 1 if $path =~ /MonoDevelop.Debugger.Soft.AspNet/;
	return 1 if $path =~ /MonoDevelop.Debugger.Gdb/;
	return 1 if $path =~ /MonoDevelop.Debugger.Win32/;

	# Blacklist local build of the add-ins.
	return 1 if $path =~ /MonoDevelop.Boo.UnityScript.Addins/;

	return 0;
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
	copy("$buildRepoRoot/Branding.xml", "main/build/bin/branding/Branding.xml") or die("failed copying branding");
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

sub process_addin_path {
   if (IsBlackListed($File::Find::name))
	{
		print "Killing $File::Find::name\n";	
		my $fullpath = $File::Find::name;
		print "Killing $fullpath\n";	
		rmtree($fullpath);
		$File::Find::prune = 1;
		return;
	} 
   if (IsWhiteListed($File::Find::name))
   {
   		return;
   }
   die ("Found path in Addins folder that is not in whitelist or blacklist: $File::Find::name\n");
}

sub remove_unwanted_addins()
{
	chdir("$root/monodevelop");
	find({
	   wanted   => \&process_addin_path,
	   no_chdir => 1,
	}, "main/build/Addins");
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

	# system("cp -R $mdRoot/* $root/monodevelop/main/build");
	# chdir "$root/monodevelop";
	# print "Collecting built files so they can be packaged on a mac\n";
	# unlink "MonoDevelop.tar.gz";
	# system("tar cfz MonoDevelop.tar.gz main extras");
	# move "MonoDevelop.tar.gz", "$root";
	# chdir "$root";
}
