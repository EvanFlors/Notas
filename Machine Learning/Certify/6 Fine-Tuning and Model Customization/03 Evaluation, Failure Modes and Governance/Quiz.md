## Quiz: Evaluation, Failure Modes and Governance

Evaluation, Failure Modes and Governance
You have fine-tuned a model for customer support and deployed it to production. After deployment, you receive reports that the model performs worse on general tasks, shows bias in outputs, and evaluation metrics don't match production performance.


During evaluation, you observe that training accuracy is 95% but validation accuracy is 78%. What does this indicate?

The model is learning well

The model is underfitting

The model is overfitting - it memorizes training data but doesn't generalize

The validation set is too small
Correct Answer!
A large gap (17 percentage points) between training and validation accuracy indicates overfitting. The model memorizes training data but fails to generalize.

After fine-tuning, you test the model on general tasks and find it performs 20% worse than the base model. What is this called?

Overfitting

Catastrophic forgetting - the model lost general capabilities

Underfitting

Normal fine-tuning behavior
Correct Answer!
Catastrophic forgetting occurs when fine-tuning causes models to lose previously learned general capabilities, making them perform worse on tasks they handled before.

When is LLM-as-Judge most appropriate for evaluation?

For all evaluation tasks

For complex tasks where traditional metrics are insufficient, like generation quality

Only when human evaluation is unavailable

Never - traditional metrics are always better
Correct Answer!
LLM-as-Judge is most appropriate for complex tasks like generation, reasoning, and open-ended Q&A where traditional metrics don't capture quality well.

How should you evaluate bias in a fine-tuned model?

Only check overall accuracy

Evaluate performance and outputs across different demographic groups and scenarios

Only check if the model is toxic

Bias evaluation is not necessary
Correct Answer!
Bias evaluation requires testing model performance and outputs across different groups, topics, and scenarios to identify unfair treatment or stereotyping.

What should a comprehensive model card include?

Only model performance metrics

Model details, intended use, performance, training data, ethical considerations, and limitations

Only the model architecture

Only deployment information
Correct Answer!
Comprehensive model cards document model characteristics, intended use, performance metrics, training data, ethical considerations (bias, safety), and limitations to enable appropriate use.