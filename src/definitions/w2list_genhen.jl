"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module W2LIST_GENHEN
  const W2LIST_GENHEN_GLOBAL_GEN_WEIGHT = 0  # Constant factor in the weight (global generation weight)
  const W2LIST_GENHEN_EG = 1  # E gamma
  const W2LIST_GENHEN_SIG = 2  # Cross section of the neutrion interaction
  const W2LIST_GENHEN_COLUMN_DEPTH = 3  # Line integrated column density through the Earth for the neutrino direction
  const W2LIST_GENHEN_P_EARTH = 4  # Transmission probability in the Earth
  const W2LIST_GENHEN_REFF = 5  # Effective muon range
  const W2LIST_GENHEN_BX = 7  # Bjorken x
  const W2LIST_GENHEN_BY = 8  # Bjorken y
  const W2LIST_GENHEN_ICHAN = 9  # Interaction channel
  const W2LIST_GENHEN_CC = 10  # Charged current interaction flag
end
