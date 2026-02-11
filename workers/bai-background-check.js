/**
 * BAI Background Check API - Cloudflare Worker
 * Fetches wallet data from Basescan and calculates trust metrics
 * 
 * Endpoints:
 *   GET /check/{address} - Returns wallet analysis and trust score
 *   GET /health - Health check
 */

const BASESCAN_API = 'https://api.basescan.org/api';
const COINGECKO_API = 'https://api.coingecko.com/api/v3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json'
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // Route: GET /check/{address}
      if (path.startsWith('/check/')) {
        const address = path.replace('/check/', '').toLowerCase();
        
        if (!address || !address.match(/^0x[a-f0-9]{40}$/i)) {
          return new Response(JSON.stringify({
            success: false,
            error: 'Invalid wallet address format'
          }), { status: 400, headers: corsHeaders });
        }

        const report = await generateWalletReport(address, env.BASESCAN_API_KEY);
        return new Response(JSON.stringify({
          success: true,
          data: report
        }), { headers: corsHeaders });
      }

      // Health check
      if (path === '/health') {
        return new Response(JSON.stringify({
          status: 'ok',
          service: 'BAI Background Check API',
          version: '2.0.0',
          chain: 'Base'
        }), { headers: corsHeaders });
      }

      // Default info
      return new Response(JSON.stringify({
        name: 'BAI Background Check API',
        version: '2.0.0',
        description: 'Wallet analysis and trust scoring for Base chain',
        endpoints: {
          '/check/{address}': 'Returns wallet analysis with trust score',
          '/health': 'Health check'
        },
        chain: 'Base (Chain ID: 8453)'
      }), { headers: corsHeaders });

    } catch (error) {
      return new Response(JSON.stringify({
        success: false,
        error: error.message
      }), { status: 500, headers: corsHeaders });
    }
  }
};

async function generateWalletReport(address, apiKey) {
  const [balance, transactions, ethPrice] = await Promise.all([
    fetchBalance(address, apiKey),
    fetchTransactions(address, apiKey),
    fetchEthPrice()
  ]);

  const metrics = calculateMetrics(address, transactions, balance, ethPrice);
  
  return {
    address: address,
    generatedAt: new Date().toISOString(),
    chain: 'Base',
    ethPriceUsd: ethPrice.toFixed(2),
    ...metrics
  };
}

async function fetchBalance(address, apiKey) {
  const url = `${BASESCAN_API}?module=account&action=balance&address=${address}&tag=latest&apikey=${apiKey}`;
  const response = await fetch(url);
  const data = await response.json();
  
  if (data.status === '1') {
    return BigInt(data.result);
  }
  return BigInt(0);
}

async function fetchTransactions(address, apiKey) {
  const url = `${BASESCAN_API}?module=account&action=txlist&address=${address}&startblock=0&endblock=99999999&page=1&offset=1000&sort=desc&apikey=${apiKey}`;
  const response = await fetch(url);
  const data = await response.json();
  
  if (data.status === '1' && Array.isArray(data.result)) {
    return data.result;
  }
  return [];
}

async function fetchEthPrice() {
  try {
    const response = await fetch(`${COINGECKO_API}/simple/price?ids=ethereum&vs_currencies=usd`);
    const data = await response.json();
    return data.ethereum?.usd || 2500;
  } catch {
    return 2500;
  }
}

