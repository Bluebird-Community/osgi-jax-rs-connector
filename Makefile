.DEFAULT_GOAL := build

SHELL               := /bin/bash -o nounset -o pipefail -o errexit
ARTIFACTS_DIR       := target/artifacts
VERSION             := $(shell cd java && mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
BUILD_NUMBER        ?= 0
MAVEN_BIN           := $(shell command -v mvn)
MAVEN_ARGS          :=
JAVA_MAJOR_VERSION  := 1.8

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
	command -v java
	command -v javac
	command -v $(MAVEN_BIN)
	command -v zip
	mkdir -p $(ARTIFACTS_DIR)
	@echo Your Maven version
	@mvn --version
	@echo Your Java version
	@java -version

.PHONY: build
build: deps-build
	@echo "Build with Maven with tests"
	@$(MAVEN_BIN) $(MAVEN_ARGS) -DskipITs=false install
	zip -r ./osgi-jaxrs-connector.zip ~/.m2/repository/com/eclipsesource
	mkdir -p $(ARTIFACTS_DIR)/{surefire-reports,failsafe-reports}
	find . -type f -regex ".*\/target\/failsafe-reports\/.*\.xml" -exec cp {} $(ARTIFACTS_DIR)/failsafe-reports/ \;
	find . -type f -regex ".*\/target\/surefire-reports\/.*\.xml" -exec cp {} $(ARTIFACTS_DIR)/surefire-reports/ \;
	find . -type f -regex "\.\/target\/lib\/.*\.jar" -exec cp {} $(ARTIFACTS_DIR)/ \;

.PHONY: clean
clean:
	@$(MAVEN_BIN) $(MAVEN_ARGS) clean
