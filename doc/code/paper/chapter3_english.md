# Chapter 3 System Model and State Inputs

This chapter establishes the system model for blockchain-governed collaborative communication among physical agents, and defines the state inputs required for the interval type-2 fuzzy payoff game. First, the collaborative communication architecture, agent set, and strategy space of off-chain physical agents are presented. Second, the evidence anchoring, reputation updating, rule-weight adjustment, and payoff-layer weight projection mechanisms in the blockchain governance layer are defined. Finally, the membership degrees of trusted interaction, communication timeliness, and resource feasibility, together with their interval type-2 extensions, are constructed. These definitions form $(\mathcal{N},\mathcal{S},\pi)$, $\boldsymbol{\omega}(h)$, $\boldsymbol{\theta}(h)$, and $\widetilde{\mathbf{z}}_i(t)$, which provide the input basis for fuzzy payoff modeling and equilibrium analysis in Chapter 4.

## 3.1 System Architecture and Agent Model

This paper considers a blockchain-governed collaborative communication system among physical agents, and uses the Internet of Vehicles as a representative scenario for modeling. As shown in Fig. 3-1, the overall system architecture consists of an off-chain physical-agent layer, a state observation layer, a blockchain governance layer, and a fuzzy game analysis layer. The off-chain physical-agent layer consists of vehicle-type physical agents, roadside units, and edge servers, and is responsible for interaction behaviors such as perception information sharing, task coordination, communication and computing resource opening, and local resource reservation. The state observation layer extracts the membership degrees of trusted interaction, communication timeliness, and resource feasibility from off-chain interaction behavior, communication link states, and resource states. The blockchain governance layer anchors interaction evidence and updates reputation states and rule weights on a slow time scale. The fuzzy game analysis layer receives interval type-2 state membership degrees, payoff-layer weights, and strategy sets as inputs for interval type-2 fuzzy payoff game modeling and equilibrium analysis.

![Fig. 3-1](figures/chapter3/fig3-1.png)

**Fig. 3-1. Overall architecture of blockchain-governed fuzzy games among physical agents in the Internet of Vehicles**

Let the set of system agents be

$$
\mathcal{N}=\mathcal{V}\cup\mathcal{R}\cup\mathcal{E},
\tag{3-1}
$$

where $\mathcal{V}$ denotes the set of vehicle-type physical agents, $\mathcal{R}$ denotes the set of roadside units, and $\mathcal{E}$ denotes the set of edge servers.

For any agent $i\in\mathcal{N}$, its collaborative behavior consists of two dimensions: data behavior and resource behavior. Data behavior includes sharing perception/task information $S$ and suppressing or refusing information sharing $D$. Resource behavior includes opening communication/computing resources for collaboration $C$ and reserving local resources $P$. The combined strategy set is therefore defined as

$$
\mathcal{S}=\{SC,SP,DC,DP\},
\tag{3-2}
$$

where $SC$ denotes sharing information and opening resources for collaboration, $SP$ denotes sharing information while reserving local resources, $DC$ denotes suppressing information sharing while opening resources, and $DP$ denotes suppressing information sharing and reserving local resources. For roadside units and edge servers with fixed service obligations, the feasible strategy space can be reduced to $\mathcal{S}_i\subseteq \mathcal{S}$ according to service constraints. To keep a unified representation, this paper uses a four-dimensional extended strategy vector to represent the mixed strategy of all agents:

$$
\pi_i=
[
\pi_{i,SC},
\pi_{i,SP},
\pi_{i,DC},
\pi_{i,DP}
]^T\in\Delta^4,
\quad
\sum_{j\in\mathcal{S}}\pi_{i,j}=1,
\quad
\pi_{i,j}=0,\ j\notin\mathcal{S}_i,
\tag{3-3}
$$

where $\pi_{i,j}\geq0$ denotes the probability that agent $i$ selects strategy $j$, and $\Delta^4$ denotes the probability simplex formed by the four combined strategies. Let $N=|\mathcal{N}|$. The population mixed-strategy profile is denoted by

$$
\pi=(\pi_i)_{i\in\mathcal{N}}.
\tag{3-4}
$$

The agent set, strategy set, and mixed strategies above form the basic strategy space of the interval type-2 fuzzy game in Chapter 4. Since strategic payoffs are also affected by trusted interaction, communication timeliness, resource feasibility, and on-chain governance rules, blockchain governance variables, payoff-layer weights, and state membership inputs need to be defined further.

## 3.2 Blockchain Governance Model

