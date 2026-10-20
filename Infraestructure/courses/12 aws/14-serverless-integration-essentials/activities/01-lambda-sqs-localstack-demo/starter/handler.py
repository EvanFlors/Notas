"""Lambda handler for the aws-14 demo.

Deliberately dependency-free: no boto3, no aws-lambda-powertools. The point is
to show the shape of a reasonable handler (idempotent-friendly, structured
logging, correlation id, explicit event validation) with nothing to install.

Invoked by the SQS event source mapping in LocalStack. The incoming event
follows the standard AWS SQS Lambda event shape (Records[]).
"""

from __future__ import annotations

import json
import logging
import os
import uuid

LOG = logging.getLogger()
LOG.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

SERVICE = os.environ.get("SERVICE_NAME", "orders-worker")
ENV = os.environ.get("ENVIRONMENT", "local")


class InvalidEvent(ValueError):
    """Raised when the incoming SQS event does not match the expected shape."""


def _validate(event):
    if not isinstance(event, dict):
        raise InvalidEvent("event is not a dict")
    records = event.get("Records")
    if not records:
        raise InvalidEvent("event missing Records")
    orders = []
    for rec in records:
        body = rec.get("body")
        if body is None:
            raise InvalidEvent("record missing body")
        try:
            payload = json.loads(body)
        except json.JSONDecodeError as exc:
            raise InvalidEvent(f"body is not valid JSON: {exc}") from exc
        if "order_id" not in payload:
            raise InvalidEvent("payload missing order_id")
        orders.append(payload)
    return orders


def _process_one(order, request_id):
    """Pretend to process the order. Idempotent by order_id in a real system."""
    return {
        "order_id": order["order_id"],
        "amount": order.get("amount"),
        "status": "processed",
        "request_id": request_id,
    }


def lambda_handler(event, context):
    request_id = getattr(context, "aws_request_id", None) or str(uuid.uuid4())
    LOG.info(json.dumps({
        "msg": "handler.invoked",
        "service": SERVICE,
        "env": ENV,
        "request_id": request_id,
    }))

    try:
        orders = _validate(event)
    except InvalidEvent as exc:
        LOG.error(json.dumps({
            "msg": "handler.invalid_event",
            "request_id": request_id,
            "error": str(exc),
        }))
        raise

    processed = [_process_one(o, request_id) for o in orders]

    LOG.info(json.dumps({
        "msg": "handler.done",
        "request_id": request_id,
        "count": len(processed),
    }))
    return {"processed": len(processed), "request_id": request_id}
