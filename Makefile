.PHONY: fmt validate test simulate

fmt:
	terraform fmt -recursive

validate:
	./run_tests.sh --static-only

test:
	./run_tests.sh

simulate:
	./run_tests.sh --simulate
