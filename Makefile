.PHONY: clean all run1 run2

all: run1 run2

run1:
	lua test.lua
	@echo "test.lua passed"
run2:
	lua test2.lua
	@echo "test2.lua passed"
clean:
	test2.xml
