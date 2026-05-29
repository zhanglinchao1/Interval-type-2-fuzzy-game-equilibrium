# Chapter 4 Interval Type-2 Fuzzy Game Equilibrium and Two-Time-Scale Stability Analysis

Based on the agent set $\mathcal{N}$, strategy set $\mathcal{S}$, mixed-strategy profile $\pi$, interval type-2 state membership degree $\widetilde{\mu}_{k,i}$, on-chain governance weight $\boldsymbol{\omega}(h)$, and its payoff-layer projection weight $\boldsymbol{\theta}(h)$ defined above, this chapter constructs an interval type-2 fuzzy payoff game, and presents the equilibrium definition, solution algorithm, and two-time-scale stability analysis. For notational simplicity, within a fixed governance cycle, $\boldsymbol{\theta}(h)$ is abbreviated as $\boldsymbol{\theta}$, and $\boldsymbol{\omega}(h)$ is abbreviated as $\boldsymbol{\omega}$. The following notation is used throughout this chapter:

- $i\in\mathcal{N}$ denotes an agent, and $N=|\mathcal{N}|$; $j\in\mathcal{S}_i$ denotes a pure strategy of agent $i$; $k\in\{\mathrm{trust},\mathrm{delay},\mathrm{res}\}$ denotes a state membership category; $\ell\in\{1,\ldots,K\}$ denotes an on-chain governance rule; and $r\in\mathbb{N}$ denotes an algorithm iteration round.
- The multi-agent strategy profile is denoted by $\pi=(\pi_i)_{i\in\mathcal{N}}$, with $\|\pi\|_1=\sum_{i\in\mathcal{N}}\|\pi_i\|_1$.
- The multi-agent algorithmic payoff vector is denoted by $\boldsymbol{\nu}=(\boldsymbol{\nu}_i)_{i\in\mathcal{N}}$, with $\|\boldsymbol{\nu}\|_1=\sum_{i\in\mathcal{N}}\|\boldsymbol{\nu}_i\|_1$.
- The defuzzified center payoff is uniformly written as $\widehat{U}_i(\pi_i,\pi_{-i};\boldsymbol{\theta})$.

## 4.1 Interval Type-2 Fuzzy Payoff Game Modeling

This section adopts the UMF/LMF representation of interval type-2 fuzzy sets, and uses the lower and upper bound intervals of the FOU as the payoff computation object. Fig. 4-1 shows the construction relationship from the state vector $\mathbf{z}_i(t)$, governance weight $\boldsymbol{\omega}(h)$, and strategy set $\mathcal{S}$ to the interval type-2 fuzzy payoff $\widetilde U_i$.

<img src="figures/chapter4/fig4-1.png" alt="4-1" style="zoom:25%;" />

**Fig. 4-1. Construction of interval type-2 fuzzy payoffs**

### 4.1.1 Strategy-Profile-Induced Interval Type-2 State Membership Degrees

The communication time slot $t$ defines the interval type-2 state membership degree $\widetilde{\mu}_{k,i}(t)=[\underline{\mu}_{k,i}(t),\overline{\mu}_{k,i}(t)]$. In game modeling, the state membership degree in time slot $t$ is jointly determined by the action profile selected by all agents in that time slot; hence, it can be re-indexed according to the action profile. Let the joint action space be $\mathcal{A}\triangleq\prod_{i\in\mathcal{N}}\mathcal{S}_i$, and denote a deterministic action profile as $a=(a_i,a_{-i})\in\mathcal{A}$. Under $a$, the interval type-2 membership degree of agent $i$ for state category $k$ is

$$
\widetilde{\mu}_{k,i}(a)
=
[\underline{\mu}_{k,i}(a),\overline{\mu}_{k,i}(a)]\subseteq[0,1]
\tag{4-1}
$$

Given the mixed-strategy profile $\pi=(\pi_i)_{i\in\mathcal{N}}$, the probability of action profile $a$ under independent joint distribution is $\Pr(a\mid\pi)=\prod_{i\in\mathcal{N}}\pi_{i,a_i}$. Accordingly, the lower and upper bounds of the strategy-induced interval type-2 membership degree of agent $i$ under $\pi$ are simultaneously given by

$$
[\underline{\mu}_{k,i}(\pi),\overline{\mu}_{k,i}(\pi)]
=
\sum_{a\in\mathcal{A}}
\Pr(a\mid\pi)\,
[\underline{\mu}_{k,i}(a),\overline{\mu}_{k,i}(a)]
\tag{4-2}
$$

Expectation preserves the order of lower and upper bounds component-wise, and thus $\underline{\mu}_{k,i}(\pi)\le\overline{\mu}_{k,i}(\pi)$. Collecting over $k\in\{\mathrm{trust},\mathrm{delay},\mathrm{res}\}$ yields the strategy-dependent interval type-2 state membership vector $\widetilde{\mathbf{z}}_i(\pi)=\{[\underline{\mu}_{k,i}(\pi),\overline{\mu}_{k,i}(\pi)]\}_k$.

