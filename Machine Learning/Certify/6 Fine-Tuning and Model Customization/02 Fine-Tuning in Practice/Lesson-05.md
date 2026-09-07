## Training Dynamics and Debugging

Fine-tuning training does not always proceed smoothly. Your customer support chatbot may overfit, underfit, fail to converge, or exhibit unexpected behaviors during training. Understanding training dynamics and debugging techniques enables you to identify issues early, fix problems efficiently, and achieve successful fine-tuning outcomes.

Many teams train models without monitoring dynamics, leading to wasted compute on failed training runs or models that perform poorly in production. Learning to interpret loss curves, validation metrics, and training logs helps you catch issues before they become costly problems.

In this lesson, you will learn to monitor training dynamics for your chatbot, identify common training issues, implement debugging techniques, and fix problems to achieve successful fine-tuning.

Monitoring Training Dynamics
Effective monitoring enables you to detect issues early and make informed decisions about training adjustments.

Key Metrics to Monitor

Monitor multiple metrics during training to get a complete picture:

Training Loss: Should decrease steadily. Sudden spikes or plateaus indicate issues.
Validation Loss: Should track training loss. Divergence indicates overfitting.
Learning Rate: Should follow schedule. Monitor for optimal learning rate.
Gradient Norm: Should be stable. Exploding or vanishing gradients indicate problems.
Task-Specific Metrics: Accuracy, F1, BLEU, etc. Should improve over time.

```python
# Monitoring Training with HuggingFace Trainer
# Trainer automatically logs metrics - access them from training history

from transformers import TrainingArguments, Trainer

# Configure training with logging
training_args = TrainingArguments(
  output_dir="./chatbot_results",
  logging_dir="./chatbot_logs",  # TensorBoard logs directory
  logging_steps=10,  # Log every 10 steps
  eval_steps=100,  # Evaluate every 100 steps
  evaluation_strategy="steps",  # Evaluate during training
  save_steps=500,
  # ... other arguments
)

# Trainer automatically logs metrics
trainer = Trainer(
  model=model,
  args=training_args,
  train_dataset=train_dataset,
  eval_dataset=eval_dataset,
  tokenizer=tokenizer
)

# Start training - metrics are logged automatically
trainer.train()

# Access logged metrics after training
training_history = trainer.state.log_history

# Extract metrics for analysis
train_losses = [log["loss"] for log in training_history if "loss" in log and "eval_loss" not in log]
val_losses = [log["eval_loss"] for log in training_history if "eval_loss" in log]
learning_rates = [log["learning_rate"] for log in training_history if "learning_rate" in log]

print(f"Training completed:")
print(f"  Final train loss: {train_losses[-1]:.4f}")
print(f"  Final val loss: {val_losses[-1]:.4f}")
print(f"  Total steps: {len(train_losses)}")

# View TensorBoard logs: tensorboard --logdir=./chatbot_logs
```

Accessing Training Metrics

After training, you can access all logged metrics from the Trainer's state. This enables post-training analysis and debugging:

```python
# Accessing and Analyzing Training Metrics
# Extract metrics from Trainer's log history for analysis

# After training completes
training_history = trainer.state.log_history

# Extract different metric types
train_losses = [log["loss"] for log in training_history if "loss" in log and "eval_loss" not in log]
val_losses = [log["eval_loss"] for log in training_history if "eval_loss" in log]
learning_rates = [log["learning_rate"] for log in training_history if "learning_rate" in log]
gradient_norms = [log["grad_norm"] for log in training_history if "grad_norm" in log]

# Get metrics at specific steps
step_metrics = {log["step"]: log for log in training_history if "step" in log}

# Find best validation loss checkpoint
if val_losses:
  best_val_loss = min(val_losses)
  best_step = val_losses.index(best_val_loss) * trainer.args.eval_steps
  print(f"Best validation loss: {best_val_loss:.4f} at step {best_step}")

# Check for training issues
if len(train_losses) > 10 and len(val_losses) > 10:
  recent_train_trend = (train_losses[-1] - train_losses[-10]) / 10
  recent_val_trend = (val_losses[-1] - val_losses[-10]) / 10

  if recent_train_trend < -0.01 and recent_val_trend > 0.01:
      print("⚠️ Warning: Overfitting detected - validation loss increasing")
  elif train_losses[-1] > 0.5 and val_losses[-1] > 0.5:
      print("⚠️ Warning: Underfitting detected - both losses high")
```

