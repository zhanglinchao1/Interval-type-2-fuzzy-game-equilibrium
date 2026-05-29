function br = sec4_3_1_softmax_br(nu_i, lambda)
%SEC4_3_1_SOFTMAX_BR 论文 §4.3.1 公式 (4-20) 熵正则化软最好响应
%     BR_{i,λ}(π)_j = exp(ν_{i,j}/λ) / Σ_h exp(ν_{i,h}/λ)
%
%   输入:
%       nu_i   - num_s×1 向量，纯策略收益
%       lambda - 标量，熵正则系数
%   输出:
%       br     - num_s×1 向量，软最好响应概率分布

    nu_shifted = nu_i - max(nu_i);
    exp_nu = exp(nu_shifted / lambda);
    br = exp_nu / sum(exp_nu);
end
