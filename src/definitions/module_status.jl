"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module MODULE_STATUS
  const MODULE_DISABLE =  0  #            Enable (disable) use of this module if this status bit is 0 (1);
  const COMPASS_DISABLE =  1  #           Enable (disable) use of compass if this status bit is 0 (1);
  const HYDROPHONE_DISABLE =  2  #        Enable (disable) use of hydrophone if this status bit is 0 (1);
  const PIEZO_DISABLE =  3  #             Enable (disable) use of piezo if this status bit is 0 (1);
  const MODULE_OUT_OF_SYNC =  4  #        Enable (disable) synchronous signal from this module if this status bit is 0 (1);
  const TRANSMITTER_DISABLE =  5  #       Enable (disable) use of transmitter if this status bit is 0 (1);
end
