"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module TRIGGER
  const JTRIGGER3DSHOWER = 1  # Shower trigger
  const JTRIGGERMXSHOWER = 2  # Shower trigger L0/L1
  const JTRIGGER3DMUON = 4  # Muon trigger
  const JTRIGGERNB = 5  # Nano-beacon trigger
  const FACTORY_LIMIT = 31  # Bit indicating max nhits reached in trigger
end
