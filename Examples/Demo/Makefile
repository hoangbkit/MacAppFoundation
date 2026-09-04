PROJECT := MacAppFoundationDemo.xcodeproj
SPEC := project.yml

.PHONY: generate open clean

generate:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen is required. Install with: brew install xcodegen"; \
		exit 1; \
	}
	xcodegen generate --spec $(SPEC)

open: generate
	open $(PROJECT)

clean:
	rm -rf $(PROJECT)
