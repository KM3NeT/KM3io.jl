"""
# KM3NeT Data Definitions v3.6.0
https://git.km3net.de/common/km3net-dataformat
"""

module TRKMEMBERS
  const TRK_MOTHER_UNDEFINED = -1
  const TRK_MOTHER_NONE = -2
  const TRK_ST_UNDEFINED = 0
  const TRK_ST_FINALSTATE = 1
  const TRK_ST_PRIMARYNEUTRINO = 100
  const TRK_ST_PRIMARYCOSMIC = 200
  const TRK_ST_MUONBUNDLE = 300
  const TRK_ST_ININUCLEI = 5
  const TRK_ST_INTERSTATE = 2
  const TRK_ST_DECSTATE = 3
  const TRK_ST_NUCTGT = 11
  const TRK_ST_PREHAD = 12
  const TRK_ST_PRERES = 13
  const TRK_ST_HADNUC = 14
  const TRK_ST_NUCLREM = 15
  const TRK_ST_NUCLCLT = 16
  const TRK_ST_FAKECORSIKA = 21
  const TRK_ST_FAKECORSIKA_DEC_MU_START = 22
  const TRK_ST_FAKECORSIKA_DEC_MU_END = 23
  const TRK_ST_FAKECORSIKA_ETA_2GAMMA = 24
  const TRK_ST_FAKECORSIKA_ETA_3PI0 = 25
  const TRK_ST_FAKECORSIKA_ETA_PIP_PIM_PI0 = 26
  const TRK_ST_FAKECORSIKA_ETA_2PI_GAMMA = 27
  const TRK_ST_FAKECORSIKA_CHERENKOV_GAMMA = 28
  const TRK_ST_PROPLEPTON = 1001
  const TRK_ST_PROPDECLEPTON = 2001
  const PDG_MUONBUNDLE = 81
end
