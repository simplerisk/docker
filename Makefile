# Colors
LOW := \033[0;32m
HIGH := \033[0;31m
NC := \033[0m

# Makefile options and tools, which will be added to .PHONY
MAKEFILE_DEFAULT_OPTIONS = all clean test help check_dependencies
MAKEFILE_EXTRA_OPTIONS = update_version generate_makefile
TOOLS = docker-compose dockle gorin grype lmaop

define HELP_MESSAGE
$(LOW)Usage:$(NC)
	$(LOW)make update_version$(NC)             Updates the version of Dockerfiles, stacks and others
	$(LOW)make generate_makefile$(NC)          Generates the makefile for this project (using gorin)


endef

check_dependencies:
	@missing=(); \
	for cmd in $(TOOLS); do \
		if ! command -v $$cmd &> /dev/null; then \
			missing+=($$cmd); \
		fi; \
	done; \
	if [ $${#missing[@]} -gt 0 ]; then \
		echo "$(HIGH)ERROR: The following required tools are missing: $${missing[@]}.$(NC)"; \
		exit 1; \
	fi

.DEFAULT_GOAL := help

.PHONY: $(MAKEFILE_DEFAULT_OPTIONS) $(MAKEFILE_EXTRA_OPTIONS) $(TOOLS)

export HELP_MESSAGE
help:
	@echo -e "$$HELP_MESSAGE"

update_version: 
	./update_workflows.sh $(VERSION)
	./simplerisk/generate_dockerfile.sh $(VERSION)
	./simplerisk-minimal/update_stack_and_workflows.sh $(VERSION)
	./simplerisk-minimal/generate_dockerfile.sh $(VERSION)

generate_makefile: check_dependencies
	@gorin makefile > Makefile


