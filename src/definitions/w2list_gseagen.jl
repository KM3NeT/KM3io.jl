"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module W2LIST_GSEAGEN
  const W2LIST_GSEAGEN_PS = 0  # Constant factor in the weight (global generation weight)
  const W2LIST_GSEAGEN_EG = 1  # E gamma
  const W2LIST_GSEAGEN_XSEC_MEAN = 2  # Average interaction cross-section per nucleon along the neutrino path throuh the Earth (in units of m2)
  const W2LIST_GSEAGEN_COLUMN_DEPTH = 3  # Line integrated column density through the Earth for the neutrino direction
  const W2LIST_GSEAGEN_P_EARTH = 4  # Transmission probability in the Earth (XSEC_MEAN and COLUMN_DEPTH used to compute PEarth)
  const W2LIST_GSEAGEN_WATER_INT_LEN = 5  # Interaction length in pure water in m
  const W2LIST_GSEAGEN_P_SCALE = 6  # Interaction probability scale
  const W2LIST_GSEAGEN_BX = 7  # Bjorken x
  const W2LIST_GSEAGEN_BY = 8  # Bjorken y
  const W2LIST_GSEAGEN_ICHAN = 9  # Interaction channel
  const W2LIST_GSEAGEN_CC = 10  # Charged current interaction flag
  const W2LIST_GSEAGEN_DISTAMAX = 11  # distance added to the radius of the generation surface (relevant for CORSIKA muons)
  const W2LIST_GSEAGEN_WATERXSEC = 12  # inclusive xsec in water
  const W2LIST_GSEAGEN_XSEC = 13  # exclusive total cross section of the interaction
  const W2LIST_GSEAGEN_DXSEC = 14  # differential cross section of the interaction (dsigma/dxdy) extracted from genie
  const W2LIST_GSEAGEN_TARGETA = 15  # number of nuclons in the target 
  const W2LIST_GSEAGEN_TARGETZ = 16  # number of protons in the target
  const W2LIST_GSEAGEN_VERINCAN = 17  # flag indicating the vertex is in the can
  const W2LIST_GSEAGEN_LEPINCAN = 18  # flag indicating a lepton reached the can
  const W2LIST_GSEAGEN_N_RETRIES = 19  # Number of extra chances given to each CORSIKA shower to hit the can
  const W2LIST_GSEAGEN_CUSTOM_YAW = 20  # user-specified rotation of CORSIKA showers (around z-axis)
  const W2LIST_GSEAGEN_CUSTOM_PITCH = 21  # user-specified rotation of CORSIKA showers (around y-axis)
  const W2LIST_GSEAGEN_CUSTOM_ROLL = 22  # user-specified rotation of CORSIKA showers (around x-axis)
end
