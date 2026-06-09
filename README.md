# RabbitMQ Quorumqueue HTTP peek

A RabbitMQ management plugin extension that exposes a REST API endpoint for peeking into quorum queues, without consuming a message and requeueing it.

## Purpose

This plugin provides a REST API alternative to the `rabbitmq-queues peek` CLI command, and is specifically designed for monitoring tools. This plugin proves especially useful in the case of queues with the `x-single-active-consumer` property set, where one cannot consume messages from the queue for monitoring (even if requeued immediately) without disrupting the consumer application that's connected to the queue.

## API Endpoint

```
GET /api/queues/{vhost}/{queue}/peek/{position}
```

### Parameters

- `vhost`: The virtual host containing the queue (URL-encoded)
- `queue`: The name of the queue
- `position`: The position in the queue (must be a positive integer >= 1)

### Response

```json
{
  "result": "ok",
  "message": {
    "payload": "...",
    "properties": {...}
  }
}
```

If an error occurs, it will be reported likewise.

## Installation

**SPECIAL PREPARATION:** This repository should be cloned into an existing rabbitmq-server clone, which is checked out at the version you want to build against.

1. Build the plugin:
   ```bash
   cd deps/rabbitmq_peek_api
   make
   ```

2. Enable the plugin:
   ```bash
   rabbitmq-plugins enable rabbitmq_peek_api
   ```

## Usage Example

```bash
curl -u guest:guest \
  http://localhost:15672/api/queues/%2F/my_queue/peek/1
```

## Requirements

- RabbitMQ 4.3.1 (targeted and tested, other versions may work)
- Management plugin enabled
- Target queue must be a quorum queue, as the internal peek mechanism is only supported for quorum queues.

## Authentication & Authorization

The endpoint respects RabbitMQ's standard authentication and authorization mechanisms.
Users must have read access to the target queue's vhost.

## Testing

Workflow is to be correctly determined. This has not yet worked properly.

## Considerations

- The peek operation is read-only and does not consume messages
- Position-based peeking is O(n) in queue length for quorum queues
- Like `rabitmq-queues peek`, the position is 1 based.

# License

This project is licensed under the [Mozilla Public License 2.0](LICENSE).
