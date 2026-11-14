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


# check ability to open CDM
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sql server",
  server = "vhacdwdwhdbs102"
)

connect <- DatabaseConnector::connect(connectionDetails = connectionDetails)

DatabaseConnector::renderTranslateQuerySql(
  connection = connect,
  sql = "select count(*) from @cdm.person;",
  cdm = "CDW_OMOP.OMOPV5"
)

DatabaseConnector::disconnect(connect)

