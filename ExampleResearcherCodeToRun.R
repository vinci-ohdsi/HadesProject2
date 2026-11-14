# Example researcher project start-up
# @author Marc A Suchard

R_HADES_ENV_PATH <- "" # Set this to the base folder of the R HADES environment using '/' for folder hierarchy

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING STUDY IN ENVIRONMENT ------------
Sys.setenv("_JAVA_OPTIONS"="-Xmx4g") # Sets the Java maximum heap space to 4GB
Sys.setenv("VROOM_THREADS"=1) # Sets the number of threads to 1 to avoid deadlocks on file system
Sys.setenv(JAVA_HOME=paste0(R_HADES_ENV_PATH, "/extras/jdk1.8")) # may need to be a fully specified path

# may need to be a fully specified path
Sys.setenv(DATABASECONNECTOR_JAR_FOLDER=paste0(R_HADES_ENV_PATH, "/extras"))

# check ability to open CDM
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sql server",
  server = "vhacdwrb02" # ensure this is the researcher's DB server
  # full specification "vhacdwrb02.vha.med.va.gov" may be necessary
)
connect <- DatabaseConnector::connect(connectionDetails = connectionDetails)
DatabaseConnector::disconnect(connect)

databaseName <- "ORD_Researcher_xyz" # need to change for each ORD research space
cdmSchemaName <- "OMOPV5"
cdmDatabaseSchema <- paste(databaseName, cdmSchemaName, sep = ".")

# !!NOTE!! Run the first time you run this file. 
#    Used to create OMOP CDM schema in ORD space -- only needs to be executed once!
# VaTools::createStandardCdmSchema(
#   connectionDetails = connectionDetails,
#   database = databaseName,
#   startingSchema = "src",
#   destinationSchema = cdmSchemaName)

# small silly test
connect <- DatabaseConnector::connect(connectionDetails = connectionDetails)
sql <- SqlRender::render(
  "SELECT COUNT(*) AS subjects FROM @cdmDatabaseSchema.person;",
  cdmDatabaseSchema = cdmDatabaseSchema)
DatabaseConnector::querySql(connection = connection,
         sql = sql)
DatabaseConnector::disconnect(connection)
