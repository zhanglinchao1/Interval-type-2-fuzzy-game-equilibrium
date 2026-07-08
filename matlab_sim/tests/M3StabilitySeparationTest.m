classdef M3StabilitySeparationTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                root, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function logitFixedPointIsNotReplicatorRestPoint(testCase)
            params = config_params();
            params.N = 5;
            params.R_max = 200;
            [piStar, history] = sec4_3_1_wfbri_solve( ...
                params, params.delta, params.theta);
            [~, ~, pureHat] = sec4_1_2_pure_interval_payoff_matrix( ...
                piStar, params.delta, params.theta, params);

            p = piStar(1, :);
            payoff = pureHat(1, :);
            replicatorField = p .* (payoff - p * payoff');

            testCase.verifyTrue(history.converged);
            testCase.verifyGreaterThan(min(p), 0);
            testCase.verifyGreaterThan(max(payoff) - min(payoff), 1e-3);
            testCase.verifyGreaterThan(norm(replicatorField, 1), 1e-4);
        end
    end
end