The blockchain governance layer serves as the slow-time-scale governance layer of the collaborative communication system among physical agents. It mainly performs three functions: evidence anchoring, reputation updating, and rule-weight adjustment. During off-chain interactions, physical agents generate event information such as strategy behavior, task execution results, communication quality, abnormality flags, and timestamps. The system uploads digests of event records to the blockchain, and obtains the necessary signatures from roadside units, edge servers, or neighboring agents, forming the traceable evidence set $\mathcal{H}_i(h)$ within governance cycle $h$. On-chain evidence supports reputation updating and rule adjustment, so that off-chain strategy interactions are constrained by an auditable governance mechanism.

Based on the on-chain evidence set, the governance contract updates the reputation state of agent $i$:

$$
R_i(h)
=
\sum_{m=1}^{M}
\varrho_m r_{i,m}(h),
\quad
\sum_{m=1}^{M}\varrho_m=1,
\tag{3-5}
$$

where $r_{i,m}(h)$ denotes the $m$-th type of reputation indicator computed from on-chain evidence, which may include cooperation frequency, data validity, task completion rate, abnormality penalty, and neighbor recommendation. The coefficient $\varrho_m$ is the corresponding reputation weight. The reputation state $R_i(h)$ further affects the trusted interaction membership degree $\mu_{\mathrm{trust},i}(t)$, and enters subsequent payoff modeling through state inputs.

In addition to reputation states, the blockchain governance layer maintains the rule-weight vector:

$$
\boldsymbol{\omega}(h)
=
[\omega_1(h),\omega_2(h),\ldots,\omega_K(h)]^T
\in\Delta^K,
\tag{3-6}
$$

where $\Delta^K$ denotes the $K$-dimensional probability simplex, and $\omega_\ell(h)$ denotes the weight of the $\ell$-th on-chain governance rule or contract parameter in governance cycle $h$. Let $\boldsymbol{\Delta}(h)$ denote the rule performance gain vector computed from the system performance indicators within governance cycle $h$. Since the system performance indicators are jointly determined by the population strategy state and the current governance weights, $\boldsymbol{\Delta}(h)$ is a function of the system state, and its explicit dependence will be given in the two-time-scale analysis in Chapter 4. To characterize the slow-time-scale adaptive process of on-chain rules, this paper abstracts the governance-weight update as

$$
\boldsymbol{\omega}(h+1)
=
\Pi_{\Delta^K}
\left[
(1-\varepsilon_g)\boldsymbol{\omega}(h)
+
\varepsilon_g\boldsymbol{\sigma}(\boldsymbol{\Delta}(h))
\right],
\tag{3-7}
$$

where $0<\varepsilon_g\ll1$ is the on-chain governance step size, $\boldsymbol{\sigma}(\cdot)$ is a bounded Lipschitz mapping, and $\Pi_{\Delta^K}[\cdot]$ denotes projection normalization onto the probability simplex $\Delta^K$. This update keeps the rule weights bounded and ensures small-step, slow-time-scale variation.

Since payoff aggregation only involves the three states of trusted interaction, communication timeliness, and resource feasibility, the on-chain governance weights need to be mapped to three-dimensional payoff-layer weights. Define a nonnegative projection matrix $P_{\mathrm{pay}}\in\mathbb{R}_{+}^{3\times K}$, and let

$$
\boldsymbol{\theta}(h)
=
P_{\mathrm{pay}}\boldsymbol{\omega}(h)
=
[\theta_{\mathrm{trust}}(h),\theta_{\mathrm{delay}}(h),\theta_{\mathrm{res}}(h)]^T
\in\Delta^3.
\tag{3-8}
$$

Here, $\boldsymbol{\theta}(h)$ denotes the payoff-layer weight vector, which regulates the payoff components corresponding to trusted interaction, communication timeliness, and resource feasibility. To ensure $\boldsymbol{\theta}(h)\in\Delta^3$, the projection matrix satisfies nonnegativity and normalization conditions, namely $P_{\mathrm{pay}}\geq0$ and $\mathbf{1}_3^T P_{\mathrm{pay}}=\mathbf{1}_K^T$. In Chapter 4, $\boldsymbol{\theta}(h)$ is abbreviated as $\boldsymbol{\theta}$ within a fixed governance cycle. The on-chain governance dynamics are still described by $\boldsymbol{\omega}(h)$, whereas payoff aggregation uses its three-dimensional projection $\boldsymbol{\theta}(h)$.

Therefore, the blockchain governance layer enters the subsequent model through three types of variables: the reputation state $R_i(h)$ affects the trusted interaction membership degree $\mu_{\mathrm{trust},i}(t)$; the on-chain governance weight $\boldsymbol{\omega}(h)$ describes slow-time-scale governance dynamics; and the payoff-layer weight $\boldsymbol{\theta}(h)$ regulates the interval type-2 fuzzy payoff aggregation structure. Off-chain strategies are updated rapidly in communication time slot $t$, while on-chain rules are updated slowly in governance cycle $h$. Together, they form the system basis for the two-time-scale stability analysis in Chapter 4.

## 3.3 State Membership Input Model

