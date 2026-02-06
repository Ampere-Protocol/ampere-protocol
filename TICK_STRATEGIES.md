# Tick Configuration Strategies for Liquidity Providers

## Understanding Tick Configuration

In OrbitalPool3, liquidity is distributed across multiple **ticks** (price bands). Each tick has:
- **bandBps**: Price band width in basis points (e.g., 50 = 0.5% price range)
- **weightBps**: Percentage of liquidity allocated to this tick (must sum to 10000 = 100%)

## Strategy 1: Stablecoin Pools (Low Volatility)
**Best for: USDC-USDT-USDE, stablecoin-stablecoin pairs**

### Conservative (Tight Spreads)
```typescript
ticks: [
  { bandBps: 10, weightBps: 5000 },   // 0.1% band, 50% weight
  { bandBps: 25, weightBps: 5000 },   // 0.25% band, 50% weight
]
```
**Pros:** Maximum fee capture in normal conditions, high capital efficiency
**Cons:** Risk of impermanent loss if depeg occurs
**Expected APR:** 15-25% (high volume, tight spreads)

### Balanced (Medium Spreads)
```typescript
ticks: [
  { bandBps: 25, weightBps: 6000 },   // 0.25% band, 60% weight
  { bandBps: 50, weightBps: 4000 },   // 0.5% band, 40% weight
]
```
**Pros:** Buffer against minor depegs, still efficient
**Cons:** Slightly lower fee capture
**Expected APR:** 12-20%

### Defensive (Wide Spreads)
```typescript
ticks: [
  { bandBps: 50, weightBps: 5000 },   // 0.5% band, 50% weight
  { bandBps: 100, weightBps: 5000 },  // 1.0% band, 50% weight
]
```
**Pros:** Protection against depeg events, lower rebalancing
**Cons:** Lower capital efficiency, less fee capture
**Expected APR:** 8-15%

---

## Strategy 2: Volatile Pairs (High Volatility)
**Best for: SUI-USDC-USDT, ETH-BTC-USDC**

### Aggressive (Concentrated)
```typescript
ticks: [
  { bandBps: 100, weightBps: 7000 },  // 1% band, 70% weight
  { bandBps: 200, weightBps: 3000 },  // 2% band, 30% weight
]
```
**Pros:** High returns during trending markets
**Cons:** High impermanent loss risk, frequent rebalancing needed
**Expected APR:** 20-40% (volatile markets)
**Best for:** Active LPs who can monitor positions

### Balanced (Medium Range)
```typescript
ticks: [
  { bandBps: 200, weightBps: 5000 },  // 2% band, 50% weight
  { bandBps: 400, weightBps: 5000 },  // 4% band, 50% weight
]
```
**Pros:** Good balance of fees vs. IL protection
**Cons:** May miss out on extreme moves
**Expected APR:** 15-30%
**Best for:** Most volatile pairs

### Conservative (Wide Range)
```typescript
ticks: [
  { bandBps: 300, weightBps: 4000 },  // 3% band, 40% weight
  { bandBps: 500, weightBps: 6000 },  // 5% band, 60% weight
]
```
**Pros:** Lower IL, less monitoring required
**Cons:** Lower fee capture, capital less efficient
**Expected APR:** 10-20%
**Best for:** Passive LPs, set-and-forget strategy

---

## Strategy 3: Multi-Tick Advanced Strategies

### Ladder Strategy (Progressive Widening)
```typescript
ticks: [
  { bandBps: 50, weightBps: 4000 },   // 0.5% band, 40% weight - core range
  { bandBps: 150, weightBps: 3500 },  // 1.5% band, 35% weight - medium buffer
  { bandBps: 300, weightBps: 2500 },  // 3% band, 25% weight - wide safety net
]
```
**Use case:** Uncertain market conditions
**Pros:** Gradual exposure, balanced risk/reward
**Expected APR:** 12-25%

### Heavy Concentration Strategy
```typescript
ticks: [
  { bandBps: 25, weightBps: 8000 },   // 0.25% band, 80% weight
  { bandBps: 200, weightBps: 2000 },  // 2% band, 20% weight - safety
]
```
**Use case:** High conviction on stable price
**Pros:** Maximum fee capture in target range
**Cons:** High risk if price moves out of range
**Expected APR:** 25-50% (if price stays in range)

### Equal Distribution (Neutral)
```typescript
ticks: [
  { bandBps: 100, weightBps: 5000 },  // 1% band, 50% weight
  { bandBps: 100, weightBps: 5000 },  // 1% band, 50% weight (different position)
]
```
**Use case:** Completely uncertain about price direction
**Pros:** Simplicity, symmetric exposure
**Expected APR:** Varies based on volatility

---

## Decision Framework

### Choose Based on:

1. **Asset Volatility**
   - Stablecoins: 10-50 bps bands
   - Low volatility: 50-200 bps bands
   - High volatility: 200-500 bps bands

2. **Your Risk Tolerance**
   - Risk-averse: Wider bands (200+ bps), more even distribution
   - Risk-neutral: Medium bands (100-200 bps), balanced weights
   - Risk-seeking: Tight bands (10-100 bps), concentrated weights

3. **Time Commitment**
   - Active management: Tighter bands for higher returns
   - Passive: Wider bands for less rebalancing

4. **Market Conditions**
   - Stable markets: Tighter bands
   - Volatile markets: Wider bands
   - Trending markets: Asymmetric weight distribution

---

## Example Configurations by Pool Type

### USDC-USDT-USDE (All Stablecoins)
```typescript
// Recommended
ticks: [
  { bandBps: 10, weightBps: 5000 },   // Ultra tight
  { bandBps: 25, weightBps: 5000 },   // Safety buffer
]
```

### SUI-USDC-USDT (Volatile-Stable-Stable)
```typescript
// Recommended
ticks: [
  { bandBps: 150, weightBps: 6000 },  // Main range
  { bandBps: 300, weightBps: 4000 },  // Wide buffer
]
```

### BTC-ETH-USDC (Volatile-Volatile-Stable)
```typescript
// Recommended
ticks: [
  { bandBps: 250, weightBps: 5000 },  // Medium-wide
  { bandBps: 500, weightBps: 5000 },  // Very wide
]
```

---

## Key Metrics to Monitor

1. **Fee APR**: Fees earned / Liquidity provided
2. **Impermanent Loss**: Loss vs. holding tokens
3. **Utilization Rate**: How often liquidity is used
4. **Rebalancing Frequency**: How often you need to adjust

---

## Pro Tips

✅ **DO:**
- Start conservative, tighten as you learn
- Monitor IL vs. fees earned
- Adjust based on market conditions
- Use tighter bands for stablecoin pairs
- Diversify across multiple tick configs

❌ **DON'T:**
- Over-concentrate in one tick (unless high conviction)
- Ignore impermanent loss calculations
- Set and forget volatile pairs with tight bands
- Use stablecoin strategies for volatile assets

---

## Advanced: Dynamic Rebalancing Strategy

**Market Regime Detection:**
- Low volatility: Move to tighter bands (more weight to narrow ticks)
- High volatility: Move to wider bands (spread out liquidity)
- Trending: Asymmetric allocation (more weight toward trend direction)

**Rebalancing Triggers:**
- Price moves 2-3 bands away from current position
- Utilization drops below 50% for 24 hours
- IL exceeds fee earnings by 20%+

---

## Conclusion

The optimal tick configuration depends on:
1. Asset class volatility
2. Your risk tolerance  
3. Time commitment
4. Market conditions

**Beginner recommendation:** Start with balanced strategies (Strategy 1 or 2 Balanced) and adjust based on performance.
