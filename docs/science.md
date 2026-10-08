# Science

Source for the scientific report: the problem, our methods, what is new, and what we found. Fill in each section as the work happens.

## 1. Problem

Commercial sensor-based irrigation systems monitor moisture at each sensor and irrigate where a sensor reports dry soil. Between sensors, the moisture state is unknown, and covering a field densely enough to see it would need a very large number of sensors.

**Problem:** given a few moisture sensors and known irrigation inputs, estimate the moisture distribution in the soil and the soil hydraulic properties that govern how water moves. Irrigation can also be used as an excitation: water applied at the surface moves through the soil, the sensors record the response, and the inverse model infers the unmeasured state.

**Research questions**

1. How well can the moisture state and soil parameters be reconstructed from sparse sensors under normal irrigation?
2. Do designed irrigation pulses make them easier to identify than normal irrigation?
3. How much extra water does that information cost?
4. Which sensor locations and pulse characteristics give the most information?
5. How robust is the estimate to sensor noise and uncertainty in soil properties, initial moisture and irrigation input?

**Scope:** 1D soil column first, 2D vertical cross-section after the interim. Simulation only.

**Unknowns:** volumetric water content $\theta(z,t)$; soil parameters $K_s$, $\alpha$, $n$ (possibly $\theta_s$, $\theta_r$).
**Knowns:** irrigation input (rate, location, duration); noisy moisture at sensor locations; temperature and humidity if evaporation is modelled.

## 2. Related work

- Richards equation [richards1931]; van Genuchten–Mualem model [vangenuchten1980, mualem1976]; typical parameters by soil texture [carsel1988]; mass-conservative numerical scheme with a standard test case [celia1990].
- Jinfeng Liu's group (Univ. of Alberta) has done state and parameter estimation with the Richards equation from sparse sensors, including sensor placement [arxiv2203.06548], model mismatch [arxiv2306.01757], joint estimation [arxiv2006.04931] and model reduction for irrigation [arxiv2404.01468]. Irrigation MPC with active uncertainty learning also exists [arxiv1810.05947].
- **So:** estimating soil moisture from sparse sensors is not new by itself. Still to check: has irrigation been framed as input design for identifiability, or has the water cost of information been quantified?

## 3. Forward model

1D Richards equation, mixed form, $z$ positive upward:

$$\frac{\partial \theta(h)}{\partial t} = \frac{\partial}{\partial z}\left[ K(h)\left(\frac{\partial h}{\partial z} + 1\right)\right]$$

van Genuchten–Mualem, with $m = 1 - 1/n$ and $S_e = (\theta-\theta_r)/(\theta_s-\theta_r)$:

$$\theta(h) = \theta_r + \frac{\theta_s-\theta_r}{[1+(\alpha|h|)^n]^m}, \qquad K = K_s S_e^{1/2}\left[1-(1-S_e^{1/m})^m\right]^2$$

- Top boundary: irrigation flux (± rain, evaporation). Bottom: free drainage. Units: cm and h (proposed).
- Implicit finite differences, modified Picard iteration [celia1990].
- Reference soil: TBD (loam or sandy loam from [carsel1988]).
- The "true" soil used to generate measurements has a finer grid and more heterogeneity than the estimation model. Record exactly how they differ.

## 4. Estimation method

Start with batch nonlinear least squares over a time window (uncertainty from the fit). Ensemble Kalman filter after the interim if we need online estimation and uncertainty for active sensing.

## 5. Irrigation design and sensor selection

Compare a normal irrigation schedule with designed pulses (amplitude, duration, timing, location in 2D), measured by parameter uncertainty against extra water used. Then choose sensor positions or next measurements to reduce uncertainty fastest.

## 6. Novelty

| Claim | Status | Experiments |
|---|---|---|
| Designed irrigation pulses improve identifiability of soil parameters | not started | |
| The water cost of information can be quantified as a trade-off curve | not started | |
| Active sensing reduces uncertainty faster than fixed sensors | not started | |

Draft pitch: *We quantify how much extra irrigation water it takes to learn the soil well enough to irrigate efficiently.*

## 7. Findings

Each finding cites the experiment that supports it (see `experiments.md`).

-

**Limitations and negative results:**

-

## References

See `references.bib`.
