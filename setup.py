# setup.py
from setuptools import setup, Extension
from Cython.Build import cythonize
import subprocess
import sys

def get_pkg_config(package, option):
    try:
        result = subprocess.run(
            ['pkg-config', option, package],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip().split()
    except subprocess.CalledProcessError as e:
        print(f"Error: pkg-config failed for {package}")
        sys.exit(1)
    except FileNotFoundError:
        print("Error: pkg-config not found.")
        sys.exit(1)

# Get flags for libcfftables
cflags = get_pkg_config('libcfftables', '--cflags')
libs = get_pkg_config('libcfftables', '--libs')

# Parse the flags into setuptools format
include_dirs = [flag[2:] for flag in cflags if flag.startswith('-I')]
library_dirs = [flag[2:] for flag in libs if flag.startswith('-L')]
libraries = [flag[2:] for flag in libs if flag.startswith('-l')]

print(f"Found libcfftables:")
print(f"  Include dirs: {include_dirs}")
print(f"  Library dirs: {library_dirs}")
print(f"  Libraries: {libraries}")

# Define the Cython extension
extensions = [
    Extension(
        name="pycfftables._lib",
        sources=["src/pycfftables/_lib.pyx"],
        include_dirs=include_dirs,
        library_dirs=library_dirs,
        libraries=libraries,
        language="c",
    )
]

setup(
    ext_modules=cythonize(
        extensions,
        compiler_directives={
            'language_level': "3",
            'boundscheck': False,
            'wraparound': False,
            'embedsignature': True,
            'binding': True,
        },
        annotate = True,
    ),
)