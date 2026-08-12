# Building onnxruntime Python Wheel on FreeBSD (Legacy / Deprecated)

> **Note:** Custom `onnxruntime` wheel builds are deprecated. `immich-ml` now uses FreeBSD's native `py-onnxruntime` package (`misc/py-onnxruntime`) installed directly via `pkg`.

This document is preserved for historical reference on building standalone onnxruntime wheels with Python bindings on FreeBSD.

## Manual Build

### Requirements

- FreeBSD 15.0+
- ~20GB disk space
- 1-2+ hours build time

### Install Build Dependencies

```bash
doas pkg install cmake ninja gmake git gpatch \
    python311 py311-pip py311-setuptools py311-wheel py311-numpy py311-pybind11
```

### Clone Source

```bash
VERSION=1.23.2
git clone --depth 1 --branch v${VERSION} --recursive \
    https://github.com/microsoft/onnxruntime.git
cd onnxruntime
```

### Apply FreeBSD Patch

The patch file fixes:
- `env.cc` - Exclude FreeBSD from Linux-specific cpu_set_t affinity code
- `onnxruntime_validation.py` - Add FreeBSD platform recognition
- `setup.py` - Include .so files in wheel for FreeBSD
- `platform_helpers.py` - Treat FreeBSD as Linux-like for build system

```bash
patch -p1 < /path/to/patches/onnxruntime-freebsd.patch
```

### Build

Standard build:
```bash
# Extra include path needed for logging.h on FreeBSD
export CXXFLAGS="-I$(pwd)/include/onnxruntime/core/common/logging"

CC=clang CXX=clang++ python3.12 ./tools/ci_build/build.py \
    --build_dir ./build/FreeBSD \
    --config Release \
    --enable_pybind \
    --build_wheel \
    --skip_tests \
    --parallel \
    --compile_no_warning_as_error
```

No-AVX build (for older CPUs without AVX/AVX2/SSE4):
```bash
export CFLAGS="-march=x86-64 -mno-avx -mno-avx2 -mno-sse4.1 -mno-sse4.2 -mno-ssse3 -mno-fma"
export CXXFLAGS="-I$(pwd)/include/onnxruntime/core/common/logging ${CFLAGS}"

CC=clang CXX=clang++ python3.12 ./tools/ci_build/build.py \
    --build_dir ./build/FreeBSD \
    --config Release \
    --enable_pybind \
    --build_wheel \
    --skip_tests \
    --parallel \
    --compile_no_warning_as_error \
    --cmake_extra_defines onnxruntime_USE_AVX=OFF onnxruntime_USE_AVX2=OFF onnxruntime_USE_AVX512=OFF CMAKE_C_FLAGS="${CFLAGS}" CMAKE_CXX_FLAGS="${CFLAGS}"
```

### Output

The wheel will be at:
```
build/FreeBSD/Release/dist/onnxruntime-1.23.2-cp311-cp311-freebsd_15_0_release_p1_amd64.whl
```

### Install and Test

```bash
pip install build/FreeBSD/Release/dist/onnxruntime-*.whl

python3 -c "
import onnxruntime as ort
import numpy as np
print('Version:', ort.__version__)
print('Providers:', ort.get_available_providers())
"
```

## Notes

- Only CPUExecutionProvider is available (no GPU support)
- The wheel is ~17MB
- C++ level warnings about "Unknown CPU vendor" are cosmetic (cpuinfo library limitation)
