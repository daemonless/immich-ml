/*
 * fkinfo_shim.c — LD_PRELOAD fix for onnxruntime 1.31.0 on FreeBSD.
 *
 * onnxruntime 1.31 calls fcntl(fd, F_KINFO, &kif) on a zero-initialised struct kinfo_file
 * (onnxruntime/core/platform/posix/env.cc, PosixRandomAccessFile::GetCanonicalPath). fcntl(2)
 * requires kf_structsize to be set to sizeof(struct kinfo_file) first, so the kernel returns
 * EINVAL and every model with external weights fails to load with "SystemError : 22".
 * Upstream fix: microsoft/onnxruntime#33433 (one line, the same as below). Remove this shim
 * once the py312-onnxruntime package carries it.
 *
 * The shim sets kf_structsize on every F_KINFO call, as the upstream fix does. A caller that
 * already set it gets the same value; every other fcntl call passes through untouched.
 */
#include <sys/types.h>
#include <sys/user.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>

#ifndef F_KINFO
#error "F_KINFO missing from fcntl.h: the shim would build as a silent no-op"
#endif

typedef int (*fcntl_fn)(int, int, ...);

int
fcntl(int fd, int cmd, ...)
{
	static fcntl_fn real;
	va_list ap;
	intptr_t arg;

	va_start(ap, cmd);
	arg = va_arg(ap, intptr_t);
	va_end(ap);

	if (real == NULL)
		real = (fcntl_fn)dlsym(RTLD_NEXT, "fcntl");
	if (cmd == F_KINFO && arg != 0)
		((struct kinfo_file *)arg)->kf_structsize = sizeof(struct kinfo_file);
	return real(fd, cmd, arg);
}
