.DEFAULT_GOAL := build

SHELL               := /bin/bash -o nounset -o pipefail -o errexit
MAVEN_SETTINGS_XML  ?= ./.cicd-assets/settings.xml
ARTIFACTS_DIR       := target/artifacts
VERSION             := $(shell cd java && mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
BUILD_NUMBER        ?= 0
MAVEN_BIN           := $(shell command -v mvn)
MAVEN_ARGS          := --settings $(MAVEN_SETTINGS_XML)

.PHONY: help
help:
	@echo ""
	@echo "This project connects Jersey and OSGi at the service level."
	@echo "This means that OSGi services can be published as RESTful web services by simply registering them as OSGi services."
	@echo "A neat side feature is that REST services can also be consumed as OSGi services ;)."
	@echo "Artifacts are generated in the dist directory."
	@echo ""
	@echo "Goals:"
	@echo "  help:     Show this help for build goals"
	@echo "  build:    Verify dependencies and build from source"
	@echo "  clean:    Delete all build artifacts"
	@echo ""

.PHONY: deps-build
deps-build:
	@echo "Check build dependencies: Java JDK and, Maven"
	command -v $(MAVEN_BIN)
	command -v java
	command -v javac
	mkdir -p $(ARTIFACTS_DIR)
	@echo "Check Java version 11"
	@java -version 2>&1 | grep -e "\"11\..*\""

.PHONY: build
build: deps-build
	@echo "Build with Maven with tests"
	@$(MAVEN_BIN) $(MAVEN_ARGS) -DskipITs=false install
	mkdir -p $(ARTIFACTS_DIR)/{surefire-reports,failsafe-reports}
	find . -type f -regex ".*\/target\/failsafe-reports\/.*\.xml" -exec cp {} $(ARTIFACTS_DIR)/failsafe-reports/ \;
	find . -type f -regex ".*\/target\/surefire-reports\/.*\.xml" -exec cp {} $(ARTIFACTS_DIR)/surefire-reports/ \;
	find . -type f -regex "\.\/target\/lib\/.*\.jar" -exec cp {} $(ARTIFACTS_DIR)/ \;

.PHONY: clean
clean:
	@$(MAVEN_BIN) $(MAVEN_ARGS) clean
