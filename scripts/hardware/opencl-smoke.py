#!/usr/bin/env python3
"""Execute one real OpenCL kernel on an Intel GPU using only ctypes."""
from __future__ import annotations

import ctypes as C
import ctypes.util

CL_SUCCESS = 0
CL_DEVICE_TYPE_GPU = 1 << 2
CL_PLATFORM_VENDOR = 0x0903
CL_DEVICE_NAME = 0x102B
CL_DEVICE_VENDOR = 0x102C
CL_MEM_READ_ONLY = 1 << 2
CL_MEM_WRITE_ONLY = 1 << 1
CL_MEM_COPY_HOST_PTR = 1 << 5
CL_TRUE = 1
CL_PROGRAM_BUILD_LOG = 0x1183

libname = ctypes.util.find_library("OpenCL") or "libOpenCL.so.1"
cl = C.CDLL(libname)

cl_int = C.c_int
cl_uint = C.c_uint
cl_ulong = C.c_ulong
cl_bool = C.c_uint
size_t = C.c_size_t
cl_platform_id = C.c_void_p
cl_device_id = C.c_void_p
cl_context = C.c_void_p
cl_command_queue = C.c_void_p
cl_mem = C.c_void_p
cl_program = C.c_void_p
cl_kernel = C.c_void_p


def check(rc: int, what: str) -> None:
    if rc != CL_SUCCESS:
        raise RuntimeError(f"{what} failed: OpenCL rc={rc}")


def info_string(func, obj, param: int) -> str:
    size = size_t()
    check(func(obj, param, 0, None, C.byref(size)), "query info size")
    buf = C.create_string_buffer(size.value)
    check(func(obj, param, size.value, buf, None), "query info value")
    return buf.value.decode(errors="replace")


cl.clGetPlatformIDs.argtypes = [cl_uint, C.POINTER(cl_platform_id), C.POINTER(cl_uint)]
cl.clGetPlatformIDs.restype = cl_int
cl.clGetPlatformInfo.argtypes = [cl_platform_id, cl_uint, size_t, C.c_void_p, C.POINTER(size_t)]
cl.clGetPlatformInfo.restype = cl_int
cl.clGetDeviceIDs.argtypes = [cl_platform_id, cl_ulong, cl_uint, C.POINTER(cl_device_id), C.POINTER(cl_uint)]
cl.clGetDeviceIDs.restype = cl_int
cl.clGetDeviceInfo.argtypes = [cl_device_id, cl_uint, size_t, C.c_void_p, C.POINTER(size_t)]
cl.clGetDeviceInfo.restype = cl_int

count = cl_uint()
check(cl.clGetPlatformIDs(0, None, C.byref(count)), "clGetPlatformIDs(count)")
platforms = (cl_platform_id * count.value)()
check(cl.clGetPlatformIDs(count.value, platforms, None), "clGetPlatformIDs")

selected = None
for platform in platforms:
    vendor = info_string(cl.clGetPlatformInfo, platform, CL_PLATFORM_VENDOR)
    ndev = cl_uint()
    rc = cl.clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 0, None, C.byref(ndev))
    if rc != CL_SUCCESS or ndev.value == 0:
        continue
    devices = (cl_device_id * ndev.value)()
    check(cl.clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, ndev.value, devices, None), "clGetDeviceIDs")
    for dev in devices:
        d_vendor = info_string(cl.clGetDeviceInfo, dev, CL_DEVICE_VENDOR)
        name = info_string(cl.clGetDeviceInfo, dev, CL_DEVICE_NAME)
        if "intel" in (vendor + " " + d_vendor + " " + name).lower():
            selected = (platform, dev, vendor, d_vendor, name)
            break
    if selected:
        break

if not selected:
    raise SystemExit("No Intel OpenCL GPU device found")
_, device, platform_vendor, device_vendor, device_name = selected
print(f"platform_vendor={platform_vendor}")
print(f"device_vendor={device_vendor}")
print(f"device_name={device_name}")

cl.clCreateContext.argtypes = [C.c_void_p, cl_uint, C.POINTER(cl_device_id), C.c_void_p, C.c_void_p, C.POINTER(cl_int)]
cl.clCreateContext.restype = cl_context
err = cl_int()
dev_arr = (cl_device_id * 1)(device)
context = cl.clCreateContext(None, 1, dev_arr, None, None, C.byref(err))
check(err.value, "clCreateContext")

if hasattr(cl, "clCreateCommandQueueWithProperties"):
    cl.clCreateCommandQueueWithProperties.argtypes = [cl_context, cl_device_id, C.c_void_p, C.POINTER(cl_int)]
    cl.clCreateCommandQueueWithProperties.restype = cl_command_queue
    queue = cl.clCreateCommandQueueWithProperties(context, device, None, C.byref(err))