### 4.1.2 Interval Type-2 Fuzzy Payoff Aggregation

According to (3-8), the on-chain governance weight $\boldsymbol{\omega}\in\Delta^K$ is mapped by the nonnegative projection matrix $P_{\mathrm{pay}}$ to the three-dimensional payoff-layer weight $\boldsymbol{\theta}=P_{\mathrm{pay}}\boldsymbol{\omega}=[\theta_{\mathrm{trust}},\theta_{\mathrm{delay}},\theta_{\mathrm{res}}]^T\in\Delta^3$, which regulates the three payoff components of trusted interaction, communication timeliness, and resource feasibility. Based on $\widetilde{\mathbf{z}}_i(\pi)$ and $\boldsymbol{\theta}$, the lower and upper bounds of the interval type-2 fuzzy payoff of agent $i$ are defined as

$$
\underline{U}_i(\pi;\boldsymbol{\theta})
=
\sum_{k\in\{\mathrm{trust},\mathrm{delay},\mathrm{res}\}}
\theta_k\,\underline{\mu}_{k,i}(\pi)
\tag{4-3}
$$

$$
\overline{U}_i(\pi;\boldsymbol{\theta})
=
\sum_{k\in\{\mathrm{trust},\mathrm{delay},\mathrm{res}\}}
\theta_k\,\overline{\mu}_{k,i}(\pi)
\tag{4-4}
$$

Since $\sum_k\theta_k=1$ and $\underline{\mu}_{k,i},\overline{\mu}_{k,i}\in[0,1]$, it follows immediately that $0\le\underline{U}_i\le\overline{U}_i\le 1$, and thus the interval type-2 fuzzy payoff of agent $i$ is $\widetilde{U}_i(\pi;\boldsymbol{\theta})=[\underline{U}_i(\pi;\boldsymbol{\theta}),\overline{U}_i(\pi;\boldsymbol{\theta})]\subseteq[0,1]$. The corresponding payoff aggregation mapping is

$$
\mathcal{R}_{\boldsymbol{\theta}}
\!\left(\{[\underline{\mu}_{k,i},\overline{\mu}_{k,i}]\}_k\right)
=
\!\left[
\sum_k\theta_k\underline{\mu}_{k,i},\,
\sum_k\theta_k\overline{\mu}_{k,i}
\right]
\tag{4-5}
$$

That is, $\mathcal{R}_{\boldsymbol{\theta}}:[0,1]^3\times[0,1]^3\rightarrow\mathcal{I}([0,1])$, where $\mathcal{I}([0,1])$ denotes the set of closed intervals on $[0,1]$. This mapping preserves the order of lower and upper bounds, and is linear with respect to the agent's own strategy $\pi_i$ when $\pi_{-i}$ and $\boldsymbol{\theta}$ are fixed.

### 4.1.3 Definition of the Interval Type-2 Fuzzy Game

Based on the above construction, the interval type-2 fuzzy game for blockchain-governed physical agents is defined as

$$
\mathcal{G}_{\mathrm{IT2}}
=
\left\langle
\mathcal{N},
\{\mathcal{S}_i\}_{i\in\mathcal{N}},
\{\widetilde{U}_i\}_{i\in\mathcal{N}},
\boldsymbol{\theta},
\mathcal{R}_{\boldsymbol{\theta}}
\right\rangle
\tag{4-6}
$$

where $\mathcal{N}$ is the set of physical agents, $\mathcal{S}_i\subseteq\mathcal{S}$ is the feasible strategy set of agent $i$, $\widetilde{U}_i$ is the interval type-2 fuzzy payoff, $\boldsymbol{\theta}=P_{\mathrm{pay}}\boldsymbol{\omega}$ is the payoff-layer projection weight, and $\mathcal{R}_{\boldsymbol{\theta}}$ is the payoff aggregation mapping. Since the payoff structure depends only on the payoff-layer weight $\boldsymbol{\theta}$, the on-chain governance weight $\boldsymbol{\omega}$ does not directly enter the game tuple, but appears as a slow-time-scale governance dynamic variable. The game integrates off-chain strategy interaction, interval type-2 state membership degrees, and on-chain governance weights into a unified payoff structure. Next, the computable $\alpha$-cut mechanism is used to transform $\mathcal{G}_{\mathrm{IT2}}$ into a defuzzified game, based on which a robust $\alpha$-Fuzzy Nash Equilibrium is defined.

## 4.2 $\alpha$-Fuzzy Nash Equilibrium and Defuzzified Game