Interpreting Loss Curves

Loss curves reveal training health by plotting loss values over training epochs (one epoch = one complete pass through the entire training dataset). Each curve shows two lines: blue for training loss (how well the model fits training data) and red for validation loss (how well it generalizes to unseen data). Understanding curve patterns helps identify issues before they become costly problems.

![Four loss curve patterns showing healthy training, overfitting, underfitting, and instability with training and validation loss plotted over epochs](https://hrcdn.net/ai-engineering/module-6/light/training_loss_curve_patterns.svg)

Loss curve patterns: identifying training issues
Healthy Training: Both lines decrease steadily and stay close together. The validation loss tracks the training loss closely, indicating the model learns generalizable patterns rather than memorizing training data. This is the ideal pattern - the model improves on both training and validation data.

Overfitting: Training loss decreases sharply while validation loss increases or plateaus after initial improvement. The gap between lines widens, showing the model memorizes training data but fails on new data. In the diagram above, notice how validation loss starts increasing around epoch 10 while training loss continues decreasing.

Underfitting: Both losses decrease slowly and plateau at high values. The model struggles on both training and validation data, indicating insufficient model capacity, poor data quality, or insufficient training. Neither line reaches low loss values.

Instability: Both lines show erratic fluctuations with large spikes and dips rather than smooth trends. Training is unstable, often caused by learning rates that are too high, gradient issues, or data problems. The curves do not follow predictable patterns.

Monitor both training and validation loss throughout training. When they diverge (validation increases while training decreases), you have overfitting. When both stay high, you have underfitting. When both are erratic, you have instability.

Analyzing Loss Curves

```python
# Analyzing Loss Curves for Customer Support Chatbot
# This demonstrates how to identify training issues from loss curves

import numpy as np

def analyze_chatbot_training_health(train_losses, val_losses, classification_accuracies):
  """Analyze training health for chatbot from loss curves and metrics"""

  analysis = {
      "status": "unknown",
      "issues": [],
      "recommendations": []
  }

  # Check for overfitting (common issue with chatbots)
  if len(val_losses) > 10:
      recent_train = train_losses[-10:]
      recent_val = val_losses[-10:]

      train_trend = (recent_train[-1] - recent_train[0]) / len(recent_train)
      val_trend = (recent_val[-1] - recent_val[0]) / len(recent_val)

      if train_trend < -0.01 and val_trend > 0.01:  # Train decreasing, val increasing
          analysis["status"] = "overfitting"
          analysis["issues"].append("Validation loss increasing while training loss decreasing - model memorizing training data")
          analysis["recommendations"].append("Increase LoRA dropout to 0.15, reduce rank to r=12, or add more diverse training data")

  # Check for underfitting
  if train_losses[-1] > 0.5 and val_losses[-1] > 0.5:  # High loss values
      if analysis["status"] == "unknown":
          analysis["status"] = "underfitting"
      analysis["issues"].append("Both training and validation loss are high - model not learning")
      analysis["recommendations"].append("Increase LoRA rank to r=32, train longer, or improve data quality")

  # Check classification accuracy trend
  if len(classification_accuracies) > 5:
      acc_trend = classification_accuracies[-1] - classification_accuracies[-5]
      if acc_trend < -0.02:  # Accuracy decreasing
          analysis["issues"].append("Classification accuracy decreasing - possible overfitting")
          analysis["recommendations"].append("Reduce learning rate or increase regularization")

  # Check for instability
  if len(train_losses) > 5:
      train_std = np.std(train_losses[-20:])
      if train_std > 0.1:  # High variance
          analysis["issues"].append("Training loss shows high variance - unstable training")
          analysis["recommendations"].append("Reduce learning rate from 2e-4 to 1e-4 or use gradient clipping")

  # Check for convergence
  if len(train_losses) > 20:
      recent_change = abs(train_losses[-1] - train_losses[-10]) / train_losses[-10]
      if recent_change < 0.01:  # Less than 1% change
          analysis["status"] = "converged"
          analysis["recommendations"].append("Training has converged. Consider early stopping or reducing learning rate")

  return analysis

# Example: Analyze chatbot training
health_analysis = analyze_chatbot_training_health(
  train_losses=[0.8, 0.6, 0.4, 0.3, 0.25, 0.22, 0.20, 0.18, 0.17, 0.16],
  val_losses=[0.75, 0.58, 0.42, 0.35, 0.32, 0.30, 0.31, 0.33, 0.35, 0.37],  # Increasing = overfitting
  classification_accuracies=[0.65, 0.72, 0.78, 0.82, 0.85, 0.87, 0.88, 0.87, 0.86, 0.85]
)

print(f"Training status: {health_analysis['status']}")
if health_analysis["issues"]:
  print("Issues detected:")
  for issue in health_analysis["issues"]:
      print(f"  - {issue}")
  print("Recommendations:")
  for rec in health_analysis["recommendations"]:
      print(f"  - {rec}")
```

Common Training Issues and Fixes
Understanding common issues and their fixes enables rapid problem resolution.

Overfitting

Overfitting occurs when models memorize training data but fail to generalize. Signs include decreasing training loss with increasing or plateauing validation loss.

Fixes:

Increase dropout rate
Reduce model capacity (lower LoRA rank)
Add data augmentation
Reduce training epochs
Increase regularization

```python
Fixing Overfitting
# Fixing Overfitting in Customer Support Chatbot
# Detect overfitting from metrics and automatically adjust configuration

def fix_chatbot_overfitting(base_config):
  """Adjust configuration to reduce overfitting in chatbot"""

  # Increase dropout (more regularization)
  fixed_config = base_config.copy()
  fixed_config["lora_dropout"] = min(0.2, base_config["lora_dropout"] * 1.5)

  # Reduce LoRA rank (lower capacity to prevent memorization)
  if "r" in base_config:
      fixed_config["r"] = max(8, base_config["r"] // 2)

  # Add weight decay
  fixed_config["weight_decay"] = 0.01

  # Reduce learning rate (slower learning = less overfitting)
  fixed_config["learning_rate"] = base_config["learning_rate"] * 0.5

  # Add early stopping
  fixed_config["early_stopping_patience"] = 3

  return fixed_config

# Simulate detecting overfitting from training metrics
train_losses = [0.8, 0.6, 0.4, 0.3, 0.25, 0.22, 0.20, 0.18, 0.17, 0.16]
val_losses = [0.75, 0.58, 0.42, 0.35, 0.32, 0.30, 0.31, 0.33, 0.35, 0.37]  # Increasing!

# Check if overfitting is occurring
recent_train_trend = (train_losses[-1] - train_losses[-5]) / 5
recent_val_trend = (val_losses[-1] - val_losses[-5]) / 5

print("Training Analysis:")
print(f"  Recent train loss trend: {recent_train_trend:.4f} (decreasing)")
print(f"  Recent val loss trend: {recent_val_trend:.4f} (increasing)")
print(f"  Gap: {val_losses[-1] - train_losses[-1]:.4f}")

if recent_train_trend < -0.01 and recent_val_trend > 0.01:
  print("\n⚠️ Overfitting detected! Applying fixes...")

  # Current configuration that's causing overfitting
  current_config = {
      "lora_dropout": 0.1,
      "r": 16,
      "learning_rate": 2e-4,
      "num_train_epochs": 5
  }

  # Apply fixes
  fixed_config = fix_chatbot_overfitting(current_config)

  print("\nConfiguration adjustments:")
  print(f"  Dropout: {current_config['lora_dropout']} → {fixed_config['lora_dropout']:.2f} (more regularization)")
  print(f"  Rank: {current_config['r']} → {fixed_config['r']} (lower capacity)")
  print(f"  Learning rate: {current_config['learning_rate']} → {fixed_config['learning_rate']} (slower learning)")
  print(f"  Weight decay: None → {fixed_config['weight_decay']} (added)")
  print(f"  Early stopping: None → patience={fixed_config['early_stopping_patience']} (added)")

  print("\n✅ Use this fixed configuration for your next training run to reduce overfitting.")
else:
  print("\n✓ Training appears healthy - no overfitting detected.")
```

Underfitting

Underfitting occurs when models are too simple or training is insufficient. Signs include high training and validation loss that decrease slowly.

Fixes:

Increase model capacity (higher LoRA rank)
Train for more epochs
Improve data quality
Increase learning rate
Reduce regularization

Fixing Underfitting

```python
# Fixing Underfitting
# Detect underfitting from metrics and automatically adjust configuration

def fix_underfitting_config(base_config):
  """Adjust configuration to reduce underfitting"""

  # Increase model capacity
  fixed_config = base_config.copy()
  if "r" in base_config:
      fixed_config["r"] = min(64, base_config["r"] * 2)

  # Increase learning rate
  fixed_config["learning_rate"] = base_config["learning_rate"] * 2

  # Reduce dropout
  fixed_config["lora_dropout"] = max(0.05, base_config["lora_dropout"] * 0.5)

  # Train longer
  fixed_config["num_epochs"] = base_config.get("num_epochs", 3) * 2

  return fixed_config

# Simulate detecting underfitting from training metrics
train_losses = [0.8, 0.75, 0.72, 0.70, 0.68, 0.67, 0.66, 0.65]  # High and barely decreasing
val_losses = [0.82, 0.78, 0.75, 0.73, 0.71, 0.70, 0.69, 0.68]  # High and barely decreasing

print("Training Analysis:")
print(f"  Final train loss: {train_losses[-1]:.4f}")
print(f"  Final val loss: {val_losses[-1]:.4f}")
print(f"  Loss improvement: {train_losses[0] - train_losses[-1]:.4f} over {len(train_losses)} epochs")

# Check if underfitting is occurring
if train_losses[-1] > 0.5 and val_losses[-1] > 0.5:
  print("\n⚠️ Underfitting detected! Both losses are high and decreasing slowly.")
  print("Applying fixes...")

  # Current configuration that's causing underfitting
  current_config = {
      "r": 8,
      "learning_rate": 1e-4,
      "lora_dropout": 0.2,
      "num_epochs": 3
  }

  # Apply fixes
  fixed_config = fix_underfitting_config(current_config)

  print("\nConfiguration adjustments:")
  print(f"  Rank: {current_config['r']} → {fixed_config['r']} (higher capacity)")
  print(f"  Learning rate: {current_config['learning_rate']} → {fixed_config['learning_rate']} (faster learning)")
  print(f"  Dropout: {current_config['lora_dropout']} → {fixed_config['lora_dropout']:.2f} (less regularization)")
  print(f"  Epochs: {current_config['num_epochs']} → {fixed_config['num_epochs']} (train longer)")

  print("\n✅ Use this fixed configuration for your next training run to improve learning.")
else:
  print("\n✓ Training appears healthy - no underfitting detected.")
```

Training Instability

Instability manifests as fluctuating loss, exploding gradients, or NaN values. Causes include learning rate too high, gradient clipping issues, or data problems.

Fixes:

Reduce learning rate
Add gradient clipping
Check data for corrupted examples
Use learning rate warmup
Normalize inputs

Fixing Training Instability

```python
# Fixing Training Instability
# Detect instability from loss variance and automatically adjust configuration

import numpy as np

def fix_instability_config(base_config):
  """Adjust configuration to stabilize training"""

  # Reduce learning rate
  fixed_config = base_config.copy()
  fixed_config["learning_rate"] = base_config["learning_rate"] * 0.1

  # Add gradient clipping
  fixed_config["max_grad_norm"] = 1.0

  # Add learning rate warmup
  fixed_config["warmup_steps"] = 100
  fixed_config["warmup_ratio"] = 0.1

  # Use gradient accumulation
  fixed_config["gradient_accumulation_steps"] = 4

  return fixed_config

# Simulate detecting instability from training metrics
train_losses = [0.5, 0.3, 0.6, 0.2, 0.7, 0.25, 0.65, 0.3, 0.55, 0.35]  # High variance

# Calculate variance to detect instability
loss_std = np.std(train_losses)
loss_mean = np.mean(train_losses)
coefficient_of_variation = loss_std / loss_mean

print("Training Analysis:")
print(f"  Loss mean: {loss_mean:.4f}")
print(f"  Loss std: {loss_std:.4f}")
print(f"  Coefficient of variation: {coefficient_of_variation:.4f}")
print(f"  Loss range: {min(train_losses):.4f} to {max(train_losses):.4f}")

# Check if instability is occurring
if loss_std > 0.1 or coefficient_of_variation > 0.3:
  print("\n⚠️ Training instability detected! Loss shows high variance.")
  print("Applying stability fixes...")

  # Current configuration that's causing instability
  current_config = {
      "learning_rate": 5e-3,  # Too high
      "max_grad_norm": None  # No clipping
  }

  # Apply fixes
  fixed_config = fix_instability_config(current_config)

  print("\nConfiguration adjustments:")
  print(f"  Learning rate: {current_config['learning_rate']} → {fixed_config['learning_rate']} (reduced 10x)")
  print(f"  Gradient clipping: None → {fixed_config['max_grad_norm']} (added)")
  print(f"  Warmup steps: None → {fixed_config['warmup_steps']} (added)")
  print(f"  Warmup ratio: None → {fixed_config['warmup_ratio']} (added)")
  print(f"  Gradient accumulation: None → {fixed_config['gradient_accumulation_steps']} steps (added)")

  print("\n✅ Use this fixed configuration for your next training run to stabilize training.")
else:
  print("\n✓ Training appears stable - no instability detected.")
```

Debugging Workflow
A systematic debugging workflow helps identify and fix issues efficiently.

Step 1: Identify Symptoms

Monitor metrics to identify symptoms: overfitting, underfitting, instability, or convergence issues.

Step 2: Diagnose Root Cause

Analyze loss curves, check data quality, review hyperparameters, and examine training logs to identify root causes.

Step 3: Apply Fixes

Apply targeted fixes based on diagnosis. Make one change at a time to isolate effects.

Step 4: Validate Fixes

Re-train with fixes and validate that issues are resolved. Monitor metrics to confirm improvements.

```python
# Systematic Debugging Workflow
# This demonstrates a practical approach to debugging training issues

from transformers import Trainer, TrainingArguments

# Step 1: Train with initial configuration and identify symptoms
print("Step 1: Training with initial configuration...")
initial_trainer = Trainer(
  model=model,
  args=initial_training_args,
  train_dataset=train_dataset,
  eval_dataset=eval_dataset,
  tokenizer=tokenizer
)
initial_trainer.train()

# Extract metrics to identify symptoms
initial_history = initial_trainer.state.log_history
train_losses = [log["loss"] for log in initial_history if "loss" in log and "eval_loss" not in log]
val_losses = [log["eval_loss"] for log in initial_history if "eval_loss" in log]

# Analyze symptoms (using the analyze_chatbot_training_health function from earlier)
health_analysis = analyze_chatbot_training_health(
  train_losses=train_losses,
  val_losses=val_losses,
  classification_accuracies=[]  # Add if available
)

print(f"Symptoms identified: {health_analysis['status']}")
if health_analysis["issues"]:
  for issue in health_analysis["issues"]:
      print(f"  - {issue}")

# Step 2: Diagnose root cause based on symptoms
print("\nStep 2: Diagnosing root cause...")
if health_analysis["status"] == "overfitting":
  print("Diagnosis: Model is overfitting - validation loss increasing")
  # Apply overfitting fixes
  fixed_config = fix_chatbot_overfitting({"lora_dropout": 0.1, "r": 16, "learning_rate": 2e-4})
elif health_analysis["status"] == "underfitting":
  print("Diagnosis: Model is underfitting - both losses high")
  # Apply underfitting fixes
  fixed_config = fix_underfitting_config({"r": 8, "learning_rate": 1e-4, "lora_dropout": 0.2})
else:
  print("Diagnosis: Training appears healthy or needs further investigation")

# Step 3: Apply fixes and re-train
print("\nStep 3: Applying fixes and re-training...")
# Update training arguments with fixes
fixed_training_args = TrainingArguments(
  output_dir="./chatbot_results_fixed",
  learning_rate=fixed_config.get("learning_rate", 2e-4),
  # ... other arguments from fixed_config
)

fixed_trainer = Trainer(
  model=model,  # Start fresh or load checkpoint
  args=fixed_training_args,
  train_dataset=train_dataset,
  eval_dataset=eval_dataset,
  tokenizer=tokenizer
)
fixed_trainer.train()

# Step 4: Validate fixes
print("\nStep 4: Validating fixes...")
fixed_history = fixed_trainer.state.log_history
fixed_val_losses = [log["eval_loss"] for log in fixed_history if "eval_loss" in log]

# Compare final validation losses
initial_final_val_loss = val_losses[-1] if val_losses else None
fixed_final_val_loss = fixed_val_losses[-1] if fixed_val_losses else None

if fixed_final_val_loss and initial_final_val_loss:
  improvement = initial_final_val_loss - fixed_final_val_loss
  if improvement > 0:
      print(f"✓ Fixes successful! Validation loss improved by {improvement:.4f}")
  else:
      print(f"✗ Fixes did not improve. Validation loss changed by {improvement:.4f}")
      print("Consider trying alternative fixes or investigating data quality")
```

Best Practices
Start with Conservative Settings: Begin with lower learning rates, moderate capacity, and standard regularization. Increase complexity only if needed.

Monitor Continuously: Set up monitoring from the start. Use TensorBoard or similar tools to track metrics in real-time.

Validate Early: Evaluate on validation set frequently (every 100-500 steps) to catch overfitting early.

Save Checkpoints: Save model checkpoints regularly to enable rollback if training fails.

Document Changes: Keep a log of configuration changes and their effects to learn what works for your use case.

Common Pitfalls
Ignoring Validation Metrics: Focusing only on training loss leads to overfitting. Always monitor validation metrics.

Changing Too Many Things at Once: Making multiple changes simultaneously makes it impossible to identify what fixed the issue. Change one thing at a time.

Not Saving Checkpoints: Training failures without checkpoints force restarting from scratch. Save checkpoints regularly.

Over-Tuning Hyperparameters: Excessive hyperparameter tuning wastes compute. Start with standard settings and tune only if needed.

Summary
Monitoring training dynamics and debugging issues are essential for successful fine-tuning of your customer support chatbot. You learned to monitor training loss, validation loss, learning rate, gradient norms, and task-specific metrics like classification accuracy and response quality. Interpreting loss curves helps you identify overfitting (validation loss increasing), underfitting (both losses high), instability (high variance), or convergence (loss plateauing).

For your chatbot, common issues include overfitting (fix with increased LoRA dropout to 0.15, reduced rank to r=12, or more regularization), underfitting (fix with increased rank to r=32, longer training, or better data), and instability (fix with reduced learning rate from 2e-4 to 1e-4, gradient clipping, or warmup). Use a systematic debugging workflow: identify symptoms from metrics, diagnose root cause, apply targeted fixes, validate improvements.

Key concepts to remember
Monitor Metrics - Track training loss, validation loss, learning rate, gradients, classification accuracy, response quality
Interpret Curves - Loss curves reveal overfitting (val loss increasing), underfitting (both high), instability (high variance)
Common Issues - Overfitting (increase dropout, reduce rank), underfitting (increase rank, train longer), instability (reduce LR, gradient clipping)
Debugging Workflow - Identify symptoms, diagnose cause, apply fixes, validate improvements
Best Practices - Start conservative (r=16, dropout=0.1), monitor continuously, validate early, save checkpoints