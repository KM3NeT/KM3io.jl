"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module ROOT
  const TTREE_ONLINE_TIMESLICE =     "KM3NET_TIMESLICE"     #   ROOT TTree name
  const TTREE_ONLINE_TIMESLICEL0 =   "KM3NET_TIMESLICE_L0"  #   ROOT TTree name
  const TTREE_ONLINE_TIMESLICEL1 =   "KM3NET_TIMESLICE_L1"  #   ROOT TTree name
  const TTREE_ONLINE_TIMESLICEL2 =   "KM3NET_TIMESLICE_L2"  #   ROOT TTree name
  const TTREE_ONLINE_TIMESLICESN =   "KM3NET_TIMESLICE_SN"  #   ROOT TTree name
  const TTREE_ONLINE_SUMMARYSLICE =  "KM3NET_SUMMARYSLICE"  #   ROOT TTree name
  const TTREE_ONLINE_EVENT =         "KM3NET_EVENT"         #   ROOT TTree name
  const TTREE_OFFLINE_EVENT =        "E"                    #   ROOT TTree name
  const TTREE_OSC_OPENDATA_NU =      "binned_nu_response"   #   ROOT TTree name
  const TTREE_OSC_OPENDATA_DATA =    "binned_data"          #   ROOT TTree name
  const TTREE_OSC_OPENDATA_MUONS =   "binned_muon"          #   ROOT TTree name
  const TBRANCH_ONLINE_TIMESLICE =     "KM3NET_TIMESLICE"     #   ROOT TBranch name
  const TBRANCH_ONLINE_TIMESLICEL0 =   "km3net_timeslice_L0"  #   ROOT TBranch name
  const TBRANCH_ONLINE_TIMESLICEL1 =   "km3net_timeslice_L1"  #   ROOT TBranch name
  const TBRANCH_ONLINE_TIMESLICEL2 =   "km3net_timeslice_L2"  #   ROOT TBranch name
  const TBRANCH_ONLINE_TIMESLICESN =   "km3net_timeslice_SN"  #   ROOT TBranch name
  const TBRANCH_ONLINE_SUMMARYSLICE =  "KM3NET_SUMMARYSLICE"  #   ROOT TBranch name
  const TBRANCH_ONLINE_EVENT =         "KM3NET_EVENT"         #   ROOT TBranch name
  const TBRANCH_OFFLINE_EVENT =        "Evt"                  #   ROOT TBranch name
  const COMPRESSION_LEVEL_ONLINE_TIMESLICE =     0  #   compression level
  const COMPRESSION_LEVEL_ONLINE_TIMESLICEL0 =   0  #   compression level
  const COMPRESSION_LEVEL_ONLINE_TIMESLICEL1 =   2  #   compression level
  const COMPRESSION_LEVEL_ONLINE_TIMESLICEL2 =   2  #   compression level
  const COMPRESSION_LEVEL_ONLINE_TIMESLICESN =   2  #   compression level
  const COMPRESSION_LEVEL_ONLINE_SUMMARYSLICE =  1  #   compression level
  const COMPRESSION_LEVEL_ONLINE_EVENT =         0  #   compression level
  const COMPRESSION_LEVEL_OFFLINE_EVENT =        1  #   compression level
  const BASKET_SIZE_ONLINE_TIMESLICE =       5000000  #   basket size
  const BASKET_SIZE_ONLINE_TIMESLICEL0 =   500000000  #   basket size
  const BASKET_SIZE_ONLINE_TIMESLICEL1 =     5000000  #   basket size
  const BASKET_SIZE_ONLINE_TIMESLICEL2 =     5000000  #   basket size
  const BASKET_SIZE_ONLINE_TIMESLICESN =     5000000  #   basket size
  const BASKET_SIZE_ONLINE_SUMMARYSLICE =    5000000  #   basket size
  const BASKET_SIZE_ONLINE_EVENT =           5000000  #   basket size
  const BASKET_SIZE_OFFLINE_EVENT =          5000000  #   basket size
  const SPLIT_LEVEL_ONLINE_TIMESLICE =     1  #   split level
  const SPLIT_LEVEL_ONLINE_TIMESLICEL0 =   2  #   split level
  const SPLIT_LEVEL_ONLINE_TIMESLICEL1 =   2  #   split level
  const SPLIT_LEVEL_ONLINE_TIMESLICEL2 =   2  #   split level
  const SPLIT_LEVEL_ONLINE_TIMESLICESN =   2  #   split level
  const SPLIT_LEVEL_ONLINE_SUMMARYSLICE =  1  #   split level
  const SPLIT_LEVEL_ONLINE_EVENT =         1  #   split level
  const SPLIT_LEVEL_OFFLINE_EVENT =        4  #   split level
  const AUTOFLUSH_LEVEL_ONLINE_TIMESLICE =     1000  #   auto flush
  const AUTOFLUSH_LEVEL_ONLINE_TIMESLICEL0 =   1000  #   auto flush
  const AUTOFLUSH_LEVEL_ONLINE_TIMESLICEL1 =   1000  #   auto flush
  const AUTOFLUSH_LEVEL_ONLINE_TIMESLICEL2 =   1000  #   auto flush
  const AUTOFLUSH_LEVEL_ONLINE_TIMESLICESN =   1000  #   auto flush
  const AUTOFLUSH_LEVEL_ONLINE_SUMMARYSLICE =  1000  #   auto flush
  const AUTOFLUSH_LEVEL_ONLINE_EVENT =         1000  #   auto flush
  const AUTOFLUSH_LEVEL_OFFLINE_EVENT =         500  #   auto flush
end
