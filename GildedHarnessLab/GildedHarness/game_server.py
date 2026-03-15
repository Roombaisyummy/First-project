import base64
import binascii
import hashlib
import logging
from flask import Flask, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# LIVE LOGIC CONFIGURATION
# Change these values and the app updates instantly.
game_config = {
    "buttonText": "Buy 100 Gems ($99.99)",
    "productID": "com.natha.gems.100",
    "gemReward": 100,
    "alertMessage": "✅ Server Verified Tweak Receipt!",
}

EXPECTED_BUNDLE_ID = "com.natha.gilded"
KNOWN_FAKE_RECEIPTS = {
    "SATELLA_MODERN_V1_FALLBACK",
    "SATELLA",
}

db = {
    "gems": 0,
    "accepted": 0,
    "rejected": 0,
    "last_reason": "none",
}
seen_receipts = set()


def reject(reason: str, status: int = 400):
    db["rejected"] += 1
    db["last_reason"] = reason
    app.logger.warning("receipt rejected: %s", reason)
    return jsonify({"status": "error", "reason": reason, "balance": db["gems"]}), status


def decode_receipt(receipt: str):
    try:
        # Apple receipts are base64 strings representing ASN.1 payloads.
        return base64.b64decode(receipt, validate=True)
    except (binascii.Error, ValueError):
        return None


def validate_receipt(product_id: str, receipt: str):
    if not product_id or product_id != game_config["productID"]:
        return "unexpected product id", None

    if not receipt:
        return "missing receipt", None

    if receipt in KNOWN_FAKE_RECEIPTS:
        return "known fallback receipt", None

    decoded = decode_receipt(receipt)
    if not decoded:
        return "receipt is not valid base64", None

    # Apple app receipts are DER/ASN.1 and generally begin with a SEQUENCE byte.
    if len(decoded) < 256 or decoded[0] != 0x30:
        return "receipt is not a plausible app receipt", None

    if EXPECTED_BUNDLE_ID.encode() not in decoded:
        return "bundle id missing from receipt", None

    if product_id.encode() not in decoded:
        return "product id missing from receipt", None

    digest = hashlib.sha256(decoded).hexdigest()
    if digest in seen_receipts:
        return "replayed receipt", None

    return None, digest


@app.route("/config", methods=["GET"])
def get_config():
    return jsonify(game_config)


@app.route("/verify_receipt", methods=["POST"])
def verify():
    data = request.get_json(silent=True) or {}
    product_id = data.get("product_id", "")
    receipt = data.get("receipt", "")

    reason, digest = validate_receipt(product_id, receipt)
    if reason:
        return reject(reason)

    seen_receipts.add(digest)
    db["gems"] += game_config["gemReward"]
    db["accepted"] += 1
    db["last_reason"] = "accepted"
    app.logger.info("receipt accepted: product=%s gems=%s", product_id, db["gems"])
    return jsonify({"status": "success", "balance": db["gems"]})


@app.route("/stats", methods=["GET"])
def stats():
    return jsonify(db)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
