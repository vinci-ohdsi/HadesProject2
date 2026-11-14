R_HADES_ENV_PATH <- "" # Set this to the base folder of the R HADES environment using '/' for folder hierarchy

Sys.setenv(EUNOMIA_DATA_FOLDER=paste0(R_HADES_ENV_PATH, "/extras/EunomiaDatasets-main/datasets/GiBleed/"))

library(Eunomia)

## This only needed to be ran once to create the CDM version of the data
## It is kept here for provenance
#extractLoadData(
#  from = paste0(Sys.getenv("EUNOMIA_DATA_FOLDER"),"GiBleed_5.3.zip"),
#  to = paste0(Sys.getenv("EUNOMIA_DATA_FOLDER"),"GiBleed_5.3.sqlite"),
#  dbms = 'sqlite'
#  )

connectionDetails <- getEunomiaConnectionDetails()
connection <- DatabaseConnector::connect(connectionDetails)
DatabaseConnector::querySql(connection, "SELECT COUNT(*) FROM person;")

DatabaseConnector::getTableNames(connection, databaseSchema="main")
DatabaseConnector::disconnect(connection)

