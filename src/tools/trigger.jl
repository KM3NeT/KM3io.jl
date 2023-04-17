"""
Return `true` if the passed object (hit, event, ...) was triggered by any trigger algorithm.
"""
triggered(e) = e.trigger_mask > 0

"""
$(METHODLIST)

Return `true` the 3D Muon trigger bit is set.
"""
is3dmuon(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGER3DMUON, e.header.trigger_mask)
is3dmuon(x) = nthbitset(TRIGGER.JTRIGGER3DMUON, x)

"""
$(METHODLIST)

Return `true` if the 3D Shower trigger bit is set.
"""
is3dshower(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGER3DSHOWER, e.header.trigger_mask)
is3dshower(x) = nthbitset(TRIGGER.JTRIGGER3DSHOWER, x)

"""
$(METHODLIST)

Return `true` if the MX Shower trigger bit is set.
"""
ismxshower(x) = nthbitset(TRIGGER.JTRIGGERMXSHOWER, x)
ismxshower(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGERMXSHOWER, e.header.trigger_mask)

"""
$(METHODLIST)

Return `true` if the NanoBeacon trigger bit is set.
"""
isnb(x) = nthbitset(TRIGGER.JTRIGGERNB, x)
isnb(e::DAQEvent) = nthbitset(TRIGGER.JTRIGGERNB, e.header.trigger_mask)
