
TF=TF_CLI_CONFIG_FILE=dev.tfrc terraform

clean-state:
	@rm -f terraform.tfstate*

init:
	${TF} init
apply:
	${TF} apply -auto-approve
plan:
	${TF} plan
destroy:
	${TF} destroy -auto-approve
refresh:
	${TF} refresh
state-show:
	${TF} state show aws_route53_record.test
