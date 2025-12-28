# Building onnxruntime Python Wheel on FreeBSD

This documents how to build onnxruntime with Python bindings on FreeBSD.

## Requirements

- FreeBSD 15.0+
- ~20GB disk space
- 1-2+ hours build time

## Install Build Dependencies

```bash
doas pkg install cmake ninja gmake git-lite gpatch \
    python311 py311-pip py311-setuptools py311-wheel py311-numpy \
    FreeBSD-clang FreeBSD-clibs-dev FreeBSD-clang-dev
```

## Clone Source

```bash
git clone --recursive https://github.com/microsoft/onnxruntime.git
cd onnxruntime
```

## Apply FreeBSD Patches

### 1. Override BSD patch with gpatch

The build scripts require GNU patch features:

```bash
doas ln -sf /usr/local/bin/gpatch /usr/local/bin/patch
```

### 2. Fix thread ID in env.cc

Edit `onnxruntime/core/platform/posix/env.cc`:

```cpp
// Add at top with other includes:
#ifdef __FreeBSD__
#include <pthread_np.h>
#endif

// Find the GetCurrentThreadId() function and change:
// FROM:
#if defined(__linux__)
  return static_cast<pid_t>(syscall(SYS_gettid));
#endif

// TO:
#if defined(__linux__)
  return static_cast<pid_t>(syscall(SYS_gettid));
#elif defined(__FreeBSD__)
  return static_cast<pid_t>(pthread_getthreadid_np());
#endif
```

### 3. Fix unused variable warning in spin_pause.cc

Edit `onnxruntime/core/common/spin_pause.cc`:

The file has an unused variable that triggers `-Werror`. Either:
- Comment out the unused variable, or
- Use `--compile_no_warning_as_error` flag (recommended)

## Build

```bash
CC=clang CXX=clang++ python3.11 ./tools/ci_build/build.py \
    --build_dir ./build/FreeBSD \
    --config Release \
    --enable_pybind \
    --build_wheel \
    --skip_tests \
    --parallel \
    --compile_no_warning_as_error
```

## Output

The wheel will be at:
```
build/FreeBSD/Release/dist/onnxruntime-X.Y.Z-cp311-cp311-freebsd_15_0_release_p1_amd64.whl
```

## Upload to GitHub Releases

```bash
gh release create onnxruntime-X.Y.Z \
    build/FreeBSD/Release/dist/onnxruntime-*.whl \
    --repo daemonless/immich-ml \
    --title "onnxruntime X.Y.Z FreeBSD wheel" \
    --notes "Pre-built onnxruntime X.Y.Z with Python bindings for FreeBSD 15.0 / Python 3.11"
```

Then update `ONNXRUNTIME_WHEEL` and `ONNXRUNTIME_URL` in `immich-ml/Containerfile`.

## Notes

- onnxruntime warns "Unsupported platform (freebsd)" at runtime but works fine
- Only CPUExecutionProvider is available (no GPU support)
- The wheel is ~25MB
