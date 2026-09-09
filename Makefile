install:
	bash scripts/codeartifact-login.sh && yarn install && bundle install

add:
	@bash scripts/add.sh $(filter-out $@,$(MAKECMDGOALS))

upgrade:
	bash scripts/codeartifact-login.sh && bundle update $(if $(CONSERVATIVE),--conservative) $(filter-out $@,$(MAKECMDGOALS))

%:
	@:
