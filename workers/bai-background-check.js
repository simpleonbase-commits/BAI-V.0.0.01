/**
 * BAI Background Check API - Cloudflare Worker (BlockScout - FREE)
 */

export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const path = url.pathname;
        
        // CORS headers
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
        };
        
        if (request.method === 'OPTIONS') {
            return new Response(null, { headers: corsHeaders });
        }
        
        // Health check
        if (path === '/health' || path === '/') {
            return Response.json({
                status: 'healthy',
                service: 'BAI Background Check API',
                version: 'blockscout-1.0',
                chain: 'Base',
                dataSource: 'BlockScout (free)'
            }, { headers: corsHeaders });
        }
        
        // Background check endpoint
        if (path.startsWith('/check/')) {
            const address = path.replace('/check/', '');
            
            if (!address || !address.startsWith('0x') || address.length !== 42) {
                return Response.json({
                    success: false,
                    error: 'Invalid address format'
                }, { status: 400, headers: corsHeaders });
            }
            
            try {
                const result = await performBackgroundCheck(address);
                return Response.json(result, { headers: corsHeaders });
            } catch (error) {
                return Response.json({
                    success: false,
                    error: error.message
                }, { status: 500, headers: corsHeaders });
            }
        }
        
        return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
    }
};

async function performBackgroundCheck(address) {
    // Use BlockScout API (free, no API key needed)
    const apiUrl = `https://base.blockscout.com/api?module=account&action=txlist&address=${address}&page=1&offset=100&sort=desc`;
    
    const response = await fetch(apiUrl, {
        headers: {
            'Accept': 'application/json',
            'User-Agent': 'BAI-BackgroundCheck/1.0'
        }
    });
    
    const data = await response.json();
    const transactions = data.result || [];
    
    // Calculate metrics
    const now = Date.now();
    const ETH_PRICE_USD = 2500; // Approximate price
    
    let totalIn = 0;
    let totalOut = 0;
    let oldestTx = null;
    let newestTx = null;
    
    for (const tx of transactions) {
        const value = parseFloat(tx.value) / 1e18;
        const timestamp = parseInt(tx.timeStamp) * 1000;
        
        if (tx.to?.toLowerCase() === address.toLowerCase()) {
            totalIn += value;
        } else {
            totalOut += value;
        }
        
        if (!oldestTx || timestamp < oldestTx.timestamp) {
            oldestTx = { ...tx, timestamp };
        }
        if (!newestTx || timestamp > newestTx.timestamp) {
            newestTx = { ...tx, timestamp };
        }
    }
    
    // Calculate wallet age
    let walletAge = null;
    if (oldestTx) {
        const ageDays = Math.floor((now - oldestTx.timestamp) / (1000 * 60 * 60 * 24));
        walletAge = `${ageDays} days`;
    }
    
    // Calculate trust score
    let trustScore = 50;
    const flags = [];
    const positives = [];
    
    if (transactions.length === 0) {
        trustScore = 10;
        flags.push('No transaction history found');
    } else {
        // Age bonus
        if (oldestTx) {
            const ageDays = (now - oldestTx.timestamp) / (1000 * 60 * 60 * 24);
            if (ageDays > 365) {
                trustScore += 20;
                positives.push('Established wallet (1+ year old)');
            } else if (ageDays > 90) {
                trustScore += 10;
                positives.push('Wallet active for 90+ days');
            } else if (ageDays < 7) {
                trustScore -= 20;
                flags.push('New wallet (less than 7 days old)');
            }
        }
        
        // Transaction count bonus
        if (transactions.length >= 50) {
            trustScore += 15;
            positives.push('High transaction count (50+)');
        } else if (transactions.length >= 10) {
            trustScore += 5;
            positives.push('Moderate transaction history');
        } else if (transactions.length < 5) {
            trustScore -= 10;
            flags.push('Low transaction count');
        }
        
        // Activity recency
        if (newestTx) {
            const daysSinceActive = (now - newestTx.timestamp) / (1000 * 60 * 60 * 24);
            if (daysSinceActive > 180) {
                trustScore -= 15;
                flags.push('Dormant wallet (no activity in 6+ months)');
            } else if (daysSinceActive < 7) {
                trustScore += 5;
                positives.push('Recently active');
            }
        }
    }
    
    // Clamp score
    trustScore = Math.max(0, Math.min(100, trustScore));
    
    // Determine trust level
    let trustLevel;
    if (trustScore >= 80) trustLevel = 'HIGH';
    else if (trustScore >= 60) trustLevel = 'MEDIUM';
    else if (trustScore >= 40) trustLevel = 'CAUTION';
    else if (trustScore >= 20) trustLevel = 'HIGH_RISK';
    else trustLevel = 'UNKNOWN';
    
    // Build last transaction info
    let lastTransaction = null;
    if (newestTx) {
        const value = parseFloat(newestTx.value) / 1e18;
        lastTransaction = {
            hash: newestTx.hash,
            timestamp: new Date(newestTx.timestamp).toISOString(),
            value: `${value.toFixed(6)} ETH`,
            usdValue: (value * ETH_PRICE_USD).toFixed(2),
            type: newestTx.to?.toLowerCase() === address.toLowerCase() ? 'IN' : 'OUT'
        };
    }
    
    return {
        success: true,
        data: {
            address: address.toLowerCase(),
            generatedAt: new Date().toISOString(),
            chain: 'Base',
            ethPriceUsd: ETH_PRICE_USD.toFixed(2),
            trustScore,
            trustLevel,
            lastTransaction,
            transactionCount: transactions.length,
            walletAge,
            volumeIn: {
                eth: totalIn.toFixed(4),
                usd: (totalIn * ETH_PRICE_USD).toFixed(2)
            },
            volumeOut: {
                eth: totalOut.toFixed(4),
                usd: (totalOut * ETH_PRICE_USD).toFixed(2)
            },
            flags,
            positives
        }
    };
}