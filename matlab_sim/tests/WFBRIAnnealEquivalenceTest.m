classdef WFBRIAnnealEquivalenceTest < matlab.unittest.TestCase
% WFBRIANNEALEQUIVALENCETEST lambda_path 退火机制的回归与证书测试。
%   固化 stag.md 的回归保障: (1) 缺省行为与单段调用逐位一致;
%   (2) 深退火使事后 exploitability 证书变强; (3) 非法调度报错;
%   (4) Scenario-B regime 工作点的深退火固定点收敛到严格 NE 顶点。

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                root, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function defaultMatchesSingleStagePath(testCase)
            params = WFBRIAnnealEquivalenceTest.smallParams();

            [piDefault, histDefault] = sec4_3_1_wfbri_solve( ...
                params, 0.2, params.theta, 0.5, 20);
            paramsPath = params;
            paramsPath.lambda_path = params.lambda;
            [piPath, histPath] = sec4_3_1_wfbri_solve( ...
                paramsPath, 0.2, params.theta, 0.5, 20);

            testCase.verifyEqual(piPath, piDefault);
            testCase.verifyEqual(histPath.residual, histDefault.residual);
            testCase.verifyEqual(histPath.iterations, histDefault.iterations);
        end

        function deepAnnealingImprovesCertificate(testCase)
            params = WFBRIAnnealEquivalenceTest.smallParams();

            [~, histSingle] = sec4_3_1_wfbri_solve( ...
                params, 0.2, params.theta, 0.5, 40);
            paramsDeep = params;
            paramsDeep.lambda_path = [0.15, 0.002];
            [~, histDeep] = sec4_3_1_wfbri_solve( ...
                paramsDeep, 0.2, params.theta, 0.5, 40);

            testCase.verifyLessThan(histDeep.eps_ne, histSingle.eps_ne);
        end

        function rejectsNonpositiveLambdaPath(testCase)
            params = WFBRIAnnealEquivalenceTest.smallParams();
            params.lambda_path = [0.15, 0, 0.02];

            testCase.verifyError(@() sec4_3_1_wfbri_solve( ...
                params, 0.2, params.theta, 0.5, 20), ...
                'sec4_3_1_wfbri_solve:badLambdaPath');
        end

        function deepAnnealReachesStrictNEVertex(testCase)
            % v1 regime 工作点 (alpha=0.5, s=40): 纯 SP 是 nu 准则的严格 NE,
            % 深退火固定点应贴到该顶点 (SP 份额 -> 1)。
            params = WFBRIAnnealEquivalenceTest.smallParams();
            cfg = scenario_b_config('concentrated');
            paramsB = scenario_b_env(params, cfg.fou_scale);
            paramsB.shock_mode = cfg.shock_mode;
            paramsB.lambda_path = [0.15, 0.002];

            [piStar, hist] = sec4_3_1_wfbri_solve( ...
                paramsB, cfg.delta, params.theta, 0.5, 40);
            profile = mean(piStar, 1);

            testCase.verifyGreaterThan(profile(2), 0.99);
            testCase.verifyLessThan(hist.eps_ne, 1e-4);
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
