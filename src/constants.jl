const WATER_INDEX = 1.3499  # Used in aanet
const INDEX_OF_REFRACTION_WATER = 1.3800851282  # Used in Jpp (e.g. in PDFs)
const DN_DL = 0.0298
const COS_CHERENKOV = 1 / WATER_INDEX
const CHERENKOV_ANGLE_RAD = math.acos(COS_CHERENKOV)
const SIN_CHERENKOV = math.sin(CHERENKOV_ANGLE_RAD)
const TAN_CHERENKOV = math.tan(CHERENKOV_ANGLE_RAD)
const C_LIGHT = 299792458e-9  # m/ns
const V_LIGHT_WATER = C_LIGHT / (WATER_INDEX + DN_DL)
const C_WATER = C_LIGHT / INDEX_OF_REFRACTION_WATER
const c = 2.99792458e8  # m/s