function calculateMetrics(address, transactions, balanceWei, ethPrice) {
  const addressLower = address.toLowerCase();
  const balanceEth = Number(balanceWei) / 1e18;
  const balanceUsd = balanceEth * ethPrice;

  // No transactions case
  if (!transactions || transactions.length === 0) {
    return {
      trustScore: 10,
      trustLevel: 'UNKNOWN',
      balance: { eth: balanceEth.toFixed(6), usd: balanceUsd.toFixed(2) },
      lastTransaction: null,
      transactionCount: 0,
      walletAge: null,
      volumeIn: { eth: '0', usd: '0' },
      volumeOut: { eth: '0', usd: '0' },
      activityScore: 0,
      flags: ['No transaction history found'],
      positives: []
    };
  }

  const now = Math.floor(Date.now() / 1000);
  const firstTx = transactions[transactions.length - 1];
  const lastTx = transactions[0];
  
  const firstTxTime = parseInt(firstTx.timeStamp);
  const lastTxTime = parseInt(lastTx.timeStamp);
  
  const walletAgeDays = Math.floor((now - firstTxTime) / 86400);
  const daysSinceLastTx = Math.floor((now - lastTxTime) / 86400);

  // Volume calculations
  let totalIn = BigInt(0);
  let totalOut = BigInt(0);
  let successfulTx = 0;
  let failedTx = 0;
  const uniqueAddresses = new Set();
  const hourlyActivity = new Array(24).fill(0);

  for (const tx of transactions) {
    const value = BigInt(tx.value || '0');
    const from = tx.from?.toLowerCase();
    const to = tx.to?.toLowerCase();
    
    if (tx.isError === '0') {
      successfulTx++;
    } else {
      failedTx++;
    }

    if (to === addressLower) {
      totalIn += value;
      if (from) uniqueAddresses.add(from);
    } else if (from === addressLower) {
      totalOut += value;
      if (to) uniqueAddresses.add(to);
    }

    const txDate = new Date(parseInt(tx.timeStamp) * 1000);
    hourlyActivity[txDate.getUTCHours()]++;
  }

  const volumeInEth = Number(totalIn) / 1e18;
  const volumeOutEth = Number(totalOut) / 1e18;
  const volumeInUsd = volumeInEth * ethPrice;
  const volumeOutUsd = volumeOutEth * ethPrice;

  const peakHour = hourlyActivity.indexOf(Math.max(...hourlyActivity));

  // Trust score calculation
  let trustScore = 50;
  const flags = [];
  const positives = [];

  // Wallet age factor
  if (walletAgeDays > 365) {
    trustScore += 20;
    positives.push(`Established wallet (${walletAgeDays} days old)`);
  } else if (walletAgeDays > 180) {
    trustScore += 15;
    positives.push(`Mature wallet (${walletAgeDays} days old)`);
  } else if (walletAgeDays > 90) {
    trustScore += 10;
    positives.push(`Active wallet (${walletAgeDays} days old)`);
  } else if (walletAgeDays > 30) {
    trustScore += 5;
  } else {
    trustScore -= 10;
    flags.push(`New wallet (only ${walletAgeDays} days old)`);
  }

  // Transaction count factor
  if (transactions.length > 100) {
    trustScore += 15;
    positives.push(`High activity (${transactions.length} transactions)`);
  } else if (transactions.length > 50) {
    trustScore += 10;
  } else if (transactions.length > 20) {
    trustScore += 5;
  } else if (transactions.length < 5) {
    trustScore -= 10;
    flags.push('Very low transaction count');
  }

  // Unique interactions
  if (uniqueAddresses.size > 50) {
    trustScore += 10;
    positives.push(`Diverse interactions (${uniqueAddresses.size} unique addresses)`);
  } else if (uniqueAddresses.size > 20) {
    trustScore += 5;
  } else if (uniqueAddresses.size < 5) {
    trustScore -= 5;
    flags.push('Limited address diversity');
  }

  // Recent activity
  if (daysSinceLastTx < 7) {
    trustScore += 10;
    positives.push('Recently active');
  } else if (daysSinceLastTx < 30) {
    trustScore += 5;
  } else if (daysSinceLastTx > 90) {
    trustScore -= 5;
    flags.push(`Inactive for ${daysSinceLastTx} days`);
  }

  // Success rate
  const successRate = transactions.length > 0 ? (successfulTx / transactions.length) * 100 : 0;
  if (successRate < 80 && transactions.length > 10) {
    trustScore -= 5;
    flags.push(`High failure rate (${successRate.toFixed(1)}% success)`);
  }

  trustScore = Math.max(0, Math.min(100, trustScore));

  let trustLevel;
  if (trustScore >= 80) trustLevel = 'HIGH';
  else if (trustScore >= 60) trustLevel = 'MODERATE';
  else if (trustScore >= 40) trustLevel = 'CAUTION';
  else if (trustScore >= 20) trustLevel = 'HIGH_RISK';
  else trustLevel = 'AVOID';

  const monthsActive = Math.max(1, walletAgeDays / 30);
  const activityScore = Math.round(transactions.length / monthsActive);

  return {
    trustScore,
    trustLevel,
    balance: {
      eth: balanceEth.toFixed(6),
      usd: balanceUsd.toFixed(2)
    },
    lastTransaction: {
      timestamp: lastTxTime,
      date: new Date(lastTxTime * 1000).toISOString(),
      hash: lastTx.hash,
      daysSince: daysSinceLastTx,
      valueEth: (Number(BigInt(lastTx.value || '0')) / 1e18).toFixed(6),
      valueUsd: ((Number(BigInt(lastTx.value || '0')) / 1e18) * ethPrice).toFixed(2)
    },
    firstTransaction: {
      timestamp: firstTxTime,
      date: new Date(firstTxTime * 1000).toISOString()
    },
    transactionCount: transactions.length,
    successfulTransactions: successfulTx,
    failedTransactions: failedTx,
    successRate: successRate.toFixed(1),
    walletAge: {
      days: walletAgeDays,
      formatted: formatAge(walletAgeDays)
    },
    volumeIn: {
      eth: volumeInEth.toFixed(6),
      usd: volumeInUsd.toFixed(2)
    },
    volumeOut: {
      eth: volumeOutEth.toFixed(6),
      usd: volumeOutUsd.toFixed(2)
    },
    uniqueAddresses: uniqueAddresses.size,
    activityScore,
    peakActivityHour: `${peakHour.toString().padStart(2, '0')}:00 UTC`,
    positives,
    flags
  };
}

function formatAge(days) {
  if (days >= 365) {
    const years = Math.floor(days / 365);
    const remainingDays = days % 365;
    return `${years}y ${Math.floor(remainingDays / 30)}m`;
  } else if (days >= 30) {
    return `${Math.floor(days / 30)}m ${days % 30}d`;
  }
  return `${days}d`;
}
