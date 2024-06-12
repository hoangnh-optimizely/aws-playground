package rds

import (
	"github.com/hoangnh-optimizely/playground/internal/tofu"
)

// Ref: https://github.com/hashicorp/learn-terraform-rds
tofu.#Base & {
	for _, provider in ["aws", "random"] {
		terraform: required_providers: (provider): tofu.providers[provider]
	}

	provider: aws: region: "us-east-1"

	data: aws_availability_zones: avaiable: {}

	module: vpc: tofu.modules.vpc & {
		name: "iam-db-auth-test"
		cidr: "10.0.0.0/16"
		azs:  "${data.aws_availability_zones.avaiable.names}"
		public_subnets: ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
	}

	resource: {
		random_password: rds: {
			length:           24
			special:          true
			override_special: "!#$%&*()-_=+[]{}<>:?"
		}

		aws_security_group: rds: {
			name:   "iam-db-auth-test"
			vpc_id: "${module.vpc.vpc_id}"

			tags: {
				Name: "iam-db-auth-test"
			}
		}

		for _, type in ["ingress", "egress"] {
			"aws_vpc_security_group_\(type)_rule": rds: {
				security_group_id: "${aws_security_group.rds.id}"
				cidr_ipv4:         "0.0.0.0/0"
				from_port:         "${aws_db_instance.rds.port}"
				to_port:           "${aws_db_instance.rds.port}"
				ip_protocol:       "tcp"
			}
		}

		aws_db_subnet_group: rds: {
			name:       "iam-db-auth-test"
			subnet_ids: "${module.vpc.public_subnets}"

			tags: {
				Name: "iam-db-auth-test"
			}
		}

		aws_db_instance: rds: {
			identifier:           "iam-db-auth-test"
			instance_class:       "db.t3.micro"
			allocated_storage:    5
			engine:               "mariadb"
			engine_version:       "10.11"
			username:             "admin"
			password:             "${random_password.rds.result}"
			db_subnet_group_name: "${aws_db_subnet_group.rds.id}"
			parameter_group_name: "default.mariadb10.11"
			skip_final_snapshot:  true
			publicly_accessible:  true
			vpc_security_group_ids: ["${aws_security_group.rds.id}"]
		}
	}

	output: {
		db_password: {
			value:     "${random_password.rds.result}"
			sensitive: true
		}
		db_url: value:  "${aws_db_instance.rds.address}"
		db_port: value: "${aws_db_instance.rds.port}"
	}
}
