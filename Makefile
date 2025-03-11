.DEFAULT_GOAL := jar

SHELL               := /bin/bash -o nounset -o pipefail -o errexit
ARTIFACTS_DIR       := target/artifacts
VERSION             ?= $(shell mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
GIT_BRANCH          := $(shell git branch --show-current)
BUILD_NUMBER        ?= 0
MAVEN_BIN           := $(shell command -v mvn)
MAVEN_ARGS          := --settings .cicd-assets/settings.xml
RELEASE_VERSION     := UNSET.0.0
RELEASE_BRANCH      := release/1.x
PUSH_RELEASE        := false
MAJOR_VERSION       := $(shell echo $(RELEASE_VERSION) | cut -d. -f1)
MINOR_VERSION       := $(shell echo $(RELEASE_VERSION) | cut -d. -f2)
PATCH_VERSION       := $(shell echo $(RELEASE_VERSION) | cut -d. -f3)
SNAPSHOT_VERSION    := $(MAJOR_VERSION).$(MINOR_VERSION).$(shell expr $(PATCH_VERSION) + 1)-SNAPSHOT
MAVEN_REPO          := bluebird-snapshots
MAVEN_USERNAME      := ""
MAVEN_PASSWORD      := ""
RELEASE_LOG         := target/release.log
OK                  := "[ 👍 ]"
SKIP                := "[ ⏭️ ]"
JAVA_MAJOR_VERSION  := 1.8

.PHONY: help
help:
	env
	@echo ""
	@echo "This project connects Jersey and OSGi at the service level."
	@echo "This means that OSGi services can be published as RESTful web services by simply registering them as OSGi services."
	@echo "A neat side feature is that REST services can also be consumed as OSGi services ;)."
	@echo "Artifacts are generated in the dist directory."
	@echo ""
	@echo "Goals:"
	@echo "  help:     Show this help for build goals"
	@echo "  jar:      Verify dependencies and build from source"
	@echo "  clean:    Delete all build artifacts"
	@echo ""

.PHONY: deps-build
deps-build:
	@echo "Check build dependencies: Java JDK and, Maven"
	command -v java
	command -v javac
	command -v $(MAVEN_BIN)
	mkdir -p $(ARTIFACTS_DIR)
	@echo Your Maven version
	@mvn --version
	@echo Check Java version $(JAVA_MAJOR_VERSION)
	@java -version 2>&1 | grep '$(JAVA_MAJOR_VERSION)\..*' >/dev/null

.PHONY: jar
jar: deps-build
	@echo "Build with Maven with tests"
	@$(MAVEN_BIN) $(MAVEN_ARGS) -DskipITs=false install
	mkdir -p $(ARTIFACTS_DIR)/{surefire-reports,failsafe-reports}
	find . -type f -regex ".*\/target\/failsafe-reports\/.*\.xml" -exec cp {} $(ARTIFACTS_DIR)/failsafe-reports/ \;
	find . -type f -regex ".*\/target\/surefire-reports\/.*\.xml" -exec cp {} $(ARTIFACTS_DIR)/surefire-reports/ \;
	find . -type f -regex "\.\/target\/lib\/.*\.jar" -exec cp {} $(ARTIFACTS_DIR)/ \;

.PHONY: release
release:
	@mkdir -p target
	@echo ""
	@echo "Release version:          $(RELEASE_VERSION)"
	@echo "New snapshot version:     $(SNAPSHOT_VERSION)"
	@echo "Git version tag:          v$(RELEASE_VERSION)"
	@echo "Release log:              $(RELEASE_LOG)"
	@echo "Current branch:           $(GIT_BRANCH)"
	@echo "Release branch:           $(RELEASE_BRANCH)"
	@echo ""
	@echo -n "Check release branch:        "
	@if [ "$(GIT_BRANCH)" != "$(RELEASE_BRANCH)" ]; then echo "Releases are made from the $(RELEASE_BRANCH) branch, your branch is $(GIT_BRANCH)."; exit 1; fi
	@echo "$(OK)"
	@echo -n "Check branch in sync         "
	@if [ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]; then echo "$(RELEASE_BRANCH) branch not in sync with remote origin."; exit 1; fi
	@echo "$(OK)"
	@echo -n "Check uncommited changes     "
	@if git status --porcelain | grep -q .; then echo "There are uncommited changes in your repository."; exit 1; fi
	@echo "$(OK)"
	@echo -n "Check release version:       "
	@if [ "$(RELEASE_VERSION)" = "UNSET" ]; then echo "Set a release version, e.g. make release RELEASE_VERSION=1.0.0"; exit 1; fi
	@echo "$(OK)"
	@echo -n "Check version tag available: "
	@if git rev-parse v$(RELEASE_VERSION) >$(RELEASE_LOG) 2>&1; then echo "Tag v$(RELEASE_VERSION) already exists"; exit 1; fi
	@echo "$(OK)"
	@echo -n "Set Maven release version:   "
	@mvn versions:set -DnewVersion=$(RELEASE_VERSION) >>$(RELEASE_LOG) 2>&1
	@echo "$(OK)"
	@echo -n "Verify build with tests:     "
	@$(MAKE) jar >>$(RELEASE_LOG) 2>&1
	@echo "$(OK)"
	@echo -n "Git commit new release:      "
	@git commit --signoff -am "release: OSGi JAX RS Connector version $(RELEASE_VERSION)" >>$(RELEASE_LOG) 2>&1
	@echo "$(OK)"
	@echo -n "Set Git version tag:         "
	@git tag -a "v$(RELEASE_VERSION)" -m "Release OSGi JAX RS Connector version $(RELEASE_VERSION)" >>$(RELEASE_LOG) 2>&1
	@echo "$(OK)"
	@echo -n "Set Maven snapshot version:  "
	@mvn versions:set -DnewVersion=$(SNAPSHOT_VERSION) >>$(RELEASE_LOG) 2>&1
	@echo "$(OK)"
	@echo -n "Git commit snapshot release: "
	@git commit --signoff -am "release: Set new snapshot version $(SNAPSHOT_VERSION)" >>$(RELEASE_LOG) 2>&1
	@echo "$(OK)"
	@if [ "$(PUSH_RELEASE)" = "true" ]; then \
	    echo -n "Push commits                 "; \
  		git push >>$(RELEASE_LOG) 2>&1; \
		echo "$(OK)"; \
		echo -n "Push tag                     "; \
  		git push origin v$(RELEASE_VERSION) >>$(RELEASE_LOG) 2>&1; \
  		echo "$(OK)"; \
  	else \
  		echo "Push commits and tag:        $(SKIP)"; \
  	fi;

.PHONY: publish
publish:
	@$(MAVEN_BIN) $(MAVEN_ARGS) -Drepo.id=$(MAVEN_REPO) -Drepo.username=$(MAVEN_USERNAME) -Drepo.password=$(MAVEN_PASSWORD) -DskipTests deploy

.PHONY: clean
clean:
	@$(MAVEN_BIN) $(MAVEN_ARGS) clean