else:
    cl.clCreateCommandQueue.argtypes = [cl_context, cl_device_id, cl_ulong, C.POINTER(cl_int)]
    cl.clCreateCommandQueue.restype = cl_command_queue
    queue = cl.clCreateCommandQueue(context, device, 0, C.byref(err))
check(err.value, "clCreateCommandQueue")

n_items = 256
float_array = C.c_float * n_items
a = float_array(*[float(i) for i in range(n_items)])
b = float_array(*[float(i * 2) for i in range(n_items)])
out = float_array()
bytes_len = C.sizeof(a)

cl.clCreateBuffer.argtypes = [cl_context, cl_ulong, size_t, C.c_void_p, C.POINTER(cl_int)]
cl.clCreateBuffer.restype = cl_mem
buf_a = cl.clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, bytes_len, C.cast(a, C.c_void_p), C.byref(err)); check(err.value, "buffer a")
buf_b = cl.clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, bytes_len, C.cast(b, C.c_void_p), C.byref(err)); check(err.value, "buffer b")
buf_o = cl.clCreateBuffer(context, CL_MEM_WRITE_ONLY, bytes_len, None, C.byref(err)); check(err.value, "buffer out")

source = b"""
__kernel void add(__global const float *a, __global const float *b, __global float *out) {
    size_t i = get_global_id(0);
    out[i] = a[i] + b[i];
}
"""
srcs = (C.c_char_p * 1)(C.c_char_p(source))
cl.clCreateProgramWithSource.argtypes = [cl_context, cl_uint, C.POINTER(C.c_char_p), C.c_void_p, C.POINTER(cl_int)]
cl.clCreateProgramWithSource.restype = cl_program
program = cl.clCreateProgramWithSource(context, 1, srcs, None, C.byref(err)); check(err.value, "clCreateProgramWithSource")
cl.clBuildProgram.argtypes = [cl_program, cl_uint, C.POINTER(cl_device_id), C.c_char_p, C.c_void_p, C.c_void_p]
cl.clBuildProgram.restype = cl_int
rc = cl.clBuildProgram(program, 1, dev_arr, None, None, None)
if rc != CL_SUCCESS:
    cl.clGetProgramBuildInfo.argtypes = [cl_program, cl_device_id, cl_uint, size_t, C.c_void_p, C.POINTER(size_t)]
    cl.clGetProgramBuildInfo.restype = cl_int
    n = size_t()
    cl.clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, None, C.byref(n))
    log = C.create_string_buffer(n.value)
    cl.clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, n.value, log, None)
    raise RuntimeError(f"clBuildProgram rc={rc}: {log.value.decode(errors='replace')}")

cl.clCreateKernel.argtypes = [cl_program, C.c_char_p, C.POINTER(cl_int)]
cl.clCreateKernel.restype = cl_kernel
kernel = cl.clCreateKernel(program, b"add", C.byref(err)); check(err.value, "clCreateKernel")
cl.clSetKernelArg.argtypes = [cl_kernel, cl_uint, size_t, C.c_void_p]
cl.clSetKernelArg.restype = cl_int
for idx, buf in enumerate((buf_a, buf_b, buf_o)):
    tmp = cl_mem(buf)
    check(cl.clSetKernelArg(kernel, idx, C.sizeof(tmp), C.byref(tmp)), f"clSetKernelArg({idx})")

cl.clEnqueueNDRangeKernel.argtypes = [cl_command_queue, cl_kernel, cl_uint, C.c_void_p, C.POINTER(size_t), C.c_void_p, cl_uint, C.c_void_p, C.c_void_p]
cl.clEnqueueNDRangeKernel.restype = cl_int
global_size = size_t(n_items)
check(cl.clEnqueueNDRangeKernel(queue, kernel, 1, None, C.byref(global_size), None, 0, None, None), "clEnqueueNDRangeKernel")

cl.clEnqueueReadBuffer.argtypes = [cl_command_queue, cl_mem, cl_bool, size_t, size_t, C.c_void_p, cl_uint, C.c_void_p, C.c_void_p]
cl.clEnqueueReadBuffer.restype = cl_int
check(cl.clEnqueueReadBuffer(queue, buf_o, CL_TRUE, 0, bytes_len, C.cast(out, C.c_void_p), 0, None, None), "clEnqueueReadBuffer")

for i in range(n_items):
    expected = a[i] + b[i]
    if abs(out[i] - expected) > 1e-5:
        raise RuntimeError(f"verification failed at {i}: got {out[i]} expected {expected}")
print(f"vectors={n_items}")
print("verdict=PASS")

for name, obj in (("clReleaseKernel", kernel), ("clReleaseProgram", program), ("clReleaseMemObject", buf_o), ("clReleaseMemObject", buf_b), ("clReleaseMemObject", buf_a), ("clReleaseCommandQueue", queue), ("clReleaseContext", context)):
    fn = getattr(cl, name, None)
    if fn and obj:
        fn(obj)
