"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module PMT_STATUS
  const PMT_DISABLE =  0  #               Enable (disable) use of this PMT if this status bit is 0 (1);
  const HIGH_RATE_VETO_DISABLE =  1  #    Enable (disable) use of high-rate veto test if this status bit is 0 (1);
  const FIFO_FULL_DISABLE =  2  #         Enable (disable) use of FIFO (almost) full test if this status bit is 0 (1);
  const UDP_COUNTER_DISABLE =  3  #       Enable (disable) use of UDP packet counter test if this status bit is 0 (1);
  const UDP_TRAILER_DISABLE =  4  #       Enable (disable) use of UDP packet trailer test if this status bit is 0 (1);
  const OUT_OF_SYNC =  5  #               Enable (disable) synchronous signal from this PMT if this status bit is 0 (1);
end
