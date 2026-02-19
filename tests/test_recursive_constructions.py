import pytest
from pycfftables import CFF, CFFTable

def test_ext_by_one():
    initial_cff = CFF.sts(9)
    cff = CFF.extend_by_one(initial_cff)
    assert cff
    assert cff.verify()
    print(cff)

def test_doubling():
    initial_cff = CFF.sts(9)
    cff = CFF.double(initial_cff)
    assert cff
    assert cff.verify()
    print(cff)

def test_additive():
    left = CFF.sts(9)
    right = CFF.sts(13)
    cff = CFF.add(left, right)
    assert cff
    assert cff.verify()
    print(cff)

def test_kronecker():
    left = CFF.sts(9)
    right = CFF.sts(13)
    cff = CFF.kronecker(left, right)
    assert cff
    assert cff.verify()
    print(cff)