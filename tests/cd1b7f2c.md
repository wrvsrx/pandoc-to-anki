---
title: projective dynamic
tags: [inbox, simulation]
---

\newcommand{\dt}{\Delta t}

::: {.remark}
隐式积分 $x_{n + 1} = x_{n} + v_{n + 1} \dt$ 在匀加速时产生的误差

假设加速度为常量 $a$, 那么 $x_{n} = x_{0} + v_{0} \dt n + \frac{n (n + 1)}{2} a \dt^{2} n^2$. 跟匀加速相比相差 $\frac{n }{2} a \dt^{2} n^2 = \frac{1}{2} a \dt T$, 是个跟时间和时间步成正比的误差.
:::
