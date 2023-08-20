.DELETE_ON_ERROR:

PRINT_INFO = echo '\033[1;32m'$(1)'\033[0m' >&2
UPPERCASE = $(shell echo $(1) | tr '[:lower:]' '[:upper:]')

CASES := $(patsubst cases/%.sh,%,$(wildcard cases/*.sh))
export CASE_MNT := mnt

DRIVES = hdd ssd ram
HDD1_DEV ?= /dev/null
HDD2_DEV ?= /dev/null
SSD1_DEV ?= /dev/null
SSD2_DEV ?= /dev/null
RAM1_DEV ?= /dev/null
RAM2_DEV ?= /dev/null

.PHONY: test
test: $(patsubst %,test/%,$(DRIVES))

.PHONY: report
report: report/all $(patsubst %,report/%,$(DRIVES))

.PHONY: report/all
report/all: \
	gen/all.csv \
	gen/all.svg

define TEST_DRIVE_RULES
.PHONY: test/$(1)
test/$(1): $(patsubst %,test/$(1)/%,$(CASES))

.PHONY: report/$(1)
report/$(1): \
	gen/drive.$(1).csv \
	gen/drive.$(1).svg

endef
$(eval $(foreach _,$(DRIVES),$(call TEST_DRIVE_RULES,$_)))

define TEST_CASE_RULES
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
	cases/$(2).sh up
	@$$(call PRINT_INFO,$$@: Done)

.PHONY: test/$(1)/$(2)/exec
test/$(1)/$(2)/exec: export DISK1_DEV=$$($(call UPPERCASE,$(1))1_DEV)
test/$(1)/$(2)/exec: export DISK2_DEV=$$($(call UPPERCASE,$(1))2_DEV)
test/$(1)/$(2)/exec:
	@$$(call PRINT_INFO,$$@: Started)
	mkdir -p gen/$(1)
	cases/$(2).sh exec sudo -E fio --output=gen/$(1)/$(2).json --output-format=json --eta=never tools/test.fio
	@$$(call PRINT_INFO,$$@: Done)

.PHONY: test/$(1)/$(2)/down
test/$(1)/$(2)/down: export DISK1_DEV=$$($(call UPPERCASE,$(1))1_DEV)
test/$(1)/$(2)/down: export DISK2_DEV=$$($(call UPPERCASE,$(1))2_DEV)
test/$(1)/$(2)/down:
	@$$(call PRINT_INFO,$$@: Started)
	cases/$(2).sh down
	@$$(call PRINT_INFO,$$@: Done)

endef
$(eval $(foreach DRIVE,$(DRIVES),$(foreach CASE,$(CASES),$(call TEST_CASE_RULES,$(DRIVE),$(CASE)))))

gen/all.svg: gen/all.csv
	tools/csv2svg.R $< $@ 12 '.' '.' '.'

gen/all.csv:
	tools/json2csv.sh gen/*/*.json > $@

gen/drive.%.svg: gen/drive.%.csv
	tools/csv2svg.drive.R $< $@ 8 '.' '.'

gen/drive.%.csv:
	tools/json2csv.sh gen/$*/*.json > $@

.PHONY: clean
clean:
	rm -rf gen
