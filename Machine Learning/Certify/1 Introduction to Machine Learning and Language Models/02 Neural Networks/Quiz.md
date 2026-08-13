Neural Networks & Deep Learning
Your initial ML model (logistic regression on code metrics) achieves 72% accuracy but struggles with complex patterns like: "Function acquires database lock in transaction A, then calls async operation that acquires lock in transaction B, causing potential deadlock.".


According to neural network principles, why might deep learning better capture code vulnerabilities than simple ML approaches?

Neural networks can learn relationships between distant parts of code (variable declarations, function calls, usage patterns).

Neural networks process code syntax faster than traditional parsing methods.

Neural networks require less training data than traditional ML approaches.

Neural networks provide more interpretable results for developers.
Correct Answer!
Neural networks learn complex, non-linear relationships across distant code elements (line 10 declaration → line 25 modification → line 40 race condition).

Your neural network shows these results: Training accuracy: 91%, Validation accuracy: 74%, Test accuracy: 69%. What does this pattern indicate?

The model is underfitting and needs more layers or parameters.

The model is overfitting to training data and may have memorized specific code patterns.

The validation set is too different from the training data.

This is normal performance degradation expected in production.
Correct Answer!
Large gap (91% → 74%) = classic overfitting. Model memorized training examples, not general patterns.

For a code review tool integrated into developer workflows, which constraint is most critical for adoption?

The model must achieve 95%+ accuracy before developers will trust it.

The model must provide near-instantaneous feedback (under 500ms) to fit into coding flow.

The model must work equally well across all programming languages.

The model must be interpretable enough to explain every decision.
Correct Answer!
Developers won't use slow tools regardless of accuracy. Real-time feedback is essential.

To address the overfitting problem, which approach aligns with neural network training best practices?

Collect more training data from the same codebases.

Increase model complexity to better fit the training data.

Apply regularization techniques (dropout, weight decay) and use early stopping based on validation performance.

Remove the validation set and train only on training data.
Correct Answer!
Regularization (dropout, weight decay) prevents overfitting. Early stopping halts training when validation performance degrades.

Your neural network successfully detects 85% of bugs but generates many false positives. For developer adoption, how should you prioritize improvements?

Focus solely on increasing recall to catch more bugs.

Balance precision improvements to reduce false alarms while maintaining reasonable recall.

Optimize for overall accuracy regardless of precision/recall trade-offs.

Prioritize model interpretability over prediction performance.
Correct Answer!
False positives frustrate developers. Balance precision (fewer false alarms) with recall (bug detection).