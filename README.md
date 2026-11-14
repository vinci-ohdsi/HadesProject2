# SOP for windows-based renv environments for HADES that work in VINCI Standard and Development workspaces 

## Overview

Building and maintaining functional renv environments with all of the OHDSI HADES packages is a fundamental requirement to support the use of these tools.   VINCI Standard and Development workspaces are airgapped and so the environments much be built elsewhere and then uploaded into file stores accessible from the workspaces. The github actions provided in this repo enable full windows-based builds using only github actions within the managed VA github.  

- Supported use cases:
  - build for a new R version
  - update one or more libraries to be loaded into the renv for a specific R version
  - update duckdb major/minor version
  - update/add new java version, postgres or sqlserver driver, synthetic datasets, or vignettes to the extras/ subfolder
  - update R files that provide examples of HADES features in the "scaffold"

## Quick start if just updating or adding an R packages or editing something in the scaffold

If you are already familiar with how this works and just updating one or more R packages:

###  updating or adding an R packages
1. In the target branch, edit renv/package-requests.dcf with the update or new R package
2. run the github action, specifying the appropriate previously-built scaffold release artifact.
3. Upload the revised environment to the airgapped target location, unpack, and test.

### editing something in the scaffold

1. On the `main` branch, edit the file(s)

>[!NOTE]
> adding a new file or folder requires editing `.github/workflows/build_scaffold_release.yaml`

2. Commit the changes to a temporary new branch and then go through a pull request to the main (triggers CodeQL checks that protect the main branch)
3. Run the build_scaffold_release target with the SHA of the commit that was pulled into main.
4. See [Air-gapped use](#air-gapped-use) below for what to do next.

## R X.Y.Z initial provisioning

1. Create an `ingest_RvX.Y` branch with `renv/activate.R`, `.Rprofile`, a comment-template `renv/package-requests.dcf`, and a reviewed `renv.lock` whose `R.Version` is `X.Y.Z` (e.g., 4.4.3 or 4.5.2 etc.). See examples in the ingest_Rv4.4 and ingest_Rv4.5 branches to get started.
2. Build and publish the R X.Y specific DuckDB asset before dispatching the R X.Y wrapper. Its DBI version must match the R X.Y lockfile.
3. Create or select a validated "scaffold" release from the intended `main` commit. A "scaffold" is a set of files from the main branch that include a java version, postgres and sqlserver drivers, synthetic datasets, and vignettes (found in the `extras/` subfolder) and examples of HADES features in the "scaffold" (found top-level). There is a specific github action in this repo for creating a new scaffold release or you can use a prior one. Either way, the tag name (e.g., "project-scaffold-a5e8ac6a30dde75c6e2ce74363fc8e0d78b5cd0b") is input into build ingest action in the next step.
4. Copy one of the scaffolding files (e.g., workflows/build_ingest_Rv4_5_scaffolded.yaml) to a new yaml file in the same `.github/workflows` location naming it appropriately for the new version. Edit that file to update the following variables:

```
      target_branch:    # the branch where the relevant renv.lock file and renv/package-requests.dcf resides
      r_version:  # e.g., "4.5.2" - must match the renv.lock file of the target_branch
      r_minor_version:  # e.g., "4.5"       
      duckdb_version: # e.g., "1.5.5"
      duckdb_dbi_version: # e.g., "1.3.0"
      duckdb_release_tag: # from step (2) above e.g., duckdb-windows-r4.5-duckdb-1.5.5
      duckdb_asset: # from step (2) above e.g., duckdb-windows-r4.5-x86_64-w64-mingw32-1.5.5.zip
```
     
6. Dispatch the R X.Y wrapper with that scaffold tag. It creates, independently verifies, commits, and packages the R X.Y library.

## Air-gapped use

Download the uploaded portable-project ZIP, not GitHub's automatically generated `Source code (zip)` asset. Verify its SHA-256 checksum. Extract to a short Windows path such as `C:\Hades` when Explorer or PowerShell path limits are a concern, then open `HadesProject.Rproj` using the matching 64-bit Windows R version.


## Environment identity

Each supported R minor version has an independent target branch, lockfile, committed library, DuckDB release asset, cache namespace, and portable release:

| R version | Target branch | Library path |
| --- | --- | --- |
| 4.4.1 | `ingest_Rv4.4` | `renv/library/windows/R-4.4/x86_64-w64-mingw32/` |
| 4.5.2 | `ingest_Rv4.5` | `renv/library/windows/R-4.5/x86_64-w64-mingw32/` |

Do not merge `main` into an environment branch during a build. The reusable workflow checks out only its configured target branch. `main` supplies only the separately released scaffold.

## Package updates

1. On the applicable target branch, add one or more DCF records to `renv/package-requests.dcf`.
2. Use only a CRAN package/version or a GitHub repository pinned to a release tag or commit SHA.
3. Run the matching R-version wrapper and select a previously validated `project-scaffold-<source-SHA>` release tag.
4. On success, the workflow validates a second clean library, promotes the committed environment, clears fulfilled requests back to the commented template, and publishes the portable bundle.

Examples:

```dcf
Package: reticulate
Source: CRAN
Spec: reticulate@1.46.0
Dependencies: true

Package: PatientLevelPrediction
Source: GitHub
Spec: OHDSI/PatientLevelPrediction@v6.6.0
Dependencies: true
```

For CRAN, use `package@version` without a `v` prefix. For GitHub, use the exact tag name; retain a `v` when the release tag includes it. Do not use floating GitHub refs such as `main`, `master`, or `HEAD`.

## DuckDB and DBI updates

Do not request `duckdb` or `DBI` in `package-requests.dcf`.

1. Select the intended DuckDB and DBI versions for the target R minor version.
2. Run `build_duckdb_R_user_spec_version.yaml` with the full R version, DuckDB version, and DBI version.
3. Confirm that it publishes the R-minor-specific DuckDB release asset.
4. Update the matching wrapper only when deliberately changing this pinned environment identity, then ensure the target lockfile records the same DBI and DuckDB versions.

## Exclusions and failures

A package either installs and is represented in both the lockfile and committed library, or it is intentionally excluded.

For an exclusion, remove the package from the target branch lockfile and library in a reviewed change, and record the package, source/ref, date, and reason in the change record. Never retain a failed or optional package in a release lockfile.

A failed build must not modify the target branch or portable release. The build-report artifact records the request and error; the package cache can be reused on a later retry.


