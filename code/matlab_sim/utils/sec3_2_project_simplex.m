function x = sec3_2_project_simplex(v)
%SEC3_2_PROJECT_SIMPLEX 论文 §3.2 公式 (3-7) 中的单纯形投影算子 Π
%   将向量投影到概率单纯形，确保输出满足 x≥0 且 Σx_i=1
%
%   输入:
%       v - K×1 向量
%   输出:
%       x - K×1 向量，在单纯形上的投影

    x = max(v, 0);
    s = sum(x);
    if s > 0
        x = x / s;
    else
        x = ones(size(v)) / length(v);
    end
end
