ABLAC_DIR := $(abspath ../ablac)
COMPILER := $(ABLAC_DIR)/build/ablac

.PHONY: check test

check:
	mkdir -p build
	$(COMPILER) build tests/protocol_test.ab -o build/protocol-test --fast --no-cache
	build/protocol-test

test: check
	ABLAC=$(COMPILER) ./tools/test-redis.sh
	ABLAC=$(COMPILER) ./tools/test-async.sh
