VERSION = 0.0.2
IMAGE_NAME ?= aarongorka/gocd-metrics:$(VERSION)
TAG = $(VERSION)

build:
	docker build -t $(IMAGE_NAME) .

shell: .env
	docker run --rm -it --env-file=.env -v ~/.aws:/root/.aws:Z $(IMAGE_NAME) bash

.env:
	@echo "Create .env with .env.template"
	cp .env.template .env

gitTag:
	-git tag -d $(TAG)
	-git push origin :refs/tags/$(TAG)
	git tag $(TAG)
	git push origin $(TAG)
