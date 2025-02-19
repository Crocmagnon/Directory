.PHONY: all release test build pack image run check lint coverage clean help

NAME = directory
IMAGE = privatebin/$(NAME)
PORT = 8000
BUILD_IMAGE = ekidd/rust-musl-builder:nightly-2020-03-12-sqlite
DATABASE = var/directory.sqlite
ROCKET_DATABASES = "{directory={url=\"$(DATABASE)\"}}"
GEOIP_MMDB = var/geoip-country.mmdb

all: test build image run check clean ## Equivalent to "make test build image run check clean" (default).

release: test build pack license image run check clean ## Equivalent to "make test build pack image run check clean".

test: .cargo/registry $(DATABASE) ## Build and run the unit tests.
	git checkout $(DATABASE)
	docker run --rm -t --init \
		-e GEOIP_MMDB="$(GEOIP_MMDB)" \
		-e ROCKET_DATABASES=$(ROCKET_DATABASES) \
		-v "$(CURDIR)":/home/rust/src \
		-v "$(CURDIR)"/.cargo/registry:/home/rust/.cargo/registry \
		$(BUILD_IMAGE) \
		cargo test --release # -- --nocapture
	git checkout $(DATABASE)

build: .cargo/registry ## Build the binary for release.
	git checkout $(DATABASE)
	docker run --rm -t --init \
		-v "$(CURDIR)":/home/rust/src \
		-v "$(CURDIR)"/.cargo/registry:/home/rust/.cargo/registry \
		$(BUILD_IMAGE) \
		cargo build --release

pack: ## Strips and compresses the binary to reduce it's size, only intended for the release.
	strip target/x86_64-unknown-linux-musl/release/directory
	upx --ultra-brute target/x86_64-unknown-linux-musl/release/directory

license: ## Generates the LICENSE.md file
	docker run --rm -t --init \
		-v "$(CURDIR)":/home/rust/src \
		-v "$(CURDIR)"/.cargo/registry:/home/rust/.cargo/registry \
		$(BUILD_IMAGE) \
		sh -c "cargo install cargo-about && cargo about init && cargo about generate about.hbs > /home/rust/src/LICENSE.md"

image: ## Build the container image.
	docker build --build-arg PORT=$(PORT) \
		--build-arg GEOIP_MMDB="/$(GEOIP_MMDB)" \
		--build-arg ROCKET_DATABASES='{directory={url="/'$(DATABASE)'"}}' \
		-t $(IMAGE) .

run: ## Run a container from the image.
	docker run -d --init --name $(NAME) -p=$(PORT):$(PORT) \
		--read-only -v "$(CURDIR)/var":/var --restart=always $(IMAGE)

check: ## Launch tests to verify that the service works as expected, requires a running container.
	@sleep 1
	nc -z localhost $(PORT)
	curl -s http://localhost:$(PORT)/ | grep "Welcome!"
	curl -s http://localhost:$(PORT)/about | grep "About"
	curl -s http://localhost:$(PORT)/add | grep "Add instance"
	docker exec -t -e CRON=POLL directory directory | grep "cleaned up checks stored before"
	@echo "Checks: \033[92mOK\033[0m"

.cargo/registry:
	mkdir -p .cargo/registry

lint: ## Run fmt & clippy on the code to come up with improvements.
	cargo fmt
	cargo clippy
	git checkout $(DATABASE)

coverage: ## Run tarpaulin on the code to report on the tests code coverage.
	git checkout $(DATABASE)
	GEOIP_MMDB="$(GEOIP_MMDB)" \
	ROCKET_DATABASES=$(ROCKET_DATABASES) \
	cargo tarpaulin --release -o Html
	git checkout $(DATABASE)

clean: $(DATABASE) ## Stops and removes the running container.
	git checkout $(DATABASE)
	docker ps -q --filter "name=$(NAME)" | grep -q . && \
	docker stop $(NAME) && \
	docker rm $(NAME) || true

help: ## Displays these usage instructions.
	@echo "Usage: make <target(s)>"
	@echo
	@echo "Specify one or multiple of the following targets and they will be processed in the given order:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "%-16s%s\n", $$1, $$2}' $(MAKEFILE_LIST)
