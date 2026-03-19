"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module W2LIST_KM3BUU
  const W2LIST_KM3BUU_PS = 0  # Constant factor in the weight (global generation weight)
  const W2LIST_KM3BUU_EG = 1  # E gamma
  const W2LIST_KM3BUU_XSEC_MEAN = 2  #  Mean cross section of this process
  const W2LIST_KM3BUU_COLUMN_DEPTH = 3  # Line integrated column density through the Earth for the neutrino direction
  const W2LIST_KM3BUU_P_EARTH = 4  # Transmission probability in the Earth
  const W2LIST_KM3BUU_WATER_INT_LEN = 5  # Interaction length in pure water in m
  const W2LIST_KM3BUU_BX = 7  # Bjorken x
  const W2LIST_KM3BUU_BY = 8  # Bjorken y
  const W2LIST_KM3BUU_ICHAN = 9  # Interaction channel
  const W2LIST_KM3BUU_CC = 10  # Charged current interaction flag
  const W2LIST_KM3BUU_XSEC = 13  # effective total cross section of the interaction
  const W2LIST_KM3BUU_DXSEC = 14  # differential cross section of the interaction (dsigma/dxdy) extracted from genie
  const W2LIST_KM3BUU_TARGETA = 15  # number of nuclons in the target 
  const W2LIST_KM3BUU_TARGETZ = 16  # number of protons in the target
  const W2LIST_KM3BUU_VERINCAN = 17  # flag indicating the vertex is in the can
  const W2LIST_KM3BUU_LEPINCAN = 18  # flag indicating a lepton reached the can
  const W2LIST_KM3BUU_GIBUU_WEIGHT = 23  # GiBUU weight value
  const W2LIST_KM3BUU_GIBUU_SCAT_TYPE = 24  # GiBUU scattering type identifier
  const W2LIST_KM3BUU_LEPPROP_SAMPLES = 25  # KM3BUU lepton propagation resample attempts
end
