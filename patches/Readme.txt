This directory contains patches for Mono and MonoDevelop that are not yet upstream.

Build mono-sgen
===============

1) Check version of existing mono-sgen

	buildresult/MonoDevelop.app/Contents/Frameworks/Mono.framework/Versions/Current/bin/mono-sgen --version

- Example output:
	Mono JIT compiler version 4.0.2 ((detached/c99aa0c Thu Jun 11 18:53:01 EDT 2015)
	Copyright (C) 2002-2014 Novell, Inc, Xamarin Inc and Contributors. www.mono-project.com
		TLS:           normal
		SIGSEGV:       altstack
		Notification:  kqueue
		Architecture:  x86
		Disabled:      none
		Misc:          softdebug 
		LLVM:          yes(3.6.0svn-mono-(detached/a173357)
		GC:            sgen

2) Note revision c99aa0c in the output above
3) Build mono-sgen from revision c99aa0c with mono.patch applied.

	git clone https://github.com/mono/mono.git
	cd mono
	git checkout c99aa0c
	git apply <monodevelop-build dir>/patches/mono.patch

	CC='cc -m32' ./autogen.sh --disable-nls --build=i386-apple-darwin11.2.0
	make clean all


4) Copy mono-sgen into patches folder

	cp mono/mini/mono-sgen  <monodevelop-build dir>/patches/