In the blockchain-governed collaborative communication system among physical agents, the strategic payoff of an agent is jointly determined by trusted interaction, communication timeliness, and resource feasibility. To uniformly describe the effects of heterogeneous states on strategic payoffs, this paper maps the three types of states into scalar membership inputs in the interval $[0,1]$:

$$
\mu_{\mathrm{trust},i}(t),\quad
\mu_{\mathrm{delay},i}(t),\quad
\mu_{\mathrm{res},i}(t).
\tag{3-9}
$$

Here, $\mu_{\mathrm{trust},i}(t)$ denotes the trustworthiness degree of agent $i$ in the current interaction. The term $\mu_{\mathrm{delay},i}(t)$ denotes the communication timeliness satisfaction degree, which takes a higher value when delay, jitter, and packet loss are lower. The term $\mu_{\mathrm{res},i}(t)$ denotes the feasibility support provided by the current resource state for the collaborative task.

### 3.3.1 Trusted Interaction Membership Degree

The trusted interaction membership degree describes whether an agent is suitable for participating in perception information sharing, task coordination, and resource opening in the current time slot. This membership degree is jointly determined by the on-chain reputation state and the off-chain interaction context. The trusted interaction membership degree of agent $i$ is defined as

$$
\mu_{\mathrm{trust},i}(t)
=
\mathcal{F}_{\mathrm{trust}}
\left(
R_i(h),
\mathbf{c}^{\mathrm{trust}}_i(t)
\right),
\quad
t\in\mathcal{T}_h,
\tag{3-10}
$$

where $R_i(h)$ denotes the reputation state maintained by the blockchain governance layer, $\mathbf{c}^{\mathrm{trust}}_i(t)$ denotes the off-chain trusted interaction context variables, which may include neighbor feedback, recent abnormal events, historical collaborative behavior, task completion status, and data validity, and $\mathcal{T}_h$ denotes the set of off-chain communication time slots covered by the $h$-th governance cycle. The mapping function $\mathcal{F}_{\mathrm{trust}}(\cdot)$ converts the on-chain reputation and off-chain context into the trusted interaction membership degree, as shown in Fig. 3-2.

<img src="figures/chapter3/fig3-2.png" alt="3-2" style="zoom:25%;" />

**Fig. 3-2. Interval type-2 membership function for trusted interaction**

Therefore, $\mu_{\mathrm{trust},i}(t)$ is jointly determined by the auditable on-chain reputation state and the real-time off-chain context, and is used to characterize the trustworthiness of an agent for information sharing and resource collaboration. A value closer to 1 indicates that the agent is more suitable for information sharing and collaborative resource opening, while a value closer to 0 indicates a higher risk of untrustworthiness, abnormal behavior, or contract violation.

### 3.3.2 Communication Timeliness Membership Degree

The communication timeliness membership degree describes how well the current communication state satisfies the timeliness requirements of collaborative tasks. In collaborative communication among physical agents in the Internet of Vehicles, perception sharing, task coordination, and edge computing offloading are usually affected by end-to-end delay, jitter, packet loss rate, and link congestion. The communication timeliness membership degree of agent $i$ is defined as

$$
\mu_{\mathrm{delay},i}(t)
=
\mathcal{F}_{\mathrm{delay}}
\left(
d_i(t),
J_i(t),
p_i^{\mathrm{loss}}(t),
\chi_i(t)
\right),
\tag{3-11}
$$

where $d_i(t)$ denotes the end-to-end delay or round-trip delay, $J_i(t)$ denotes delay jitter, $p_i^{\mathrm{loss}}(t)$ denotes the packet loss rate, and $\chi_i(t)$ denotes the link congestion state. The mapping function $\mathcal{F}_{\mathrm{delay}}(\cdot)$ converts these communication observations into a timeliness satisfaction degree, as shown in Fig. 3-3.

<img src="figures/chapter3/fig3-3.png" alt="3-3" style="zoom:25%;" />

**Fig. 3-3. Multidimensional membership aggregation for communication timeliness**

When delay, jitter, packet loss rate, and congestion are at low levels, $\mu_{\mathrm{delay},i}(t)$ takes a high value, indicating that the current communication state can satisfy the timeliness requirements of the collaborative task. When link quality degrades or congestion intensifies, $\mu_{\mathrm{delay},i}(t)$ decreases, indicating uncertainty in the payoff of the agent participating in real-time collaboration.

### 3.3.3 Resource Feasibility Membership Degree

The resource feasibility membership degree describes the support capability of the current computing, communication, and energy resources of an agent for collaborative tasks. The resource state of a vehicle-type physical agent is usually affected by CPU load, wireless bandwidth, residual energy, and instantaneous power consumption. For roadside units and edge servers, resource feasibility is mainly reflected in computing load, bandwidth occupation, and service queue pressure.

