"""
    nthbitset(n, a) = !Bool((a >> (n - 1)) & 1)
Return `true` if the n-th bit of `a` is set, `false` otherwise.
"""
nthbitset(n, a) = Bool((a >> n) & 1)


is3dmuon(e::DAQEvent) = nthbitset(Trigger.JTRIGGER3DMUON, e.trigger_mask)
is3dshower(e::DAQEvent) = nthbitset(Trigger.JTRIGGER3DSHOWER, e.trigger_mask)
ismxshower(e::DAQEvent) = nthbitset(Trigger.JTRIGGERMXSHOWER, e.trigger_mask)
isnb(e::DAQEvent) = nthbitset(Trigger.JTRIGGERNB, e.trigger_mask)
is3dmuon(x) = nthbitset(Trigger.JTRIGGER3DMUON, x)
is3dshower(x) = nthbitset(Trigger.JTRIGGER3DSHOWER, x)
ismxshower(x) = nthbitset(Trigger.JTRIGGERMXSHOWER, x)
isnb(x) = nthbitset(Trigger.JTRIGGERNB, x)
