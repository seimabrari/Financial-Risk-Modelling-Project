# PROJECT: FINANCIAL RISK MODELLING
# GARCH, EVT, VaR/ES and Backtesting

# necessary libraries

library(rugarch)
library(tseries)
library(quantmod) # For real market data
library(extRemes) # For EVT

# 1- We use the benchmark index for the Eurozone

getSymbols("^STOXX50E", from = "2020-01-01", to = Sys.Date())
prices <- Cl(STOXX50E)
returns <- dailyReturn(prices, type = "log") * 100 # return in %
returns <- na.omit(returns)
colnames(returns) <- "Returns"

# 2- Volatility Modelling (GJR-GARCH) 

# => Asymmetric model to capture the "Leverage Effect"

spec_gjr <- ugarchspec(
  variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)),
  mean.model = list(armaOrder = c(0,0), include.mean = TRUE),
  distribution.model = "std" # Student-t distribution for fat tails
)

fit <- ugarchfit(spec = spec_gjr, data = returns)

# 3- VaR 

# => 95% Value-at-Risk from the GARCH model

var_95 <- as.numeric(quantile(fit, 0.05))

# => Standardized residuals for Extreme Value Theory

res_std <- as.numeric(residuals(fit, standardize = TRUE))

# 4- Extreme value theory (EVT)

# => Generalized Pareto Distribution (GPD)

es_evt <- mean(returns[returns < var_95]) 

try({
  losses <- -res_std
  u_threshold <- quantile(losses, 0.90)
  fit_gpd <- fevd(losses, threshold = u_threshold, type = "GP")
  
  beta_param <- as.numeric(fit_gpd$results$par[1])
  xi_param   <- as.numeric(fit_gpd$results$par[2])
  
  # Expected Shortfall (ES) formula from coursework 
  # ES = (VaR + beta - xi * threshold) / (1 - xi)
  
  es_evt <- (abs(var_95) + beta_param - xi_param * u_threshold) / (1 - xi_param)
}, silent = TRUE)


# 5- Backtesting function

# Test de Kupiec (Unconditional Coverage) - from coursework

LRUnconditional <- function(returns, var_threshold) {
  violations <- ifelse(returns < var_threshold, 1, 0)
  v1 <- sum(violations)
  n <- length(returns)
  p <- 0.05
  pi_hat <- v1 / n
  LR <- -2 * (v1 * log(p) + (n-v1) * log(1 - p)) + 2 * (v1 * log(pi_hat) + (n-v1) * log(1 - pi_hat))
  p_value <- 1 - pchisq(LR, df = 1)
  return(p_value)
}

p_val_kupiec <- LRUnconditional(returns, var_95)

# 6- Results

print(fit)
cat("RISK METRICS REPORT\n")
cat("Index: Euro Stoxx 50\n")
cat("Value-at-Risk (95%):       ", round(var_95, 4), "%\n")
cat("Expected Shortfall (EVT):  ", round(es_evt, 4), "%\n")
cat("Kupiec Test P-value:       ", round(p_val_kupiec, 4), "\n")

cat("Current VaR (95%): ", round(tail(var_95, 1), 4), "%\n")
cat("Current ES (EVT):  ", round(tail(es_evt, 1), 4), "%\n")
cat("Kupiec Test P-value:", round(p_val_kupiec, 4), "\n")

# 7- Visualization 
par(mfrow=c(2,2))
plot(fit, which = 1)  # Time Series with VaR
plot(fit, which = 9)  # QQ-Plot for Fat Tails
plot(fit, which = 12) # News Impact Curve (Asymmetry)


# Value-at-Risk the most recent
#> tail(var_95, 1)
# Expected Shortfall (EVT) the most recent
#> tail(es_evt, 1)
