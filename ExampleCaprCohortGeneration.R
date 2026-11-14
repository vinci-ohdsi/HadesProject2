# Example project start-up
# @author Marc A Suchard

R_HADES_ENV_PATH <- "" # Set this to the base folder of the R HADES environment using '/' for folder hierarchy

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING STUDY IN ENVIRONMENT ------------
Sys.setenv("_JAVA_OPTIONS"="-Xmx4g") # Sets the Java maximum heap space to 4GB
Sys.setenv("VROOM_THREADS"=1) # Sets the number of threads to 1 to avoid deadlocks on file system
Sys.setenv(JAVA_HOME=paste0(R_HADES_ENV_PATH, "/extras/jdk1.8")) # may need to be a fully specified path

# may need to be a fully specified path
Sys.setenv(DATABASECONNECTOR_JAR_FOLDER=paste0(R_HADES_ENV_PATH, "/extras"))

library(DatabaseConnector)
library(Capr)

# check ability to open CDM
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sql server",
  server = "vhacdwdwhdbs102"
)
connect <- DatabaseConnector::connect(connectionDetails = connectionDetails)

# Define a simple concept set
cystitis <- cs(descendants(195588), name = "Cystitis")

#cystitis <- getConceptSetDetails(cystitis, connect, "SyncVA.OMOP")
cystitis <- getConceptSetDetails(cystitis, connect, "CDW_OMOP.OMOPV5")
cystitis

# Print the JSON of the concept set
as.json(cystitis)

# create a simple cystitis cohort
cystitisCohort <- cohort(entry = entry(conditionOccurrence(cystitis)))

# Create a cohort definition for a drug exposure
ketamineConceptId = 785649
ketamine  <- cs(
  descendants(ketamineConceptId),
  name = "ketamine"
)

# Inclusion criterion:
attrition = attrition(
  "No prior ketamine exposure" = withAll(
    exactly(0, drugExposure(ketamine), duringInterval(eventStarts(-Inf, -1)))
  )
)


ketamineCohort <- cohort(
  entry = entry(
    drugExposure(ketamine, firstOccurrence()),
    observationWindow = continuousObservation(priorDays = 365)
  ),
  attrition = attrition,
  exit = exit(endStrategy = drugExit(ketamine,
                                     persistenceWindow = 30,
                                     surveillanceWindow = 0))
)

#We can generate a print-friendly output of any cohort definition using the CirceR package:
rmarkdown <- CirceR::cohortPrintFriendly(toCirce(ketamineCohort))
writeLines(rmarkdown)


# Generate the cohorts
# First we need to create a “Cohort Set” object, after which we can instruct
# CohortGenerator to generate the cohorts:
cohortsToCreate <- makeCohortSet(cystitisCohort,
                                   ketamineCohort)

# Create the cohort tables to hold the cohort generation results
cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = "cohort")

CohortGenerator::createCohortTables(connectionDetails = connectionDetails,
                                    cohortDatabaseSchema = "OHDSI_OMOP.DevTemp",
                                    cohortTableNames = cohortTableNames,
                                    incremental=TRUE)

# Generate the cohorts
cohortsGenerated <- CohortGenerator::generateCohortSet(connectionDetails = connectionDetails,
                                                       cdmDatabaseSchema = "CDW_OMOP.OMOPV5",
                                                       #cdmDatabaseSchema = "SyncVA.OMOP",
                                                       cohortDatabaseSchema = "OHDSI_OMOP.DevTemp",
                                                       cohortTableNames = cohortTableNames,
                                                       cohortDefinitionSet = cohortsToCreate)


# To see that the cohorts generated successfully we can display the cohort counts:
CohortGenerator::getCohortCounts(connectionDetails = connectionDetails,
                                   cohortDatabaseSchema = "OHDSI_OMOP.DevTemp",
                                   cohortTable = cohortTableNames$cohortTable,
                                   cohortIds = c(1,2)
                                )

DatabaseConnector::disconnect(connect)

