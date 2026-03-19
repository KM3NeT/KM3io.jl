"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module RECONSTRUCTION
  const JPP_RECONSTRUCTION_TYPE = 4000  # Jpp reconstruction type
  const JMUONBEGIN = 0  # begin range of reconstruction stages
  const JMUONPREFIT = 1  # 
  const JMUONSIMPLEX = 2  # 
  const JMUONGANDALF = 3  # 
  const JMUONENERGY = 4  # 
  const JMUONSTART = 5  # 
  const JLINEFIT = 6  # 
  const JMUONFEATURES = 7  # 
  const JMUONEND = 99  # end range of reconstruction stages
  const JSHOWERBEGIN = 100  # begin range of reconstruction stages
  const JSHOWERPREFIT = 101  # 
  const JSHOWERPOSITIONFIT = 102  # 	
  const JSHOWERCOMPLETEFIT = 103  # 	
  const JSHOWER_BJORKEN_Y = 104  # 
  const JSHOWERENERGYPREFIT = 105  # 
  const JSHOWERPOINTSIMPLEX = 106  # 	
  const JSHOWERDIRECTIONPREFIT = 107  # 
  const JSHOWEREND = 199  # end range of reconstruction stages
  const DUSJ_RECONSTRUCTION_TYPE = 200  # Dusj reconstruction type
  const DUSJSHOWERBEGIN = 200  # begin range of reconstruction stages
  const DUSJSHOWERPREFIT = 201  # 
  const DUSJSHOWERPOSITIONFIT = 202  # 
  const DUSJSHOWERCOMPLETEFIT = 203  # 
  const DUSJSHOWEREND = 299  # end range of reconstruction stages
  const AANET_RECONSTRUCTION_TYPE = 101  # aanet reconstruction type
  const AASHOWERBEGIN = 300  # begin range of reconstruction stages
  const AASHOWERFITPREFIT = 302  # 
  const AASHOWERFITPOSITIONFIT = 303  # 
  const AASHOWERFITDIRECTIONENERGYFIT = 304  # 
  const AASHOWEREND = 399  # end range of reconstruction stages
  const JUSERBEGIN = 1000  # begin range of user applications
  const JMUONVETO = 1001  # 
  const JMUONPATH = 1003  # 
  const JMCEVT = 1004  # 
  const JUSEREND = 1099  # begin range of user applications
  const RECTYPE_UNKNOWN = -1  # default value for unofficial or development versions
  const RECSTAGE_UNKNOWN = -1  # default value for unofficial or development versions
end
