"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module DAQDATATYPES
  const DAQSUPERFRAME = 101  # Super frame
  const DAQSUMMARYFRAME = 201  # Summary frame
  const DAQTIMESLICE = 1001  # Erroneous timeslice
  const DAQTIMESLICEL0 = 1002  # L0 timeslice
  const DAQTIMESLICEL1 = 1003  # L1 timeslice
  const DAQTIMESLICEL2 = 1004  # L2 timeslice
  const DAQTIMESLICESN = 1005  # Supernova timeslice
  const DAQSUMMARYSLICE = 2001  # Summaryslice
  const DAQEVENT = 10001  # DAQ event
end
