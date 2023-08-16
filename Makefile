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
	gen/fio/$(1).json \
	# gen/dd/seq-read-$(1).log \
	# gen/dd/seq-write-$(1).log \
	# gen/dd/rand-read-$(1).log \
	# gen/dd/rand-write-$(1).log

.PHONY: test/$(1)/down
test/$(1)/down:
	@$$(call PRINT_INFO,$$@: Started)
	cases/$(1).sh down
	@$$(call PRINT_INFO,$$@: Done)

endef
$(eval $(foreach _,$(CASES),$(call TEST_CASE_RULES,$_)))

# Deprecated
gen/dd/seq-read-%.log:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p $(@D)
	cases/$*.sh exec tools/dd.sh seq-read > $@
	@$(call PRINT_INFO,$@: Done)

gen/fio/%.json:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p $(@D)
	cases/$*.sh exec sudo -E fio --output=$@ --output-format=json --eta=never tools/test.fio
	@$(call PRINT_INFO,$@: Done)

# Deprecated
gen/dd/seq-write-%.log:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p $(@D)
	cases/$*.sh exec tools/dd.sh seq-write > $@
	@$(call PRINT_INFO,$@: Done)

# Deprecated
gen/dd/rand-read-%.log:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p $(@D)
	cases/$*.sh exec tools/dd.sh rand-read > $@
	@$(call PRINT_INFO,$@: Done)

# Deprecated
gen/dd/rand-write-%.log:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p $(@D)
	cases/$*.sh exec tools/dd.sh rand-write > $@
	@$(call PRINT_INFO,$@: Done)

.PHONY: report
report: \
	report/fio \
	# report/dd

.PHONY: report/fio
report/fio:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p gen
	tools/fio2csv.sh gen/fio/*.json > gen/fio.csv
	tools/csv2tab.sh gen/fio.csv
	tools/fio2svg.r
	@$(call PRINT_INFO,$@: Done)

# Deprecated
.PHONY: report/dd
report/dd:
	@$(call PRINT_INFO,$@: Started)
	mkdir -p gen
	tools/dd2csv.sh gen/dd/*.log > gen/dd.csv
	tools/csv2tab.sh gen/dd.csv
	@$(call PRINT_INFO,$@: Done)

.PHONY: clean
clean:
	rm -rf gen