Interval type-2 fuzzy payoffs characterize strategic payoff uncertainty through lower and upper payoff bounds. This section introduces a computable $\alpha$-cut in center-radius form, compresses the complete payoff interval into an $\alpha$-cut payoff interval under a given confidence level, and extracts the defuzzified center to construct a deterministic-payoff game. On this basis, a conservative-optimistic comparison criterion is adopted to define an $\varepsilon_{\alpha}$-approximate $\alpha$-Fuzzy Nash Equilibrium, so that the optimistic upper payoff of any unilateral deviation is constrained by the conservative lower payoff of the current strategy, forming a robust equilibrium criterion for interval type-2 fuzzy payoffs. Fig. 4-2 shows the basic logic of $\alpha$-cut interval contraction, defuzzified payoff construction, and robust $\alpha$-FNE judgment.

<img src="figures/chapter4/fig4-2.png" alt="4-2" style="zoom:25%;" />

**Fig. 4-2. $\alpha$-cut, defuzzified payoff, and robust $\alpha$-FNE judgment**

### 4.2.1 Computable $\alpha$-Cut of Interval Type-2 Fuzzy Payoffs

Since $\widetilde{U}_i$ is an interval type-2 fuzzy payoff with a footprint of uncertainty, the unilateral deviation improvement relation in conventional scalar-payoff games cannot be directly used. To obtain comparable payoff objects, this paper adopts a computable $\alpha$-cut based on the center and radius of the payoff interval.

For the interval type-2 fuzzy payoffs given in (4-3) and (4-4), define the nominal center and basic uncertainty radius as

$$
\widehat{U}_i(\pi;\boldsymbol{\theta})
=
\frac{\underline{U}_i(\pi;\boldsymbol{\theta})+\overline{U}_i(\pi;\boldsymbol{\theta})}{2},
\qquad
\rho_i(\pi;\boldsymbol{\theta})
=
\frac{\overline{U}_i(\pi;\boldsymbol{\theta})-\underline{U}_i(\pi;\boldsymbol{\theta})}{2}
\tag{4-7}
$$

Given a confidence level $\alpha\in(0,1]$, the $\alpha$-cut payoff interval is denoted by

$$
U_i^{\alpha}(\pi;\boldsymbol{\theta})
=
[\underline{U}_i^{\alpha}(\pi;\boldsymbol{\theta}),
\overline{U}_i^{\alpha}(\pi;\boldsymbol{\theta})]
\tag{4-8}
$$

whose lower and upper bounds are

$$
\underline{U}_i^{\alpha}(\pi;\boldsymbol{\theta})
=
\widehat{U}_i(\pi;\boldsymbol{\theta})-(1-\alpha)\rho_i(\pi;\boldsymbol{\theta}),
\quad
\overline{U}_i^{\alpha}(\pi;\boldsymbol{\theta})
=
\widehat{U}_i(\pi;\boldsymbol{\theta})+(1-\alpha)\rho_i(\pi;\boldsymbol{\theta})
\tag{4-9}
$$

This $\alpha$-cut uses the nominal center as the reference, with the radius linearly contracted by $(1-\alpha)$. From (4-7), when $\alpha=1$, $U_i^{\alpha}$ degenerates to the nominal center $\widehat{U}_i$; when $\alpha\rightarrow0^+$, $U_i^{\alpha}$ recovers the complete payoff interval $[\underline{U}_i,\overline{U}_i]$.

The $\alpha$-uncertainty radius is further defined as

$$
\rho_i^{\alpha}(\pi;\boldsymbol{\theta})
=
\frac{\overline{U}_i^{\alpha}(\pi;\boldsymbol{\theta})-
\underline{U}_i^{\alpha}(\pi;\boldsymbol{\theta})}{2}
=(1-\alpha)\rho_i(\pi;\boldsymbol{\theta})
\tag{4-10}
$$

Equation (4-9) shows that the center of the $\alpha$-cut payoff interval is always the nominal center $\widehat{U}_i(\pi;\boldsymbol{\theta})$, which is independent of the confidence level $\alpha$. The parameter $\alpha$ only controls the width of the payoff interval through the $\alpha$-uncertainty radius $\rho_i^{\alpha}=(1-\alpha)\rho_i$. Therefore, the defuzzified game constructed below using the nominal center $\widehat{U}_i$ and its equilibrium do not depend on $\alpha$. The confidence level $\alpha$ affects the robust equilibrium criterion and the approximation error budget. A larger $\alpha$ produces a narrower $\alpha$-cut payoff interval, making the robust $\alpha$-FNE criterion less conservative.

### 4.2.2 Robust $\alpha$-Fuzzy Nash Equilibrium

**Definition 1 ($\varepsilon_{\alpha}$-robust $\alpha$-Fuzzy Nash Equilibrium)** Given $\alpha\in(0,1]$ and error tolerance $\varepsilon_{\alpha}\ge 0$, if a mixed-strategy profile $\pi^{\ast}$ satisfies, for any agent $i\in\mathcal{N}$ and any feasible deviation strategy $\pi_i'\in\Delta(\mathcal{S}_i)$,

