Quiz: ML Fundamentals & Lifecycle
ML Fundamentals & Lifecycle
Your engineering team relies on static analysis tools for code quality, but they miss 65% of bugs that later cause production incidents. You have 18 months of Git history with:

50,000 code commits across various services (backend APIs, data pipelines, microservices)
Bug reports filed 1-3 weeks after commits (only 4% of commits have associated bugs)
Code metrics: complexity, file size, number of changes, dependencies
Manual code review feedback and approvals

According to ML fundamentals, what makes this a good candidate for machine learning over expanding static analysis rules?

ML will process code faster than rule-based static analysis tools.

ML models are easier to maintain than updating linting configurations.

Bug patterns evolve with new frameworks and coding practices faster than rules can be manually updated.

ML provides better error messages than traditional linting tools.
Correct Answer!
Bug patterns evolve constantly (new frameworks, APIs). Manual rules can't keep pace; ML learns automatically.

What type of machine learning problem is "predicting which code commits will have bugs discovered later"?

Supervised Classification (commits with later-discovered bugs vs clean commits).

Unsupervised Clustering (grouping similar code patterns).

Reinforcement Learning (learning from code review feedback over time).

Semi-supervised Learning (using partially labeled commit history).
Correct Answer!
You have labeled examples (buggy vs clean commits) and want to classify new commits.

Given that bugs are discovered 1-3 weeks after commits, how should you structure your data splits?

Random 70/15/15 split to ensure representative sampling.

Split by repository: some codebases for training, others for testing.

Time-based split with 3-week buffer: train on commits before week N-3, test on commits after week N.

Split by developer: some programmers' commits for training, others for testing.
Correct Answer!
3-week buffer prevents seeing future bug labels that wouldn't be known in production.

Your initial model achieves 78% accuracy on validation data. The team wants to deploy immediately because "it performs better than random guessing." What is the critical missing information?

78% accuracy is too low for any production code analysis system.

You need to understand the baseline bug detection rate of current tools and the cost of false positives vs false negatives.

The model needs to achieve at least 90% accuracy before production deployment.

Accuracy doesn't matter if the model can explain its decisions.
Correct Answer!
If current tools catch 75%, then 78% is minimal improvement. Need business context and cost analysis.

During model development, you discover your validation accuracy is 78% but drops to 65% when tested on a completely different codebase. This indicates:

The model is underfitting and needs more complexity.

65% accuracy is still acceptable for production deployment.

The model has overfit to specific coding styles and patterns in the training data.

The test codebase has fundamentally different types of bugs.
Correct Answer!
Performance drop on new codebases = learned specific patterns, not general bug indicators.

SkillUp | Hackerrank