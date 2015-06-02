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

main();

sub main {
	prepare_sources();
	build_monodevelop();
	remove_unwanted_addins();
	package_monodevelop();
}

sub prepare_sources {
	chdir $root;
	die ("Must grab MonoDevelop checkout from github first") if !-d "monodevelop";
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

	return 0;
}


sub build_monodevelop {
	chdir "$root/monodevelop";

	open(my $fh, '>', 'profiles/unity');
	print $fh "main --disable-update-mimedb --disable-update-desktopdb --disable-gnomeplatform --enable-macplatform --disable-tests --disable-git --disable-subversion\n";
	close $fh;

	system("./configure --profile=unity");

	# monodevelop/main/external/Makefile copies Xamarin.Mac files from the system installed 
	# framework. We remove the Makefile copy and copy our own files instead.
	system("cp dependencies/libxammac.dylib ../monodevelop/main/external/");
	system("cp dependencies/Xamarin.Mac.dll ../monodevelop/main/external/");
	system("cp dependencies/Xamarin.Mac.dll.mdb ../monodevelop/main/external/");

	system("sed -i -e 's/all: Xamarin.Mac.dll/all:/g' ../monodevelop/main/external/Makefile");

	system("make") && die("Failed building MonoDevelop");
	mkpath("main/build/bin/branding");
	copy("$buildRepoRoot/Branding.xml", "main/build/bin/branding/Branding.xml") or die("failed copying branding");
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
	rmtree($buildresult) if (-d $buildresult);
	mkpath($buildresult);

	my $targetapp = "$buildresult/MonoDevelop.app";
	my $monodevelopbuild = "$root/monodevelop/main/build";
	my $monodeveloptarget = "$targetapp/Contents/MacOS/lib/monodevelop";

	system("cp -R $buildRepoRoot/template.app \"$targetapp\"");
	
	mkpath($monodeveloptarget);
	system("cp -r $monodevelopbuild/Addins \"$monodeveloptarget/\"");
	system("cp -r $monodevelopbuild/bin \"$monodeveloptarget/\"");
	system("cp -r $monodevelopbuild/data \"$monodeveloptarget/\"");

	# system("cp -R $mdRoot/* $root/monodevelop/main/build");
	# chdir "$root/monodevelop";
	# print "Collecting built files so they can be packaged on a mac\n";
	# unlink "MonoDevelop.tar.gz";
	# system("tar cfz MonoDevelop.tar.gz main extras");
	# move "MonoDevelop.tar.gz", "$root";
	# chdir "$root";
}
