# ENVIRONMENT SETTINGS NEEDED FOR RUNNING STUDY IN ENVIRONMENT ------------
R_HADES_ENV_PATH <- "" # Set this to the base folder of the R HADES environment using '/' for folder hierarchy

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING STUDY IN ENVIRONMENT ------------
Sys.setenv("_JAVA_OPTIONS"="-Xmx4g") # Sets the Java maximum heap space to 4GB
Sys.setenv("VROOM_THREADS"=1) # Sets the number of threads to 1 to avoid deadlocks on file system
Sys.setenv(JAVA_HOME=paste0(R_HADES_ENV_PATH, "/extras/jdk1.8")) # may need to be a fully specified path

# may need to be a fully specified path
Sys.setenv(DATABASECONNECTOR_JAR_FOLDER=paste0(R_HADES_ENV_PATH, "/extras"))

## Run on simulated data
# cdmSchema = "OHDSI_OMOP.Dev"
# targetTable = "OHDSI_OMOP.DevResults.cohort"
# resultSchema = "OHDSI_OMOP.DevResults"
# vocabularySchema = "OHDSI_OMOP.DevVocabulary"
# cdmDatabaseSchema = cdmSchema
# cohortDatabaseSchema = resultSchema
# cdmDatabaseId = "OHDSI_OMOP Dev"


## Run on CDW OMOP data
cdmSchema = "OHDSI_OMOP.CDW"
targetTable = "OHDSI_OMOP.CDWResults.cohort"
resultSchema = "OHDSI_OMOP.CDWResults"
vocabularySchema = "OHDSI_OMOP.CDWVocabulary"
cdmDatabaseSchema = cdmSchema
cohortDatabaseSchema = resultSchema
cdmDatabaseId = "OHDSI_OMOP CDW OMOP"

library(Capr)

# Hypertension
essentialHypertension <- cs(
  descendants(320128),
  name="Essential hypertension"
)

sbp <- cs(3004249, name="SBP")
dbp <- cs(3012888, name="DBP")

hypertensionCohort <- cohort(
  entry = entry(
    conditionOccurrence(essentialHypertension),
    measurement(sbp, valueAsNumber(gte(130)), measurementUnit(8876)),
    measurement(dbp, valueAsNumber(gte(80)), measurementUnit(8876))
  ),
  exit= exit(
    endStrategy = observationExit()
  )
)

# Acute myocardial infarction
myocardialInfarction <- cs(
  descendants(4329847),
  exclude(descendants(314666)),
  name = "Myocardial infarction"
)

inpatientOrEr <- cs(
  descendants(9201),
  descendants(262),
  name = "Inpatient or ER"
)

amiCohort <- cohort(
  entry = entry(
    conditionOccurrence(myocardialInfarction),
    additionalCriteria = withAll(
      atLeast(1,
              visit(inpatientOrEr),
              aperture = duringInterval(eventStarts(-Inf,0), eventEnds(0,Inf)))
    ),
    primaryCriteriaLimit = "All",
    qualifiedLimit = "All"
  ),
  attrition = attrition(
    "No prior AMI" = withAll(
      exactly(0,
              conditionOccurrence(myocardialInfarction),
              duringInterval(eventStarts(-365,-1)))
    )
  ),
  exit = exit(
    endStrategy = fixedExit(index = "startDate", offsetDays = 1)
  )
)

generateOptions <- CirceR::createGenerateOptions(
  cohortIdFieldName = "cohort_definition_id",
  cdmSchema = cdmSchema,
  targetTable = targetTable,
  resultSchema = resultSchema,
  vocabularySchema = vocabularySchema,
  generateStats = TRUE
)

sql <- CirceR::buildCohortQuery(CirceR::cohortExpressionFromJson(Capr::as.json(hypertensionCohort)), generateOptions)
#sql <- gsub("@vocabulary_database_schema", vocabularyDatabaseSchema, sql, fixed = TRUE)
htnCohortDF <- data.frame(
              cohortId = -100,
              cohortName = "PLP Test Hypertension cohort",
              sql = sql,
              json =Capr::as.json(hypertensionCohort),
              stringsAsFactors = FALSE
  )

sql <- CirceR::buildCohortQuery(CirceR::cohortExpressionFromJson(Capr::as.json(amiCohort)), generateOptions)
#sql <- gsub("@vocabulary_database_schema", vocabularyDatabaseSchema, sql, fixed = TRUE)
amiCohortDF <- data.frame(
              cohortId = -200,
              cohortName = "PLP Test AMI cohort",
              sql = sql,
              json =Capr::as.json(amiCohort),
              stringsAsFactors = FALSE
)

cohortDefinitionSet <- rbind(
  htnCohortDF, amiCohortDF
)

# check ability to open CDM
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sql server",
  server = "vhacdwdwhdbs102"
)
# connect <- DatabaseConnector::connect(connectionDetails = connectionDetails)


cohortTableNames <- CohortGenerator::getCohortTableNames(
  cohortTable = "cohort"
)

#CohortGenerator::createCohortTables(
#  connectionDetails = connectionDetails,
#  cohortDatabaseSchema = "DevResults",
#  cohortTableNames = cohortTableNames
#)


cohortsGenerated <- CohortGenerator::generateCohortSet(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = resultSchema,
  cohortTableNames = cohortTableNames,
  cohortDefinitionSet = cohortDefinitionSet
)

