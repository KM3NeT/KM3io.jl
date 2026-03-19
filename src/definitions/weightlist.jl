"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module WEIGHTLIST
  const WEIGHTLIST_GENERATION_AREA = 0  # Generation area (c.f. taglist document) [m2]
  const WEIGHTLIST_GENERATION_VOLUME = 0  # Generation volume (c.f. taglist document) [m3]
  const WEIGHTLIST_DIFFERENTIAL_EVENT_RATE = 1  # Event rate per unit of flux (c.f. taglist document) [GeV m2 sr]
  const WEIGHTLIST_EVENT_RATE = 2  # Event rate [s-1]
  const WEIGHTLIST_NORMALISATION = 3  # Event rate normalisation
  const WEIGHTLIST_RESCALED_EVENT_RATE = 4  # Rescaled event rate [s-1]
  const WEIGHTLIST_RUN_BY_RUN_WEIGHT = 5  #  w[1]*DAQ_livetime / MC_evts_summary::n_gen (gseagen; [GeV m2 sr s]) or DAQ_livetime/MC_evts_summary::livetime_sim (mupage; [-])
end
