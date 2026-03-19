"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module TRKMEMBERS
  const TRK_MOTHER_UNDEFINED = -1  # mother id was not defined for this track
  const TRK_MOTHER_NONE = -2  # mother id of a particle if it has no parent
  const TRK_ST_UNDEFINED = 0  # MC or reco status was not defined for this track
  const TRK_ST_FINALSTATE = 1  # for MC: the particle must be processed by detector simulation ('track_in' tag in evt files). For reconstructed tracks: this track is the final stage in the reco chain (tracks from preceding stages have TRK_ST_UNDEFINED)
  const TRK_ST_PRIMARYNEUTRINO = 100  # initial state neutrino ('neutrino' tag in evt files from gseagen and genhen).
  const TRK_ST_PRIMARYCOSMIC = 200  # initial state cosmic ray ('track_primary' tag in evt files from corant).
  const TRK_ST_MUONBUNDLE = 300  # initial state muon bundle (mupage)
  const TRK_ST_ININUCLEI = 5  # Initial state nuclei (gseagen)
  const TRK_ST_INTERSTATE = 2  # Intermediate state particles produced in hadronic showers (gseagen)
  const TRK_ST_DECSTATE = 3  # Short-lived particles that are forced to decay
  const TRK_ST_NUCTGT = 11  # Nucleon target (gseagen)
  const TRK_ST_PREHAD = 12  # DIS pre-fragmentation hadronic state (gseagen)
  const TRK_ST_PRERES = 13  # resonant pre-decayed state (gseagen)
  const TRK_ST_HADNUC = 14  # Hadrons inside the nucleus before FSI (gseagen)
  const TRK_ST_NUCLREM = 15  # Low energy nuclear fragments (gseagen)
  const TRK_ST_NUCLCLT = 16  # For composite nucleons before phase space decay (gseagen)
  const TRK_ST_FAKECORSIKA = 21  # fake particle from corant/CORSIKA to add parent information (gseagen)
  const TRK_ST_FAKECORSIKA_DEC_MU_START = 22  # fake particle from CORSIKA: decaying mu at start (gseagen)
  const TRK_ST_FAKECORSIKA_DEC_MU_END = 23  # fake particle from CORSIKA: decaying mu at end (gseagen)
  const TRK_ST_FAKECORSIKA_ETA_2GAMMA = 24  # fake particle from CORSIKA: eta -> 2 gamma (gseagen)
  const TRK_ST_FAKECORSIKA_ETA_3PI0 = 25  # fake particle from CORSIKA: eta -> 3 pi0 (gseagen)
  const TRK_ST_FAKECORSIKA_ETA_PIP_PIM_PI0 = 26  # fake particle from CORSIKA: eta -> pi+ pi- pi0 (gseagen)
  const TRK_ST_FAKECORSIKA_ETA_2PI_GAMMA = 27  # fake particle from CORSIKA: eta -> pi+ pi- gamma (gseagen)
  const TRK_ST_FAKECORSIKA_CHERENKOV_GAMMA = 28  # fake particle from CORSIKA: Cherenkov photons on particle output file (gseagen)
  const TRK_ST_PROPLEPTON = 1001  # lepton propagated that reaches the can (gseagen)
  const TRK_ST_PROPDECLEPTON = 2001  # lepton propagated and decayed before got to the can (gseagen)
  const PDG_MUONBUNDLE = 81  # muon bundle reached the can level (mupage)
end
