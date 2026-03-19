"""
# KM3NeT Data Definitions v3.6.2-2-g7bbf858
https://git.km3net.de/common/km3net-dataformat
"""

module FITPARAMETERS
  const JGANDALF_BETA0_RAD = 0  # uncertainty on the reconstructed track direction from the error matrix [rad]                                                     see JRECONSTRUCTION::JMuonGandalf
  const JGANDALF_BETA1_RAD = 1  # uncertainty on the reconstructed track direction from the error matrix [rad]                                                     see JRECONSTRUCTION::JMuonGandalf
  const JGANDALF_NUMBER_OF_HITS = 3  # number of hits                                                                                                              see JRECONSTRUCTION::JMuonGandalf
  const JENERGY_ENERGY = 4  # uncorrected energy [GeV]                                                                                                             see JRECONSTRUCTION::JMuonEnergy
  const JENERGY_CHI2 = 5  # chi2                                                                                                                                   see JRECONSTRUCTION::JMuonEnergy
  const JGANDALF_LAMBDA = 6  # largest eigenvalue of error matrix                                                                                                  see JRECONSTRUCTION::JMuonGandalf
  const JGANDALF_NUMBER_OF_ITERATIONS = 7  # number of iterations                                                                                                  see JRECONSTRUCTION::JMuonGandalf
  const JGANDALF_LIKELIHOOD_RATIO = 2  # likelihood ratio between this and best alternative fit                                                                    see JRECONSTRUCTION::JMuonGandalf
  const JMUONFEATURES_NUMBER_OF_HITS = 25  # number of hits                                                                                                        see JRECONSTRUCTION::JMuonFeatures
  const JMUONFEATURES_NUMBER_OF_DOMS = 23  # number of doms                                                                                                        see JRECONSTRUCTION::JMuonFeatures
  const JMUONFEATURES_NUMBER_OF_LINES = 24  # number of lines                                                                                                      see JRECONSTRUCTION::JMuonFeatures
  const JSTART_NPE_MIP_TOTAL = 9  # number of photo-electrons along the whole track                                                                                see JRECONSTRUCTION::JMuonStart
  const JSTART_NPE_MIP_MISSED = 22  # number of photo-electrons missed                                                                                             see JRECONSTRUCTION::JMuonStart
  const JSTART_BACKGROUND_LOGP = 8  # summed logarithm of background probabilities                                                                                 see JRECONSTRUCTION::JMuonStart
  const JSTART_LENGTH_METRES = 10  # distance between projected positions on the track of optical modules for which the response does not conform with background  see JRECONSTRUCTION::JMuonStart
  const JSTART_ZMIN_M = 11  # start position of track                                                                                                              see JRECONSTRUCTION::JMuonStart
  const JSTART_ZMAX_M = 12  # end position of track                                                                                                                see JRECONSTRUCTION::JMuonStart
  const JENERGY_MUON_RANGE_METRES = 13  # range of a muon with the reconstructed energy [m]                                                                        see JRECONSTRUCTION::JMuonEnergy
  const JENERGY_NOISE_LIKELIHOOD = 14  # log likelihood of every hit being K40                                                                                     see JRECONSTRUCTION::JMuonEnergy
  const JENERGY_NDF = 15  # number of degrees of freedom                                                                                                           see JRECONSTRUCTION::JMuonEnergy
  const JENERGY_NUMBER_OF_HITS = 16  # number of hits                                                                                                              see JRECONSTRUCTION::JMuonEnergy
  const JPP_COVERAGE_ORIENTATION = 18  # coverage of dynamic orientation calibration of this event                                                                              
  const JPP_COVERAGE_POSITION = 19  # coverage of dynamic position calibration of this event                                                                                    
  const JENERGY_MINIMAL_ENERGY = 20  # minimal energy [GeV]                                                                                                        see JRECONSTRUCTION::JMuonEnergy
  const JENERGY_MAXIMAL_ENERGY = 21  # maximal energy [GeV]                                                                                                        see JRECONSTRUCTION::JMuonEnergy
  const JSHOWERFIT_ENERGY = 4  # uncorrected energy [GeV]                                                                                                          see JRECONSTRUCTION::JShowerFit
  const AASHOWERFIT_ENERGY = 0  # uncorrected energy [GeV]
  const AASHOWERFIT_NUMBER_OF_HITS = 1  # number of hits used
end
