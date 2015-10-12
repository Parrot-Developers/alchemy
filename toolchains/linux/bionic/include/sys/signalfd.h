#ifndef _SYS_SIGNALFD_H
#define _SYS_SIGNALFD_H 1

#include <signal.h>
#include <stdint.h>

#include <unistd.h>
#include <sys/syscall.h>

#ifndef SYS_signalfd4
#ifdef __arm__
#define SYS_signalfd4 (355)
#else
#error not supported
#endif
#endif


/* Flags for signalfd4.  */
#define SFD_CLOEXEC  02000000
#define SFD_NONBLOCK 04000

struct signalfd_siginfo
{
	uint32_t ssi_signo;
	int32_t ssi_errno;
	int32_t ssi_code;
	uint32_t ssi_pid;
	uint32_t ssi_uid;
	int32_t ssi_fd;
	uint32_t ssi_tid;
	uint32_t ssi_band;
	uint32_t ssi_overrun;
	uint32_t ssi_trapno;
	int32_t ssi_status;
	int32_t ssi_int;
	uint64_t ssi_ptr;
	uint64_t ssi_utime;
	uint64_t ssi_stime;
	uint64_t ssi_addr;
	uint8_t __pad[48];
};

static inline int signalfd (int fd, const sigset_t *mask, int flags)
{
	sigset_t sigset[2] = {*mask, 0};
	/* use signalfd4 */
	return syscall(SYS_signalfd4, fd, &sigset[0], sizeof(sigset), flags);
}

#endif
