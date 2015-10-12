AC_INIT([autotools-cache],
	[1.0.0],
	[yves-marie.morgan@parrot.com])

AM_MAINTAINER_MODE([enable])
AM_SILENT_RULES([yes])

AC_PROG_CC
AM_PROG_CC_C_O
AC_HEADER_STDC

AC_CHECK_HEADERS([ \
	ctype.h \
	dirent.h \
	dlfcn.h \
	fcntl.h \
	float.h \
	fstab.h \
	grp.h \
	inttypes.h \
	limits.h \
	poll.h \
	process.h \
	pwd.h \
	malloc.h \
	mntent.h \
	sched.h \
	stdarg.h \
	stddef.h \
	stdint.h \
	stdlib.h \
	string.h \
	strings.h \
	syslog.h \
	unistd.h \
	values.h \
	xlocale.h \
])

AC_CHECK_HEADERS([ \
	sys/filio.h \
	sys/ioctl.h \
	sys/mkdev.h \
	sys/mman.h \
	sys/mntctl.h \
	sys/mnttab.h \
	sys/mount.h \
	sys/param.h \
	sys/poll.h \
	sys/prctl.h \
	sys/resource.h \
	sys/select.h \
	sys/socket.h \
	sys/stat.h \
	sys/statfs.h \
	sys/statvfs.h \
	sys/sysctl.h \
	sys/time.h \
	sys/timerfd.h \
	sys/times.h \
	sys/types.h \
	sys/uio.h \
	sys/utsname.h \
	sys/vfs.h \
	sys/vfstab.h \
	sys/vmount.h \
	sys/wait.h \
])

AC_CHECK_HEADERS([ \
	arpa/inet.h \
	netdb.h \
	netinet/in.h \
	netinet/tcp.h \
	netinet/udp.h \
])

AC_CHECK_FUNCS([ \
	accept \
	atexit \
	chown \
	clock_gettime \
	dlopen \
	dlerror \
	dlsym \
	endmntent \
	endservent \
	fallocate \
	fchmod \
	fchown \
	fdatasync \
	fdwalk \
	fgetpos \
	fsetpos \
	fstatat \
	fsync \
	ftello \
	getc_unlocked \
	getcwd \
	getfsstat \
	getpagesize \
	getgrgid \
	gethostbyname \
	getmntent_r \
	getprotobyname_r \
	getpwuid \
	getresuid \
	gettimeofday \
	getvfsstat \
	gmtime_r \
	hasmntopt \
	if_nametoindex \
	issetugid \
	lchmod \
	lchown \
	link \
	localtime_r \
	lstat \
	memalign \
	memmem \
	memmove \
	memset \
	mkdir \
	mmap \
	newlocale \
	on_exit \
	openat \
	pipe2 \
	poll \
	posix_memalign \
	ppoll \
	prlimit \
	pselect \
	readlink \
	regcomp \
	select \
	setenv \
	setlocale \
	setmntent \
	sigaction \
	snprintf \
	socket \
	splice \
	statfs \
	statvfs \
	stpcpy \
	strcasecmp \
	strchr \
	strdup \
	strerror \
	strncasecmp \
	strndup \
	strrchr \
	strsignal \
	strstr \
	strtod_l \
	strtol \
	strtoll_l \
	strtoull_l \
	symlink \
	sysctlbyname \
	timegm \
	unlinkat \
	unsetenv \
	uselocale \
	usleep \
	utimes \
	valloc \
	vasprintf \
	vsnprintf \
	wcslen \
])

AC_CHECK_LIB(dl, dlopen)
AC_CHECK_LIB(dl, dlerror)
AC_CHECK_LIB(dl, dlsym)

AC_CHECK_LIB(m, asinh)
AC_CHECK_LIB(m, cosh)
AC_CHECK_LIB(m, fpclass)
AC_CHECK_LIB(m, log2)
AC_CHECK_LIB(m, rint)
AC_CHECK_LIB(m, sinh)

AC_CHECK_TYPE(size_t)
AC_CHECK_TYPE(ptrdiff_t)

AC_CHECK_SIZEOF(char)
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long)
AC_CHECK_SIZEOF(long long)
AC_CHECK_SIZEOF(void *)
AC_CHECK_SIZEOF(float)
AC_CHECK_SIZEOF(double)
AC_CHECK_SIZEOF(long double)

AC_OUTPUT
