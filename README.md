# RabbitMQ Queue Peek API

A RabbitMQ management plugin that exposes a REST API endpoint for peeking into quorum queues.

## Purpose

This plugin provides a lightweight REST API alternative to the `rabbitmq-queues peek` CLI command, allowing clients to inspect messages at specific positions in quorum queues without the overhead of starting an Erlang VM.

## API Endpoint

```
GET /api/queues/{vhost}/{queue}/peek/{position}
```

### Parameters

- `vhost`: The virtual host containing the queue (URL-encoded)
- `queue`: The name of the queue
- `position`: The position in the queue (must be a positive integer >= 1)

### Response

**Success (200):**
```json
{
  "result": "ok",
  "message": {
    "payload": "...",
    "properties": {...}
  }
}
```

**Errors (400/404/500):**
```json
{
  "result": "error",
  "message": "Error description"
}
```

### Error Cases

- `404 queue_not_found`: Target queue was not found in the virtual host
- `404 no_message_at_pos`: Queue does not have a message at that position
- `400 classic_queue_not_supported`: Queue is a classic queue (only quorum queues are supported)
- `400 invalid_position`: Position is not a valid positive integer

## Installation

1. Build the plugin:
   ```bash
   cd deps/rabbitmq_peek_api
   gmake
   ```

2. Enable the plugin:
   ```bash
   rabbitmq-plugins enable rabbitmq_peek_api
   ```

3. Restart RabbitMQ or enable the plugin via the management UI

## Usage Examples

### Peek at position 1 in a quorum queue

```bash
curl -u guest:guest \
  http://localhost:15672/api/queues/%2F/my_queue/peek/1
```

### Peek at position 5 with authentication

```bash
curl -u admin:password \
  http://localhost:15672/api/queues/my_vhost/my_queue/peek/5
```

## Requirements

- RabbitMQ 4.0.0 or later
- Management plugin enabled
- Target queue must be a quorum queue

## Supported Queues

This endpoint works with **quorum queues only**. Classic queues are not supported due to their design.
To convert a classic queue to a quorum queue, see the [RabbitMQ queue migration documentation](https://www.rabbitmq.com/docs/queues#migration).

## Authentication & Authorization

The endpoint respects RabbitMQ's standard authentication and authorization mechanisms.
Users must have read access to the target queue's vhost.

## Testing

### Running the Test Suite

The plugin includes a comprehensive Common Test suite covering:
- Successful peek operations
- Error cases (queue not found, invalid positions, classic queues)
- Authorization and authentication
- JSON response format validation

To run the test suite:

```bash
cd /path/to/rabbitmq-server
gmake ct-rabbitmq_peek_api
```

Or run a specific test:

```bash
gmake ct-rabbitmq_peek_api TESTCASE=peek_at_valid_position
```

### Test Coverage

The test suite includes:

**Basic Operations** (3 tests)
- Peek at a valid position
- Peek at position 1
- Peek at multiple positions

**Error Cases** (8 tests)
- Queue not found
- Invalid position format (non-integer)
- Invalid position (negative)
- Invalid position (zero)
- No message at position
- Classic queue rejection
- Virtual host not found
- Missing position parameter

**Authorization** (2 tests)
- Unauthorized user (403 Forbidden)
- Authorized user (200 OK)

**Response Format** (3 tests)
- JSON "result" field presence
- JSON "message" field presence
- Valid JSON structure

## Building from Source

### Prerequisites

- Erlang/OTP 26+ (or as required by your RabbitMQ version)
- GNU Make 4+
- Git

### Build Steps

1. Clone the RabbitMQ server repository:
   ```bash
   git clone https://github.com/rabbitmq/rabbitmq-server.git
   cd rabbitmq-server
   ```

2. The plugin is already in `deps/rabbitmq_peek_api/`

3. Build the entire RabbitMQ server (which includes this plugin):
   ```bash
   gmake all
   ```

4. The compiled plugin will be available at:
   ```
   plugins/rabbitmq_peek_api-*.ez
   ```

### Building Just the Plugin

To build only this plugin:

```bash
cd deps/rabbitmq_peek_api
gmake
```

Compiled artifacts will be in `_build/default/lib/rabbitmq_peek_api/`

## Troubleshooting

### Plugin Not Showing in Management UI

If the endpoint doesn't work after enabling the plugin:

1. Verify the plugin is enabled:
   ```bash
   rabbitmq-plugins list | grep rabbitmq_peek_api
   ```

2. Check RabbitMQ logs:
   ```bash
   tail -f /var/log/rabbitmq/rabbit@hostname.log
   ```

3. Restart RabbitMQ:
   ```bash
   rabbitmqctl stop
   rabbitmqctl start
   ```

### 404 Errors

- **Queue not found**: Verify the queue exists and the name is correct
- **Position parameter missing**: Ensure you include the position in the URL
- **Endpoint not found**: Ensure management plugin is enabled

### 400 Bad Request

- **Invalid position**: Position must be an integer >= 1
- **Classic queue**: Only quorum queues are supported

### 403 Forbidden

- User lacks permissions for the virtual host
- Ensure user has "configure", "read", "write" permissions

## API Response Details

### Success Response (200)

```json
{
  "result": "ok",
  "message": {
    "payload": "base64-encoded-message-or-string",
    "payload_encoding": "string",
    "properties": {
      "cluster_id": "",
      "priority": 0,
      "delivery_mode": 2,
      "correlation_id": "",
      "reply_to": "",
      "expiration": "",
      "message_id": "",
      "timestamp": 1234567890,
      "type": "",
      "user_id": "",
      "app_id": "",
      "content_encoding": "",
      "content_type": "text/plain",
      "headers": {}
    }
  }
}
```

### Error Response (4xx/5xx)

```json
{
  "result": "error",
  "message": "Descriptive error message"
}
```

## Performance Considerations

- The peek operation is read-only and does not consume messages
- No locks are held on the queue during the peek
- Safe to use for monitoring and inspection
- Position-based peeking is O(n) in queue length for quorum queues

## Limitations

- **Quorum queues only**: Classic queues are not supported
- **Single message**: Each request returns only one message
- **Position-based**: No filtering or searching capabilities
- **No streaming**: Each message must be fetched individually

## Known Issues

- None currently documented

## Contributing

To contribute improvements:

1. Fork the RabbitMQ server repository
2. Create a feature branch
3. Make your changes to `deps/rabbitmq_peek_api/`
4. Run tests: `gmake ct-rabbitmq_peek_api`
5. Submit a pull request

## Support

For issues or questions:

1. Check the [RabbitMQ documentation](https://www.rabbitmq.com/docs)
2. Review [RabbitMQ queues documentation](https://www.rabbitmq.com/docs/queues)
3. Search [GitHub issues](https://github.com/rabbitmq/rabbitmq-server/issues)
4. Ask on [RabbitMQ Community Forum](https://groups.google.com/forum/#!forum/rabbitmq-users)

## License

This project is licensed under the [Mozilla Public License 2.0](LICENSE).
