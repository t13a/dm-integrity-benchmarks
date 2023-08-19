.DELETE_ON_ERROR:

PRINT_INFO = echo '\033[1;32m'$(1)'\033[0m' >&2

CASES := $(patsubst cases/%.sh,%,$(wildcard cases/*.sh))
export CASE_MNT := mnt

export DISK1_DEV ?= /dev/null
export DISK2_DEV ?= /dev/null

.PHONY: test
test: $(patsubst %,test/%,$(CASES))

define TEST_CASE_RULES
.PHONY: test/$(1)
test/$(1): \
	test/$(1)/up \
	test/$(1)/exec \
	test/$(1)/down

.PHONY: test/$(1)/up
test/$(1)/up:
	@$$(call PRINT_INFO,$$@: Started)
	cases/$(1).sh up
	@$$(call PRINT_INFO,$$@: Done)

.PHONY: test/$(1)/exec
test/$(1)/exec: \
	gen/fio/$(1).json

.PHONY: test/$(1)/down
test/$(1)/down:
	@$$(call PRINT_INFO,$$@: Started)
	cases/$(1).sh down
	@$$(call PRINT_INFO,$$@: Done)

endef
$(eval $(foreach _,$(CASES),$(call TEST_CASE_RULES,$_)))

gen/fio/%.json:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p $(@D)
	cases/$*.sh exec sudo -E fio --output=$@ --output-format=json --eta=never tools/test.fio
	@$(call PRINT_INFO,$@: Done)

.PHONY: report
report: \
	report/fio

.PHONY: report/fio
report/fio:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p gen
	tools/fio2csv.sh gen/fio/*.json > gen/fio.csv
	tools/csv2tab.sh gen/fio.csv
	tools/fio2svg.r
	@$(call PRINT_INFO,$@: Done)

.PHONY: clean
clean:
	rm -rf gen
