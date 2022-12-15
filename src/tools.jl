"""
    nthbitset(n, a) = !Bool((a >> (n - 1)) & 1)
Return `true` if the n-th bit of `a` is set, `false` otherwise.
"""
nthbitset(n, a) = Bool((a >> n) & 1)
