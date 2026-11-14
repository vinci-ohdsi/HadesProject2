# Python set up

PYTHON_ENV_PATH <- ""   # Set this to the base folder of the Python environment using '/' for folder hierarchy

Sys.setenv(RETICULATE_PYTHON=paste0(PYTHON_ENV_PATH, "/python.exe"))
Sys.setenv(RETICULATE_USE_MANAGED_VENV="no")

current_path <- Sys.getenv("PATH")
Sys.setenv(PATH=gsub("/","\\\\",paste(current_path, PYTHON_ENV_PATH, sep=';')))
Sys.setenv(PATH=gsub("/","\\\\",paste(current_path, paste0(PYTHON_ENV_PATH, "/Scripts"),sep=';')))
Sys.setenv(PATH=gsub("/","\\\\",paste(current_path, paste0(PYTHON_ENV_PATH, "/Library/bin"),sep=';')))


library(reticulate)

py_config()
py_eval("1+1")

np <- import("numpy", convert=TRUE)
pd <- import("pandas", convert=TRUE)
sp <- import("scipy", convert=TRUE)
skl <- import("sklearn", convert=TRUE)

library(PatientLevelPrediction)
data("simulationProfile")
plpData <-simulatePlpData(simulationProfile, n=1500, seed=42)
population <- createStudyPopulation(plpData, outcomeId=3, populationSettings = createStudyPopulationSettings())
data <- splitData(plpData, population, splitSettings=createDefaultSplitSetting())
data$Train$covariateData <- preprocessData(data$Train$covariateData, createPreprocessSettings())
path <- file.path(tempdir(), "plp")

modelSettings <- setRandomForest(seed=42)
model <- fitPlp(data$Train, modelSettings, analysisId = 1, analysisPath = path)
evaluatePlp(model$prediction)
