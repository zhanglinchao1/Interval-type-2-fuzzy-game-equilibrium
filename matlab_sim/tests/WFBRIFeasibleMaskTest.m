classdef WFBRIFeasibleMaskTest < matlab.unittest.TestCase
% WFBRIFEASIBLEMASKTEST feasible_mask 受限策略集机制的回归测试。
%   固化: (1) 缺省与全真掩码逐位一致; (2) 掩码外坐标恒为零且行归一;
%   (3) 非法掩码 (尺寸错误 / 空可行集) 报错。

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                root, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function fullMaskMatchesDefault(testCase)
            params = WFBRIFeasibleMaskTest.smallParams();

            [piDefault, histDefault] = sec4_3_1_wfbri_solve( ...
                params, 0.1, params.theta, 0.5, 0);
            paramsMask = params;
            paramsMask.feasible_mask = true(params.N, ...
                params.num_strategies);
            [piMask, histMask] = sec4_3_1_wfbri_solve( ...
                paramsMask, 0.1, params.theta, 0.5, 0);

            testCase.verifyEqual(piMask, piDefault);
            testCase.verifyEqual(histMask.residual, histDefault.residual);
            testCase.verifyEqual(histMask.eps_ne, histDefault.eps_ne);
        end

        function maskedEntriesStayZero(testCase)
            params = WFBRIFeasibleMaskTest.smallParams();
            mask = true(params.N, params.num_strategies);
            mask(1:5, [3 4]) = false;    % RSU 型: 仅 {SC,SP}
            mask(6:8, [2 4]) = false;    % 边缘型: 仅 {SC,DC}
            params.feasible_mask = mask;

            [piStar, hist] = sec4_3_1_wfbri_solve( ...
                params, 0.1, params.theta, 0.5, 0);

            testCase.verifyEqual(piStar(~mask), ...
                zeros(nnz(~mask), 1));
            testCase.verifyEqual(sum(piStar, 2), ...
                ones(params.N, 1), AbsTol=1e-12);
            testCase.verifyTrue(hist.converged);
            testCase.verifyTrue(isfinite(hist.eps_ne));
        end

        function rejectsBadMask(testCase)
            params = WFBRIFeasibleMaskTest.smallParams();

            params.feasible_mask = true(params.N, 3);
            testCase.verifyError(@() sec4_3_1_wfbri_solve( ...
                params, 0.1, params.theta, 0.5, 0), ...
                'sec4_3_1_wfbri_solve:badFeasibleMask');

            params.feasible_mask = true(params.N, ...
                params.num_strategies);
            params.feasible_mask(2, :) = false;
            testCase.verifyError(@() sec4_3_1_wfbri_solve( ...
                params, 0.1, params.theta, 0.5, 0), ...
                'sec4_3_1_wfbri_solve:emptyFeasibleSet');
        end
    end

    methods (Static)
        function params = smallParams()
            params = config_params();
            params.N = 20;
            params.rng_seed = 42;
            params.R_max = 300;
            params.eps_tol = 1e-4;
            params.fou_modulation = true;
        end
    end
end
