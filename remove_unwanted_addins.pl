#!/usr/bin/perl
use warnings;
use strict;
use File::Basename qw(dirname basename fileparse);
use File::Spec;
use File::Copy;
use File::Path;
use File::Find qw( find );

my $root = File::Spec->rel2abs( File::Spec->updir() );

sub IsWhiteListed {
	my ($path) = @_;
	print "IsWhiteListed: $path\n";
	return 1 if $path =~ /main\/build\/AddIns$/;
	return 1 if $path =~ /main\/build\/AddIns\/MacPlatform.xml/;
	return 1 if $path =~ /main\/build\/AddIns\/BackendBindings$/;
	return 1 if $path =~ /main\/build\/AddIns\/BackendBindings/;

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
	return 1 if $path =~ /GnomePlatform.xml/;
	return 1 if $path =~ /VersionControl/;
	return 1 if $path =~ /MonoDevelop.DocFood/;
	return 1 if $path =~ /MonoDevelop.UnitTesting/;
	
	return 0;
}

sub IsBlackListed {
	my ($path) = @_;
	return 1 if $path =~ /.DS_Store/;
	return 1 if $path =~ /MonoDevelop.CBinding/;
	return 1 if $path =~ /AddIns\/AspNet/;
	return 1 if $path =~ /MonoDevelop.VBNetBinding/;
	return 1 if $path =~ /ChangeLogAddIn/;
	return 1 if $path =~ /DisplayBindings\/Gettext/;
	return 1 if $path =~ /MonoDevelop.Deployment/;	
	return 1 if $path =~ /MonoDevelop.GtkCore/;
	return 1 if $path =~ /MonoDevelop.PackageManagement/;
	return 1 if $path =~ /MonoDevelop.TextTemplating/;
	return 1 if $path =~ /MonoDevelop.WebReferences/;
	return 1 if $path =~ /MonoDeveloperExtensions/;
	return 1 if $path =~ /MonoDevelop.ConnectedServices/;
	return 1 if $path =~ /MonoDevelop.Packaging/;
	return 1 if $path =~ /PerformanceDiagnostics/;

	return 1 if $path =~ /AddIns\/MonoDevelop.Autotools/;

	return 1 if $path =~ /MonoDevelop.Debugger.Soft.AspNet/;
	return 1 if $path =~ /MonoDevelop.Debugger.Gdb/;
	return 1 if $path =~ /MonoDevelop.Debugger.Win32/;
	return 1 if $path =~ /MonoDevelop.Debugger.Win32/;

	# Blacklist local build of the add-ins.
	return 1 if $path =~ /MonoDevelop.Boo.UnityScript.Addins/;
	return 1 if $path =~ /MonoDevelop.UnityMode/;

	return 0;
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
	}, "main/build/AddIns");
}

1;