CohortGenerator::getCohortCounts(
  connectionDetails = connectionDetails,
  cohortDatabaseSchema = resultSchema,
  cohortTable = cohortTableNames$cohortTable
)

library(FeatureExtraction)

covariateSettings <- FeatureExtraction::createCovariateSettings(
  useDemographicsGender = TRUE,
  useDemographicsAgeGroup = TRUE,
  useConditionGroupEraLongTerm = TRUE,
  useConditionGroupEraAnyTimePrior = TRUE,
  useVisitConceptCountLongTerm = TRUE,
  longTermStartDays = -365,
  endDays = -1
)

library(PatientLevelPrediction)

databaseDetails <- createDatabaseDetails(
  connectionDetails = connectionDetails,
  cdmDatabaseName = cdmSchema,
  cdmDatabaseId = cdmDatabaseId,
  cdmDatabaseSchema = cdmSchema,
  cohortDatabaseSchema = resultSchema,
  cohortTable = cohortTableNames$cohortTable,
  targetId = -100,
  outcomeIds = c(-200)
)

restrictPlpDataSettings <- createRestrictPlpDataSettings(
  firstExposureOnly = TRUE,
  washoutPeriod = 365,
  sampleSize = 10000
)

plpData <- getPlpData(
  databaseDetails = databaseDetails,
  covariateSettings = covariateSettings,
  restrictPlpDataSettings = restrictPlpDataSettings
)
savePlpData(plpData, file.path(getwd(),"data","plpData"))

plpData <- loadPlpData(plpData, file.path(getwd(),"data","plpData"))

populationSettings <- createStudyPopulationSettings(
  riskWindowStart = 1,
  startAnchor = "cohort start",
  riskWindowEnd = 365,
  endAnchor = "cohort start",
  removeSubjectsWithPriorOutcome = TRUE
)

splitSettings <- createDefaultSplitSetting(
  trainFraction = 0.75,
  testFraction = 0.25,
  type = "stratified",
  nfold = 2,
  splitSeed = 123
)

featureEngineeringSettings <- createFeatureEngineeringSettings()

sampleSettings <- createSampleSettings()

preprocessSettings <- createPreprocessSettings(
  minFraction = 0.01,
  normalize = TRUE,
  removeRedundancy = TRUE
)

lrResults <- runPlp(
  plpData = plpData,
  outcomeId = -200,
  analysisId = "lrDemo",
  analysisName = "Demonstration of runPlp for training single PLP models",
  populationSettings = populationSettings,
  splitSettings = splitSettings,
  sampleSettings = sampleSettings,
  featureEngineeringSettings = featureEngineeringSettings,
  preprocessSettings = preprocessSettings,
  modelSettings = setLassoLogisticRegression(),
  logSettings = createLogSettings(),
  executeSettings = createExecuteSettings(
    runSplitData = TRUE,
    runSampleData = TRUE,
    runFeatureEngineering = TRUE,
    runPreprocessData = TRUE,
    runModelDevelopment = TRUE,
    runCovariateSummary = TRUE
  ),
  saveDirectory = file.path(getwd(), "data", "lrModel")
)

savePlpResult(lrResults, file.path(getwd(), "data", "model"))

lrResults <- loadPlpResult(file.path(getwd(), "data", "model"))

viewPlp(lrResults)

plotPlp(lrResults, file.path(getwd(), "data", "plot"))


learningCurve <- createLearningCurve(
  plpData = plpData,
  outcomeId = 2,
  modelSettings = setLassoLogisticRegression(), # also tried lrResults and got the same error
  trainFractions = c(0.03125, 0.0625, 0.125, 0.25, 0.5),
  saveDirectory = file.path(getwd(), "data", "curve"))
## Note error
# Error in UseMethod("pivot_wider") :
#  no applicable method for 'pivot_wider' applied to an object of class "NULL"
## NOTE: probably b/c of sampling above to 10K which might yield 0 count

saveRDS(learningCurve, "learningCurve") # not ran due to error above
learningCurve <- readRDS("learningCurve") # not ran due to error above
plotLearningCurve(learningCurve, abscissa = "observations") # not ran due to error above

###

modelDesign <- list(
  createModelDesign( # first fit a L_1-regularized logistic regression
    targetId = -100,
    outcomeId = -200,
    restrictPlpDataSettings = restrictPlpDataSettings,
    populationSettings = populationSettings,
    covariateSettings = covariateSettings,
    featureEngineeringSettings = featureEngineeringSettings,
    sampleSettings = sampleSettings,
    preprocessSettings = preprocessSettings,
    splitSettings = splitSettings,
    modelSettings = setLassoLogisticRegression(
      seed = 123,
      threads = 4)
  ),
  createModelDesign( # second fit a gradient boosting machine
    targetId = -100,
    outcomeId = -200,
    restrictPlpDataSettings = restrictPlpDataSettings,
    populationSettings = populationSettings,
    covariateSettings = covariateSettings,
    featureEngineeringSettings = featureEngineeringSettings,
    sampleSettings = sampleSettings,
    preprocessSettings = preprocessSettings,
    splitSettings = splitSettings,
    modelSettings = setGradientBoostingMachine(
      ntrees = 300,
      nthread = 4,
      maxDepth = c(3,7,10))
  )
)

model <- runMultiplePlp(
  databaseDetails = databaseDetails,
  cohortDefinitions = cohortDefinitionSet,
  modelDesignList = modelDesign,
  saveDirectory = file.path(getwd(), "multipleModels"))

viewMultiplePlp(file.path(getwd(), "multipleModels"))



