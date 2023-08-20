.DELETE_ON_ERROR:

PRINT_INFO = echo '\033[1;32m'$(1)'\033[0m' >&2
UPPERCASE = $(shell echo $(1) | tr '[:lower:]' '[:upper:]')

TEST_DRIVES = hdd ssd ram
TEST_CONFIGS := $(patsubst configs/%.sh,%,$(wildcard configs/*.sh))
export TEST_MNT := mnt

.PHONY: test
test: $(patsubst %,test/%,$(TEST_DRIVES))

.PHONY: report
report: \
	out/all.csv \
	out/all.svg \
	$(patsubst %,report/%,$(TEST_DRIVES))

define TEST_DRIVE_RULES
.PHONY: test/$(1)
test/$(1): $(patsubst %,test/$(1)/%,$(TEST_CONFIGS))

.PHONY: report/$(1)
report/$(1): \
	out/drive.$(1).csv \
	out/drive.$(1).svg

endef
$(eval $(foreach _,$(TEST_DRIVES),$(call TEST_DRIVE_RULES,$_)))

define TEST_CONFIG_RULES
.PHONY: test/$(1)/$(2)
test/$(1)/$(2): \
	test/$(1)/$(2)/up \
	test/$(1)/$(2)/exec \
	test/$(1)/$(2)/down

.PHONY: test/$(1)/$(2)/up
test/$(1)/$(2)/up: export DISK1_DEV=$$($(call UPPERCASE,$(1))1_DEV)
test/$(1)/$(2)/up: export DISK2_DEV=$$($(call UPPERCASE,$(1))2_DEV)
test/$(1)/$(2)/up:
	@$$(call PRINT_INFO,$$@: Started)
	configs/$(2).sh up
	@$$(call PRINT_INFO,$$@: Done)

.PHONY: test/$(1)/$(2)/exec
test/$(1)/$(2)/exec: export DISK1_DEV=$$($(call UPPERCASE,$(1))1_DEV)
test/$(1)/$(2)/exec: export DISK2_DEV=$$($(call UPPERCASE,$(1))2_DEV)
test/$(1)/$(2)/exec:
	@$$(call PRINT_INFO,$$@: Started)
	mkdir -p out/$(1)
	configs/$(2).sh exec sudo -E fio --output=out/$(1)/$(2).json --output-format=json --eta=never tools/test.fio
	@$$(call PRINT_INFO,$$@: Done)

.PHONY: test/$(1)/$(2)/down
test/$(1)/$(2)/down: export DISK1_DEV=$$($(call UPPERCASE,$(1))1_DEV)
test/$(1)/$(2)/down: export DISK2_DEV=$$($(call UPPERCASE,$(1))2_DEV)
test/$(1)/$(2)/down:
	@$$(call PRINT_INFO,$$@: Started)
	configs/$(2).sh down
	@$$(call PRINT_INFO,$$@: Done)

endef
$(eval $(foreach TEST_DRIVE,$(TEST_DRIVES),$(foreach TEST_CONFIG,$(TEST_CONFIGS),$(call TEST_CONFIG_RULES,$(TEST_DRIVE),$(TEST_CONFIG)))))


out/all.svg: out/all.csv
	tools/csv2svg.R $< $@ '.' '.' '.'

out/all.csv:
	tools/json2csv.sh out/*/*.json > $@

out/drive.%.svg: out/drive.%.csv
	tools/csv2svg.drive.R $< $@ '.' '.'

out/drive.%.csv:
	tools/json2csv.sh out/$*/*.json > $@

.PHONY: clean
clean:
	rm -rf out
