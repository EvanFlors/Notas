## Quiz: CI/CD for Evaluation of AI Systems

CI/CD for Evaluation of AI Systems
Your team is building a CI/CD pipeline for a recommendation model. The model takes 6 hours to train, and you have 5 data scientists making code changes daily. You need to balance rapid iteration with thorough testing while managing resource costs.


Data scientists are pushing code changes 10 times per day. Full model training takes 6 hours and costs $50. How should you configure training pipeline triggers?

Trigger full training on every code commit for immediate feedback.

Never automate training; always trigger manually.

Schedule training nightly and trigger only for specific changes.

Train only when model evaluation metrics degrade.
Correct Answer!
Scheduled training (e.g., nightly) with manual triggers for model changes balances cost with feedback speed. Test code changes with existing models.

Your regression test suite includes 50 critical test cases. A new model passes 48 out of 50 but has 2% higher overall accuracy than the current model. What should you do?

Deploy the new model because overall accuracy improved.

Investigate the 2 failed cases before making a deployment decision.

Lower the regression test pass threshold to 48 out of 50.

Skip regression tests since overall metrics improved.
Correct Answer!
Failed regression tests might indicate serious issues on important cases. Higher overall accuracy does not justify deploying models that fail critical behavioral tests.

Training pipeline occasionally fails due to corrupt data. Failures waste 6 hours and $50 per run. Where should you add data validation?

At the start of training pipeline before expensive operations.

After training completes, validate the trained model.

Only in production serving to catch runtime issues.

Data validation is not necessary if data sources are reliable.
Correct Answer!
Data validation should be the first pipeline step to fail fast on bad data before wasting time and money on training.

Your team has never tested the rollback procedure for model deployments. During an incident, you need to rollback but the procedure fails. What practice would have prevented this?

More comprehensive pre-deployment testing.

Canary deployments with automated rollback.

Slower, more gradual deployments.

Regular rollback drills in staging environments.
Correct Answer!
Regularly practicing rollback in staging ensures procedures work when needed. Untested rollback procedures often fail during actual incidents.

Models pass all tests in development but fail in production due to different feature computation. What principle was violated?

Insufficient unit test coverage.

Inadequate load testing in staging.

Environment parity - feature computation differs between environments.

Missing integration tests.
Correct Answer!
Training-serving skew from different feature implementations is a classic environment parity violation. Use the same code in all environments.