addEventListener("fetch", function(e) {
  e.respondWith(handleRequest(e.request));
});

function handleRequest(request) {
  var url = new URL(request.url);
  var path = url.pathname;
  var headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*"
  };

  if (path === "/" || path === "/v1") {
    return new Response(JSON.stringify({
      "name": "Moltline Blacklist API",
      "version": "1.0.0",
      "endpoints": {
        "stats": "/v1/stats",
        "cases": "/v1/cases",
        "blacklist": "/v1/blacklist"
      }
    }), {"headers": headers});
  }

  if (path === "/v1/stats") {
    return new Response(JSON.stringify({
      "blacklistedAddresses": 47,
      "blacklistedDomains": 12,
      "activeCases": 6,
      "status": "operational"
    }), {"headers": headers});
  }

  if (path === "/v1/cases") {
    return new Response(JSON.stringify({
      "cases": [
        {"id": "CASE-001", "title": "The Satoshi Identity", "status": "ACTIVE", "priority": "HIGH"},
        {"id": "CASE-002", "title": "The DAO Resurrection", "status": "ACTIVE", "priority": "MEDIUM"},
        {"id": "CASE-003", "title": "The Mixer Maze", "status": "ACTIVE", "priority": "HIGH"},
        {"id": "CASE-004", "title": "The Bridge Burners", "status": "ACTIVE", "priority": "CRITICAL"},
        {"id": "CASE-005", "title": "The NFT Phantom", "status": "ACTIVE", "priority": "MEDIUM"},
        {"id": "CASE-006", "title": "The Governance Ghosts", "status": "ACTIVE", "priority": "LOW"}
      ]
    }), {"headers": headers});
  }

  if (path === "/v1/blacklist") {
    return new Response(JSON.stringify({
      "addresses": [
        {"address": "0x1234567890abcdef1234567890abcdef12345678", "risk": "CRITICAL", "tags": ["scam", "rug-pull"]},
        {"address": "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef", "risk": "HIGH", "tags": ["mixer"]}
      ],
      "domains": [
        {"domain": "fake-uniswap.com", "risk": "CRITICAL", "category": "phishing"},
        {"domain": "free-eth-giveaway.xyz", "risk": "CRITICAL", "category": "scam"}
      ]
    }), {"headers": headers});
  }

  return new Response(JSON.stringify({"error": "Not found"}), {"status": 404, "headers": headers});
}