$$
\overline{U}_i^{\alpha}(\pi_i',\pi_{-i}^{\ast};\boldsymbol{\theta})
\le
\underline{U}_i^{\alpha}(\pi_i^{\ast},\pi_{-i}^{\ast};\boldsymbol{\theta})
+
\varepsilon_{\alpha}
\tag{4-11}
$$

then $\pi^{\ast}$ is called an $\varepsilon_{\alpha}$-robust $\alpha$-Fuzzy Nash Equilibrium of $\mathcal{G}_{\mathrm{IT2}}$ at confidence level $\alpha$, abbreviated as an $\varepsilon_{\alpha}$-robust $\alpha$-FNE. This definition adopts a conservative-current-payoff versus optimistic-deviation-payoff interval dominance criterion, and is suitable for cases in which payoff intervals cannot be directly totally ordered.

### 4.2.3 Defuzzified Game and Approximate Equivalence

To obtain a computable form, define the defuzzified game using the center $\widehat{U}_i$ of the $\alpha$-cut payoff interval as the payoff:

$$
\Gamma
=
\left\langle
\mathcal{N},
\{\mathcal{S}_i\}_{i\in\mathcal{N}},
\{\widehat{U}_i\}_{i\in\mathcal{N}},
\boldsymbol{\theta}
\right\rangle
\tag{4-12}
$$

According to the $\alpha$-cut construction, $\widehat{U}_i$ is independent of the confidence level $\alpha$, and thus the defuzzified game $\Gamma$ is independent of $\alpha$. The defuzzified game replaces the original interval type-2 fuzzy payoff with the nominal center payoff $\widehat{U}_i$, transforming the interval type-2 fuzzy game into a solvable deterministic-payoff game.

**Lemma 1 (Approximate equivalence between the defuzzified game and the interval type-2 fuzzy game)** Suppose that $\pi^{\ast}$ is a Nash equilibrium of the defuzzified game $\Gamma$. If the $\alpha$-uncertainty radius satisfies the uniform bound

$$
\rho_i^{\alpha}(\pi;\boldsymbol{\theta})
\le
\bar{\rho}_{\alpha},
\quad
\forall i\in\mathcal{N},\ \forall \pi\in\prod_i\Delta(\mathcal{S}_i)
\tag{4-13}
$$

then $\pi^{\ast}$ is a $2\bar{\rho}_{\alpha}$-robust $\alpha$-FNE of $\mathcal{G}_{\mathrm{IT2}}$. The proof is given in Appendix A.

From (4-10), $\bar{\rho}_{\alpha}=(1-\alpha)\bar{\rho}$, where $\bar{\rho}$ is a uniform upper bound of the basic uncertainty radius $\rho_i$. Therefore, the error budget $2\bar{\rho}_{\alpha}$ tightens linearly as $\alpha$ increases. Lemma 1 provides an error budget from the solution of $\Gamma$ to the robust equilibrium of the interval type-2 fuzzy game: the same defuzzified equilibrium $\pi^{\ast}$ is a robust $\alpha$-FNE for all $\alpha$, with approximation accuracy determined by $\alpha$. The subsequent equilibrium solving is performed on $\Gamma$.

## 4.3 W-FBRI Equilibrium-Solving Algorithm

### 4.3.1 Algorithm Construction

On the defuzzified game $\Gamma$, the Weighted Fuzzy Best Response Iteration (W-FBRI) algorithm is constructed to solve multi-agent mixed-strategy equilibria. The algorithm uses entropy-regularized soft best responses and damped updates. The former ensures that the response mapping is continuous and uniquely defined, while the latter controls the update strength between the current strategy and the soft best response.

Let $\pi_i^{(r)}\in\Delta(\mathcal{S}_i)$ be the mixed strategy of agent $i$ in iteration $r$, and let $\pi_{-i}^{(r)}$ denote the strategy profile of the other agents. Define the pure-strategy defuzzified payoff vector of agent $i$ in iteration $r$ as

$$
\boldsymbol{\nu}_i^{(r)}
=
[\nu_{i,j}^{(r)}]_{j\in\mathcal{S}_i},
\quad
\nu_{i,j}^{(r)}
=
\widehat{U}_i(\delta_j,\pi_{-i}^{(r)};\boldsymbol{\theta})
\tag{4-14}
$$

where $\delta_j\in\Delta(\mathcal{S}_i)$ denotes the one-hot mixed strategy that selects pure strategy $j$.

The entropy-regularized soft best response of agent $i$ is defined as the maximizer $\mathrm{BR}_{i,\lambda}(\pi^{(r)})=\arg\max_{q_i\in\Delta(\mathcal{S}_i)}[\langle q_i,\boldsymbol{\nu}_i^{(r)}\rangle-\lambda\sum_{j}q_{i,j}\ln q_{i,j}]$, where $\lambda>0$ is the entropy regularization coefficient. The objective function is the sum of a linear term and a strictly concave entropy term, and is therefore strictly concave; hence, the soft best response exists uniquely. The detailed optimization formulation and Lagrangian derivation are given in Appendix C.1. Its closed-form solution is

$$
[\mathrm{BR}_{i,\lambda}(\pi^{(r)})]_j
=
\frac{\exp(\nu_{i,j}^{(r)}/\lambda)}
{\sum_{h\in\mathcal{S}_i}\exp(\nu_{i,h}^{(r)}/\lambda)},
\quad
j\in\mathcal{S}_i
\tag{4-15}
$$

The next strategy is obtained by the damped update:

$$
\pi_i^{(r+1)}
=(1-\beta)\pi_i^{(r)}+
\beta\,\mathrm{BR}_{i,\lambda}(\pi^{(r)}),
\quad
0<\beta\le 1
\tag{4-16}
$$

Since both $\pi_i^{(r)}$ and $\mathrm{BR}_{i,\lambda}(\pi^{(r)})$ belong to the simplex $\Delta(\mathcal{S}_i)$, $\pi_i^{(r+1)}$ also belongs to $\Delta(\mathcal{S}_i)$.

**Algorithm 1: W-FBRI Equilibrium-Solving Algorithm**

Input: Initial mixed-strategy profile $\pi^{(0)}=(\pi_i^{(0)})_{i\in\mathcal{N}}$, payoff-layer weight $\boldsymbol{\theta}$, entropy regularization coefficient $\lambda$, damping step size $\beta$, and stopping threshold $\varepsilon_{\mathrm{tol}}$.

Output: Approximate equilibrium $\pi^{\ast}$ of the defuzzified game $\Gamma$.

1. Initialize $r=0$ and choose $\pi_i^{(0)}\in\Delta(\mathcal{S}_i)$ for each agent $i$;
2. For each $i\in\mathcal{N}$, compute $\boldsymbol{\nu}_i^{(r)}$ according to (4-14), using $\pi^{(r)}$ and $\boldsymbol{\theta}$;
3. Compute $\mathrm{BR}_{i,\lambda}(\pi^{(r)})$ according to (4-15);
4. Update $\pi_i^{(r+1)}$ according to (4-16);
5. If $\max_{i\in\mathcal{N}}\|\pi_i^{(r+1)}-\pi_i^{(r)}\|_1\le\varepsilon_{\mathrm{tol}}$, output $\pi^{\ast}=\pi^{(r+1)}$ and terminate;
6. Otherwise, set $r\leftarrow r+1$ and return to Step 2.

### 4.3.2 Equilibrium Existence and Convergence

**Theorem 1 (Existence of defuzzified equilibrium)** Suppose that, for each agent $i\in\mathcal{N}$, the mixed-strategy space $\Delta(\mathcal{S}_i)$ is nonempty, compact, and convex, and the defuzzified payoff $\widehat{U}_i(\pi_i,\pi_{-i};\boldsymbol{\theta})$ is continuous in $\pi$ and quasi-concave in $\pi_i$. Then the defuzzified game $\Gamma$ has at least one mixed-strategy Nash equilibrium. For the linearly aggregated payoffs in (4-3) and (4-4), $\widehat{U}_i$ is linear in $\pi_i$, and thus quasi-concavity holds. The proof is given in Appendix B.

**Theorem 2 (Global contraction convergence of W-FBRI)** Suppose that the global defuzzified payoff mapping $\boldsymbol{\nu}(\pi)=(\boldsymbol{\nu}_i(\pi))_{i\in\mathcal{N}}$ is Lipschitz continuous with respect to $\pi$ under the $\ell_1$ norm, i.e., there exists $L_U>0$ such that $\|\boldsymbol{\nu}(\pi)-\boldsymbol{\nu}(\pi')\|_1\le L_U\|\pi-\pi'\|_1$ (see Appendix C, Eq. (C-7) for the detailed form). If the contraction condition

$$
\frac{L_U}{\lambda}<1
\tag{4-17}
$$

is satisfied, then the global W-FBRI iteration mapping $F(\pi)=[(1-\beta)\pi_i+\beta\,\mathrm{BR}_{i,\lambda}(\pi)]_{i\in\mathcal{N}}$ (see Appendix C, Eq. (C-11)) is a contraction mapping on $(\prod_i\Delta(\mathcal{S}_i),\|\cdot\|_1)$. The iteration sequence $\{\pi^{(r)}\}$ globally converges to the unique fixed point $\pi^{\ast}$, and satisfies

$$
\|\pi^{(r)}-\pi^{\ast}\|_1
\le
\left[(1-\beta)+\beta L_U/\lambda\right]^r
\|\pi^{(0)}-\pi^{\ast}\|_1
\tag{4-18}
$$

The proof is given in Appendix C.

**Corollary 1 (Overall error budget)** Under the conditions of Theorem 2, if the uniform bound $\bar{\rho}_{\alpha}$ in (4-13) holds, and the deviation of the entropy-regularized equilibrium from the non-regularized defuzzified equilibrium does not exceed $C_{\lambda}\lambda$, then the W-FBRI convergence point $\pi^{\ast}$ is a $(2\bar{\rho}_{\alpha}+C_{\lambda}\lambda+\varepsilon_{\mathrm{tol}})$-robust $\alpha$-FNE of $\mathcal{G}_{\mathrm{IT2}}$, where $C_{\lambda}>0$ is a constant depending on the payoff range. Since $\bar{\rho}_{\alpha}=(1-\alpha)\bar{\rho}$, this error budget holds for any confidence level $\alpha$ and tightens as $\alpha$ increases.

### 4.3.3 Complexity Analysis

For a single agent $i$, the computational complexity of the softmax response and damped update is $O(|\mathcal{S}_i|)$, provided that $\boldsymbol{\nu}_i^{(r)}$ is already known. Exact computation of $\boldsymbol{\nu}_i^{(r)}$ requires evaluating the joint-action expectations in (4-2), whose complexity grows with the joint action space $\mathcal{A}=\prod_i\mathcal{S}_i$. To obtain a scalable implementation, this paper computes $\widehat{U}_i$ using mean-field statistical summaries or local-neighborhood approximations. Under the mean-field approximation, payoff evaluation depends on population strategy statistics rather than complete joint-action enumeration, and each evaluation is $O(1)$. The system-level complexity per iteration is

$$
O\left(\sum_{i\in\mathcal{N}}|\mathcal{S}_i|\right)
=O(|\mathcal{S}|N)
\tag{4-19}
$$

Under the unified four-strategy representation, (4-19) becomes $O(4N)$. If a general multi-agent explicit coupling is used and no local decomposable structure exists, exact payoff evaluation may require $O(|\mathcal{S}|^N)$ joint-action enumeration. If the payoff depends only on the local neighborhood $\mathcal{N}_i^{\mathrm{loc}}$, the per-iteration complexity can be reduced to $O(\sum_i |\mathcal{S}|^{|\mathcal{N}_i^{\mathrm{loc}}|})$.

Let $R$ be the number of iterations required to reach the stopping threshold $\varepsilon_{\mathrm{tol}}$. From (4-18),

$$
R
=
O\left(
\frac{\log(\varepsilon_{\mathrm{tol}}^{-1})}
{\log\left([(1-\beta)+\beta L_U/\lambda]^{-1}\right)}
\right)
\tag{4-20}
$$

Therefore, under the mean-field approximation, the total complexity is $O(R|\mathcal{S}|N)$. The subsequent theory and experiments in this paper use the mean-field approximation as the basic setting.

## 4.4 Evolutionary Stability and Two-Time-Scale Analysis of Blockchain Governance

W-FBRI provides the instantaneous mixed-strategy equilibrium under the defuzzified game. To analyze long-term evolutionary behavior and the influence of slow on-chain governance on equilibrium stability, this section introduces replicator dynamics and a two-time-scale blockchain governance model under the mean-field approximation, and completes the stability analysis based on a Lyapunov function.

### 4.4.1 Bridge from Multi-Agent Strategies to Population Evolution

To connect with long-term population evolution, this section provides a macroscopic characterization under the homogeneous mean-field assumption: agents of the same type in the population share the same mixed strategy, and the population proportion $x_j$ over the four combined strategies $\mathcal{S}=\{SC,SP,DC,DP\}$ corresponds to the probability that a representative agent adopts strategy $j$. Under this assumption, the defuzzified equilibrium obtained above corresponds to the steady-state distribution in population evolution.

Let the population state be $x(t)=[x_{SC}(t),x_{SP}(t),x_{DC}(t),x_{DP}(t)]^T\in\Delta^4$, where $t$ denotes continuous evolutionary time. Given the payoff-layer weight $\boldsymbol{\theta}=P_{\mathrm{pay}}\boldsymbol{\omega}$, the population defuzzified payoff of strategy $j$ is $U_j(x,\boldsymbol{\theta})=\widehat{U}(\delta_j,x;\boldsymbol{\theta})$, where $\widehat{U}$ is the homogeneous-population form of the defuzzified center payoff defined in (4-7), with the agent index $i$ omitted due to homogeneity. The population average payoff is

$$
\overline{U}(x,\boldsymbol{\theta})
=
\sum_{j\in\mathcal{S}}x_jU_j(x,\boldsymbol{\theta})
\tag{4-21}
$$

The off-chain strategy layer evolves according to replicator dynamics:

$$
\dot{x}_j
=x_j[U_j(x,\boldsymbol{\theta})-
\overline{U}(x,\boldsymbol{\theta})],
\quad
j\in\mathcal{S}
\tag{4-22}
$$

The proportion of strategies with payoffs above the population average increases, while that of strategies with payoffs below the average decreases.

### 4.4.2 Local Evolutionary Stability of $\alpha$-FNE

Let $x^{\ast}\in\mathrm{int}(\Delta^4)$ be the population equilibrium point corresponding to the robust $\alpha$-FNE under the current payoff-layer weight $\boldsymbol{\theta}$. Define the KL-type potential function

$$
V_x(x;\boldsymbol{\theta})
=
\sum_{j\in\mathcal{S}}
x_j^{\ast}\ln\frac{x_j^{\ast}}{x_j}
\tag{4-23}
$$

and denote the tangent space of the simplex by

$$
\mathcal{T}
=
\{\delta x\in\mathbb{R}^4\mid\mathbf{1}^T\delta x=0\}
\tag{4-24}
$$

When $x\in\mathrm{int}(\Delta^4)$, $V_x(x;\boldsymbol{\theta})\ge0$, and $V_x(x;\boldsymbol{\theta})=0$ if and only if $x=x^{\ast}$.

**Definition 2 (Fuzzy-ESS)** If $x^{\ast}$ is a robust $\alpha$-FNE and satisfies the local evolutionary stability condition under the $\alpha$-cut defuzzified payoff, then $x^{\ast}$ is called a Fuzzy Evolutionarily Stable Strategy in the interval type-2 fuzzy game, abbreviated as Fuzzy-ESS.

**Theorem 3 (Local evolutionary stability of $\alpha$-FNE)** If $x^{\ast}\in\mathrm{int}(\Delta^4)$ is a robust $\alpha$-FNE, and there exists a constant $c_J>0$ such that the symmetric part of the defuzzified payoff Jacobian $J(x^{\ast})=\partial U/\partial x|_{x^{\ast}}$ is negative definite on the tangent space $\mathcal{T}$, i.e.,

$$
\delta x^T\frac{J(x^{\ast})+J(x^{\ast})^T}{2}\delta x
\le
-c_J\|\delta x\|^2,
\quad
\forall\delta x\in\mathcal{T}\setminus\{0\}
\tag{4-25}
$$

then $x^{\ast}$ is a locally asymptotically stable point of the replicator dynamics (4-22), and constitutes a Fuzzy-ESS. The proof is given in Appendix D.

### 4.4.3 Slow-Time-Scale Dynamics of On-Chain Governance

For the discrete on-chain governance-weight update mechanism defined in (3-7), when the projection is inactive, its component-wise form is

$$
\omega_{\ell}(h+1)-\omega_{\ell}(h)
=
\varepsilon_g[\sigma_{\ell}(\Delta_{\ell}(x,\boldsymbol{\omega}))-
\omega_{\ell}(h)],
\quad
\ell=1,\ldots,K
\tag{4-26}
$$

where $\boldsymbol{\Delta}(x,\boldsymbol{\omega})$ is the rule performance gain derived from system performance indicators, and explicitly depends on the population strategy state $x$ and governance weight $\boldsymbol{\omega}$ as described in Chapter 3. On the fast time scale, its continuous approximation is

$$
\dot{\omega}_{\ell}
=
\varepsilon_g g_{\ell}(x,\boldsymbol{\omega}),
\quad
g_{\ell}(x,\boldsymbol{\omega})
=
\sigma_{\ell}(\Delta_{\ell}(x,\boldsymbol{\omega}))-
\omega_{\ell}
\tag{4-27}
$$

Equivalently, under the slow time $\tau=\varepsilon_g t$,

$$
\frac{d\omega_{\ell}}{d\tau}
=
g_{\ell}(x,\boldsymbol{\omega})
\tag{4-28}
$$

Because $\boldsymbol{\sigma}$ is bounded and Lipschitz, and $\boldsymbol{\Delta}$ depends continuously on $(x,\boldsymbol{\omega})$, $g_{\ell}(x,\boldsymbol{\omega})$ is Lipschitz continuous with respect to $(x,\boldsymbol{\omega})$. The correction term generated by projection on the boundary can be treated as a feasibility-preserving term, and does not affect the boundedness of governance weights.

### 4.4.4 Two-Time-Scale System and Stability

Combining (4-22) and (4-27), the two-time-scale dynamical system under blockchain governance is

$$
\dot{x}_j
=
x_j[U_j(x,\boldsymbol{\theta})-
\overline{U}(x,\boldsymbol{\theta})],
\quad
j\in\mathcal{S}
\tag{4-29}
$$

$$
\dot{\omega}_{\ell}
=
\varepsilon_g g_{\ell}(x,\boldsymbol{\omega}),
\quad
\ell=1,\ldots,K
\tag{4-30}
$$

where $\boldsymbol{\theta}=P_{\mathrm{pay}}\boldsymbol{\omega}$. The following assumptions are made for stability analysis.

**A1 (Boundedness and continuity of payoffs)** For any $(x,\boldsymbol{\omega})\in\Delta^4\times\Delta^K$, $U_j(x,P_{\mathrm{pay}}\boldsymbol{\omega})$ is bounded and continuously differentiable.

**A2 (Fast-time-scale stability under fixed weights)** When $\boldsymbol{\omega}$ is fixed, the fast subsystem (4-29) has a robust $\alpha$-FNE/Fuzzy-ESS $x^{\ast}(\boldsymbol{\omega})$, and $x^{\ast}(\boldsymbol{\omega})$ is continuously differentiable with respect to $\boldsymbol{\omega}$. There exist a Lyapunov function $V_x(x;P_{\mathrm{pay}}\boldsymbol{\omega})$ and a constant $c_x>0$ such that the directional derivative of $V_x$ along the fast subsystem is uniformly negative definite with respect to the deviation $\|x-x^{\ast}(\boldsymbol{\omega})\|^2$ (see Appendix E, Eq. (E-4) for the explicit inequality).

**A3 (Lipschitz continuity and feasibility of governance updates)** $g_{\ell}(x,\boldsymbol{\omega})$ is Lipschitz continuous with respect to $(x,\boldsymbol{\omega})$, and the governance update keeps $\boldsymbol{\omega}\in\Delta^K$.

**A4 (Slow-time-scale condition)** The governance step size satisfies $0<\varepsilon_g\ll1$.

**A5 (Descent property of the governance potential function)** There exist a continuously differentiable potential function $\Phi:\Delta^K\to\mathbb{R}_{\ge0}$, a constant $c_{\omega}>0$, and a stable governance state $\boldsymbol{\omega}^{\ast}$ such that $\Phi(\boldsymbol{\omega}^{\ast})=0$, and along the reduced slow system $\dot{\boldsymbol{\omega}}=g(x^{\ast}(\boldsymbol{\omega}),\boldsymbol{\omega})$, the directional derivative of $\Phi$ is bounded by $-c_{\omega}\|g\|^2$ (see Appendix E, Eq. (E-5) for the explicit inequality). When the quadratic condition $(\boldsymbol{\omega}-\boldsymbol{\omega}^{\ast})^Tg(x^{\ast}(\boldsymbol{\omega}),\boldsymbol{\omega})\le -c\|\boldsymbol{\omega}-\boldsymbol{\omega}^{\ast}\|^2$ holds, $\Phi(\boldsymbol{\omega})=\frac{1}{2}\|\boldsymbol{\omega}-\boldsymbol{\omega}^{\ast}\|^2$ can be chosen.

Construct the joint Lyapunov potential function

$$
V(x,\boldsymbol{\omega})
=
V_x(x;P_{\mathrm{pay}}\boldsymbol{\omega})
+c_{\Phi}\Phi(\boldsymbol{\omega}),
\quad
c_{\Phi}>0
\tag{4-31}
$$

**Theorem 4 (Two-time-scale stability of blockchain governance and replicator dynamics)** If Assumptions A1-A5 hold, then the system defined by (4-29) and (4-30) forms a two-time-scale dynamical system, and:

(i) when $\varepsilon_g\to0$, the fast-time-scale replicator dynamics converge to the robust $\alpha$-FNE/Fuzzy-ESS equilibrium set $x^{\ast}(\boldsymbol{\omega})$ under the quasi-static governance weight $\boldsymbol{\omega}$;

(ii) the slow-time-scale governance dynamics adjust rule weights along $g(x,\boldsymbol{\omega})$, and converge to a stable governance state $(x^{\ast},\boldsymbol{\omega}^{\ast})$ satisfying

$$
g(x^{\ast}(\boldsymbol{\omega}^{\ast}),\boldsymbol{\omega}^{\ast})=0
\tag{4-32}
$$

(iii) for sufficiently small but finite $\varepsilon_g$, the system trajectory converges to an $O(\varepsilon_g)$ neighborhood of

$$
\{(x^{\ast}(\boldsymbol{\omega}),\boldsymbol{\omega})\mid
g(x^{\ast}(\boldsymbol{\omega}),\boldsymbol{\omega})=0\}
\tag{4-33}
$$

The proof is given in Appendix E.

This result indicates that on-chain governance slowly modifies the payoff structure through small-step updates, bounded Lipschitz mappings, and simplex projection, while off-chain physical agents complete fast strategy evolution under quasi-static governance parameters. The separation of time scales jointly ensures system stability.
