## Unit Tests for ML Code

Unit tests verify that individual components of your ML system work correctly in isolation. While models themselves are probabilistic and hard to unit test, the code surrounding models can and should be thoroughly tested.

Feature computation functions are prime candidates for unit tests. If you have a function that extracts features from raw data, test that it handles normal inputs correctly, handles edge cases gracefully, and produces expected outputs for known inputs. These tests catch bugs early and provide documentation of expected behavior.

For example, a feature that calculates days since last purchase should handle users with no purchase history, users with purchases today, and users with purchases years ago. Unit tests verify each case produces correct results. When someone modifies the feature code, tests catch regressions immediately.

Comprehensive unit tests follow best practices: they test normal cases, edge cases, error conditions, and boundary values. Each test is independent, has a descriptive name, and includes assertions with helpful failure messages.

Data preprocessing functions need testing. Functions that normalize data, handle missing values, or encode categories must work correctly. Test with typical data, edge cases (empty datasets, single values, extreme outliers), and invalid inputs. Ensure preprocessing does not crash and handles errors appropriately.

Model inference code requires testing separate from model weights. The code that loads a model, prepares inputs, runs inference, and post-processes outputs can be tested independently. Mock the actual model prediction with fixed outputs to test the surrounding infrastructure. This verifies that serving code works even if you do not have a trained model yet.

Validation functions that check data quality or model outputs need tests. If you have code that validates that predictions are in expected ranges or that input data meets schema requirements, test that it catches violations and allows valid data through. These gatekeepers are critical and must work reliably.

Utility functions for metrics, logging, or data manipulation should be tested. Any deterministic function can and should have unit tests. The more of your ML codebase covered by unit tests, the more confident you can be in changes. Aim for high test coverage on non-model code.

Testing ML training code is harder because training is stochastic and time-consuming. Focus on testing that training runs without crashing, produces a model file, and that the model can make predictions. Use tiny datasets and few epochs for fast test execution. Verify the training pipeline works end-to-end even if model quality is poor in tests.

Mock external dependencies like databases or APIs for faster, more reliable tests. Real external services make tests slow and flaky. Mocks let tests run quickly and reliably. Use mocks for testing integration points while using real dependencies for integration tests.


Integration Tests for ML Pipelines
Integration tests verify that components work together correctly. For ML systems, this means testing complete workflows from data ingestion through prediction serving.

End-to-end training tests validate the complete training pipeline. Start with raw data, run preprocessing, execute training, evaluate the model, and verify the trained model meets minimum quality thresholds. Use small datasets for speed but test all pipeline steps. This catches integration issues between components that unit tests miss.

Integration tests verify that all components work together correctly, catching issues like training-serving skew, model persistence problems, and pipeline orchestration errors that unit tests miss.

Feature engineering pipelines need integration testing. Test that features can be computed from raw data in both training and serving contexts. Verify that features match between contexts to catch training-serving skew. Run the same feature code on the same sample data in both environments and assert outputs match exactly.

Model serving integration tests verify that deployed models can handle real request patterns. Send realistic requests to a staging model server. Verify responses are correctly formatted, latency is acceptable, and error handling works. These tests catch issues with model loading, input processing, or response formatting.

Pipeline orchestration tests verify that workflow steps execute in the correct order with proper error handling. If your training pipeline has 10 steps, test that failure in step 5 stops execution and reports errors properly. Test that success in all steps completes successfully. Orchestration bugs cause silent failures that are hard to debug.

Data flow tests validate that data passes correctly between pipeline stages. Verify that preprocessing output matches training input expectations. Verify that training output matches evaluation input expectations. Schema mismatches between stages cause failures that integration tests should catch.

Resource management tests ensure pipelines do not exhaust memory, disk, or compute. Run pipelines with realistic data volumes on production-like infrastructure. Monitor resource usage and verify it stays within limits. Resource exhaustion in production is a common failure mode that integration tests can prevent.

Error recovery tests verify that pipelines handle failures gracefully. Simulate database failures, network issues, or corrupted data. Verify that pipelines detect failures, log appropriately, and either retry or fail cleanly. Graceful failure handling separates robust production systems from fragile ones.


Regression Testing for Models
Regression testing ensures that changes do not degrade existing functionality. For ML systems, this includes both code regressions and model quality regressions.

Model performance regression tests verify that new models maintain or improve quality. Maintain a test dataset that represents production data diversity. For every model candidate, evaluate on this dataset and compare to baseline performance. If new model performance drops below thresholds, fail the test. This prevents deploying worse models.

Regression tests act as quality gates in CI/CD pipelines, preventing deployment of models that degrade performance, latency, or fairness. They ensure that improvements in one area do not come at the cost of regressions in others.

Prediction consistency tests check that models produce stable predictions for important inputs. Maintain a set of critical test cases (common use cases, edge cases, compliance requirements). For every new model, verify predictions on these cases match expectations. If predictions change unexpectedly, investigate why before deployment.

Behavioral regression tests verify model behavior on specific scenarios. For a content moderation model, test that known hate speech is flagged and known benign content is not flagged. For a recommendation model, test that popular items are recommended to relevant users. These behavioral tests encode business requirements.

Performance regression tests ensure models do not become slower. Track inference latency, throughput, and resource usage for each model version. Flag models that are significantly slower than baseline even if accuracy improves. Performance matters in production and should not regress unknowingly.

Fairness regression tests verify models do not develop new biases. Test model predictions on protected groups (different genders, ages, races). Verify prediction distributions and accuracy are comparable across groups. New models should not increase disparities even if overall accuracy improves.

API contract regression tests ensure serving APIs maintain backwards compatibility. Test that existing clients can still call APIs successfully after updates. Verify request and response formats have not changed in breaking ways. API stability is critical for downstream systems relying on your model.

Infrastructure regression tests verify deployment infrastructure still works. Test that new models can be loaded, deployed, scaled, and monitored. Verify health checks, logs, and metrics still work. Infrastructure tests catch issues with model format changes or dependency updates.

Automated regression test suites run on every model candidate. Fail the CI pipeline if any regression test fails. This provides automated quality gates preventing degraded models from reaching production. Human review can override test failures when justified, but defaults should be conservative.

Golden datasets for regression testing require careful curation. Include diverse examples covering production use cases. Update periodically to reflect current data distributions. Version golden datasets so tests are reproducible. Treat test data with the same care as production models.

Summary
Automated evaluation frameworks for AI systems include unit tests for ML code components, integration tests for complete pipelines, and regression tests for model quality and behavior. Unit tests verify individual functions work correctly. Integration tests verify components work together. Regression tests ensure changes do not degrade existing functionality.

Comprehensive test coverage enables rapid iteration with confidence. Tests catch bugs early, document expected behavior, and provide safety nets for refactoring. Automated testing is essential for production ML systems operating at scale.

Key concepts to remember
Comprehensive Unit Tests - Cover feature computation, preprocessing, inference infrastructure, and validation logic with high coverage
End-to-End Integration Tests - Verify complete workflows from data ingestion through serving to catch integration issues
Quality Gates - Model regression tests prevent deploying models with degraded quality by comparing to baseline performance
Business Requirements - Behavioral regression tests encode business requirements as executable tests for critical scenarios
Automated Pipeline Gates - Automated test suites in CI pipelines fail deployments when tests fail