"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module W2LIST_KM3NEUT
  const W2LIST_KM3NEUT_PS = 0  # Constant factor in the weight (global generation weight)
  const W2LIST_KM3NEUT_EG = 1  # E gamma
  const W2LIST_KM3NEUT_XSEC_MEAN = 2  # Average interaction cross-section per nucleon along the neutrino path throuh the Earth (in units of m2)
  const W2LIST_KM3NEUT_COLUMN_DEPTH = 3  # Line integrated column density through the Earth for the neutrino direction
  const W2LIST_KM3NEUT_P_EARTH = 4  # Transmission probability in the Earth (XSEC_MEAN and COLUMN_DEPTH used to compute PEarth)
  const W2LIST_KM3NEUT_WATER_INT_LEN = 5  # Interaction length in pure water in m
  const W2LIST_KM3NEUT_P_SCALE = 6  # Interaction probability scale
  const W2LIST_KM3NEUT_BX = 7  # Bjorken x
  const W2LIST_KM3NEUT_BY = 8  # Bjorken y
  const W2LIST_KM3NEUT_ICHAN = 9  # Interaction channel converted to genie mode
  const W2LIST_KM3NEUT_CC = 10  # Charged current interaction flag
  const W2LIST_KM3NEUT_WATERXSEC = 12  # inclusive xsec in water
  const W2LIST_KM3NEUT_XSEC = 13  # total cross section of the interaction
  const W2LIST_KM3NEUT_DXSEC = 14  # differential cross section of the interaction (dsigma/dE)
  const W2LIST_KM3NEUT_TARGETA = 15  # number of nucleons in the target
  const W2LIST_KM3NEUT_TARGETZ = 16  # number of protons in the target
  const W2LIST_KM3NEUT_VERINCAN = 17  # flag indicating the vertex is in the can
  const W2LIST_KM3NEUT_LEPINCAN = 18  # flag indicating a lepton reached the can
  const W2LIST_KM3NEUT_MODE = 19  # Neut mode
end
