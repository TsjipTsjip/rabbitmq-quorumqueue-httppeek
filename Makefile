PROJECT = rabbitmq_quorumqueue_httppeek
PROJECT_DESCRIPTION = RabbitMQ Quorum queue HTTP peek

define PROJECT_APP_EXTRA_KEYS
	{broker_version_requirements, []}
endef

DEPS = rabbit_common rabbit rabbitmq_management
TEST_DEPS = rabbitmq_ct_helpers rabbitmq_ct_client_helpers

DEP_EARLY_PLUGINS = rabbit_common/mk/rabbitmq-early-plugin.mk
DEP_PLUGINS = rabbit_common/mk/rabbitmq-plugin.mk

include ../../rabbitmq-components.mk
include ../../erlang.mk