<img src="figures/chapter3/fig3-4.png" alt="3-4" style="zoom:25%;" />

**Fig. 3-4. Choquet-OWA aggregation for resource feasibility**

This paper adopts the existing prediction-enhanced two-stage T-norm-Choquet-OWA resource aggregator as the computation interface for the resource feasibility membership degree [9]. This section uses its output $\mu_{\mathrm{res},i}(t)$ as the resource feasibility input.

Let the normalized resource state vector of agent $i$ in time slot $t$ be

$$
\mathbf{s}^{\mathrm{res}}_i(t)
=
[
c_i(t), b_i(t), E_i(t), p_i(t),
F_i^c(t), F_i^b(t), F_i^E(t), \eta_i(t)
],
\tag{3-12}
$$

where the components denote computing load, bandwidth occupation, energy state, power-consumption load, their short-term predictions, and the task elasticity factor, respectively. The preceding resource aggregation mapping is denoted by

$$
\mu_{\mathrm{res},i}(t)
=
\mathcal{A}_{\mathrm{res}}
\left(
\mathbf{s}^{\mathrm{res}}_i(t)
\right),
\tag{3-13}
$$

where $\mathcal{A}_{\mathrm{res}}(\cdot)$ denotes the prediction-enhanced two-stage T-norm-Choquet-OWA resource aggregation mapping, and $\mu_{\mathrm{res},i}(t)\in[0,1]$ denotes the feasibility support of the current resource state of the agent for collaborative task execution. A higher value indicates that the resource state is more suitable for communication, computing, or collaborative tasks, whereas a lower value indicates a more evident resource bottleneck or power-consumption pressure.

### 3.3.4 Interval Type-2 State Membership Inputs

The three scalar membership degrees above describe the nominal state evaluation of a physical agent in a given time slot. To characterize the second-order uncertainty caused by observation noise, prediction bias, and fuzzy rule boundaries, this paper further elevates each scalar membership degree to an interval type-2 fuzzy membership degree. For any state category $k\in\{\mathrm{trust},\mathrm{delay},\mathrm{res}\}$, define

$$
\underline{\mu}_{k,i}(t)
=
\max\{0,\mu_{k,i}(t)-\delta_{k,i}(t)\},
\quad
\overline{\mu}_{k,i}(t)
=
\min\{1,\mu_{k,i}(t)+\delta_{k,i}(t)\},
\tag{3-14}
$$

where $\delta_{k,i}(t)\in[0,1]$ denotes the uncertainty half-bandwidth of the membership degree, which can be given by observation-noise variance, prediction residuals, or expert priors. The interval type-2 state membership degree is then obtained as

$$
\widetilde{\mu}_{k,i}(t)
=
[\underline{\mu}_{k,i}(t),\overline{\mu}_{k,i}(t)]\subseteq[0,1].
\tag{3-15}
$$

The footprint of uncertainty formed between the lower and upper membership functions is defined as

$$
\mathrm{FOU}(\widetilde{\mu}_{k,i})
=
\{(t,u)\mid t\in\mathcal{T},\ u\in[\underline{\mu}_{k,i}(t),\overline{\mu}_{k,i}(t)]\}.
\tag{3-16}
$$

Here, $\mathcal{T}$ denotes the system observation time domain. When $\delta_{k,i}(t)=0$, the lower and upper membership functions coincide, and the interval type-2 membership degree degenerates into a type-1 membership degree. When $\delta_{k,i}(t)>0$, the footprint of uncertainty between the lower and upper bounds characterizes the uncertainty of the membership degree itself.

Combining the above definitions, the interval type-2 state membership vector of agent $i$ in time slot $t$ is defined as

$$
\widetilde{\mathbf{z}}_i(t)
=
\left\{
[\underline{\mu}_{k,i}(t),\overline{\mu}_{k,i}(t)]
\right\}_{k\in\{\mathrm{trust},\mathrm{delay},\mathrm{res}\}}.
\tag{3-17}
$$

Here, $\widetilde{\mathbf{z}}_i(t)$ denotes the interval type-2 state input considering second-order uncertainty. Based on $\widetilde{\mathbf{z}}_i(t)$, Chapter 4 constructs the strategy-profile-induced interval type-2 state membership degrees and interval type-2 fuzzy payoffs.

## 3.4 Summary

This chapter defines the agent set, strategy space, on-chain governance weights, payoff-layer weights, and state membership inputs of the blockchain-governed collaborative communication system among physical agents. The resulting $(\mathcal{N},\mathcal{S},\pi)$, $\boldsymbol{\omega}(h)$, $\boldsymbol{\theta}(h)$, and $\widetilde{\mathbf{z}}_i(t)$ serve as the basis for interval type-2 fuzzy payoff game modeling and equilibrium analysis in Chapter 4.
