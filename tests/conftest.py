import ctypes

def pytest_configure(config):
    ctypes.CDLL('libflint.so', mode=ctypes.RTLD_GLOBAL)