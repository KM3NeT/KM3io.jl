"""
    nthbitset(n, a) = !Bool((a >> (n - 1)) & 1)
Return `true` if the n-th bit of `a` is set, `false` otherwise.
"""
nthbitset(n, a) = Bool((a >> n) & 1)


is3dmuon(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGER3DMUON, e.header.trigger_mask)
is3dshower(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGER3DSHOWER, e.header.trigger_mask)
ismxshower(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGERMXSHOWER, e.header.trigger_mask)
isnb(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGERNB, e.header.trigger_mask)
is3dmuon(x) = nthbitset(TRIGGER.JTRIGGER3DMUON, x)
is3dshower(x) = nthbitset(TRIGGER.JTRIGGER3DSHOWER, x)
ismxshower(x) = nthbitset(TRIGGER.JTRIGGERMXSHOWER, x)
isnb(x) = nthbitset(TRIGGER.JTRIGGERNB, x)
