# Model Lifecycle

Imagine you have built a machine learning model to predict customer churn for your company. The model shows 95% accuracy in your Jupyter notebook, so you deploy it to production with confidence. Three months later, you discover the model is performing terribly; customers who were predicted to stay are leaving, while your retention campaigns are targeting users who were never going to churn anyway.

What went wrong? The model looked great in development but failed in the real world. This is the classic problem of skipping the proper machine learning lifecycle. Just like you would not ship a mobile app without testing it first, you cannot deploy ML models without following a systematic approach to building, validating, and maintaining them.

In this lesson, you will learn how to design data splits that mimic the future, build pipelines that match production, record the right metadata for reproducibility, and diagnose overfitting and underfitting quickly. You will understand the complete journey from raw data to production deployment.

By the end, you will have a blueprint you can apply to any supervised ML task and a mental model that helps when you fine-tune LLMs or ship embedding-based systems.

Training, Validation and Testing

One of the most critical aspects of successful ML development is properly splitting your data into three distinct sets: training, validation, and test. Think of this like preparing for an exam where training is studying, validation is taking practice tests, and the test set is your final exam.

Training Set (60-70% of data)**: This is where your model learns patterns. Your algorithm sees this data and adjusts its parameters to minimize prediction errors. For example, if you are building a fraud detection system, your training set contains thousands of labeled transactions where the model learns to distinguish between legitimate and fraudulent patterns.

Validation Set (15-20% of data)**: This acts as your development testing ground. You use this data to tune hyperparameters, select the best model architecture, and make decisions about feature engineering. Crucially, while you make decisions based on validation performance, the model does not directly learn from this data during training.

Test Set (15-20% of data)**: Your final, untouched evaluation set. This simulates real-world performance because the model has never seen this data during any part of development. This is your honest assessment of how the model will perform in production.

Consider a recommendation system for an e-commerce platform. Your training set teaches the model user preferences, the validation set helps you choose between collaborative filtering versus content-based approaches, and the test set gives you confidence in the system's performance before launching to customers.

![Data Split Visualization](https://hrcdn.net/ai-engineering/module-1/light/foundations-lesson03-train-val-test-split.svg)

Choosing the Right Split Strategy
The way you split your data must match your production environment. Choose the pattern that fits your data:

Random + stratified when data is independent and identically distributed (no time or identity ties). Stratify to keep minority labels in each split.
Time-based when tomorrow can differ from today (forecasts, churn, fraud, traffic, content). Sort by time: oldest → train, middle → validation, newest → test. This blocks "seeing the future."
Group-aware when the same entity repeats (user, device, patient, item). Keep each entity in one split to avoid identity leakage.

```python
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from datetime import datetime, timedelta

# Create sample data
np.random.seed(42)
n_samples = 1000

# Sample dataset with time and user information
data = pd.DataFrame({
    'user_id': np.random.randint(1, 100, n_samples),
    'timestamp': pd.date_range('2023-01-01', periods=n_samples, freq='H'),
    'feature1': np.random.randn(n_samples),
    'feature2': np.random.randn(n_samples),
    'target': np.random.randint(0, 2, n_samples)
})

print("=== DATA SPLITTING STRATEGIES ===")
print(f"Dataset: {len(data)} samples, {data['user_id'].nunique()} users")
print(f"Time range: {data['timestamp'].min()} to {data['timestamp'].max()}")

# 1. Random Split (Wrong for time series)
print("\n1. RANDOM SPLIT (dangerous for time series):")
train_random, test_random = train_test_split(data, test_size=0.2, random_state=42)
print(f"Train time range: {train_random['timestamp'].min()} to {train_random['timestamp'].max()}")
print(f"Test time range: {test_random['timestamp'].min()} to {test_random['timestamp'].max()}")
print("Problem: Test data contains past information!")

# 2. Time-based Split (Correct for time series)
print("\n2. TIME-BASED SPLIT (correct approach):")
data_sorted = data.sort_values('timestamp')
split_time = data_sorted['timestamp'].quantile(0.8)
train_time = data_sorted[data_sorted['timestamp'] < split_time]
test_time = data_sorted[data_sorted['timestamp'] >= split_time]
print(f"Train time range: {train_time['timestamp'].min()} to {train_time['timestamp'].max()}")
print(f"Test time range: {test_time['timestamp'].min()} to {test_time['timestamp'].max()}")
print("Correct: Test data is strictly in the future!")

# 3. Group-aware Split (Correct for user data)
print("\n3. GROUP-AWARE SPLIT (prevents user leakage):")
unique_users = data['user_id'].unique()
train_users = np.random.choice(unique_users, size=int(0.8 * len(unique_users)), replace=False)
train_group = data[data['user_id'].isin(train_users)]
test_group = data[~data['user_id'].isin(train_users)]
print(f"Train users: {len(train_users)}, Test users: {len(unique_users) - len(train_users)}")
print(f"No user appears in both train and test: {len(set(train_group['user_id']) & set(test_group['user_id'])) == 0}")

print("\nKey lesson: Choose split strategy based on your data structure!")
```

Building Production-Ready Pipelines
In production, preprocessing must be identical to training. The safest approach is to ship a single pipeline that includes preprocessing and the model. Always fit preprocessing on training data only, then reuse it for validation, test, and serving. This prevents a subtle but common failure called preprocessing leakage.

For example, when building a customer churn model, your preprocessing pipeline might normalize spending amounts and encode categorical features. If you fit your scaler on all data before splitting, your model inadvertently sees future information through the scaling parameters. Instead, fit the scaler only on training data, then apply those same scaling parameters to validation, test, and production data

```python
# Wrong: Fit preprocessing on all data
scaler = StandardScaler().fit(all_data)
X_train = scaler.transform(train_data)
X_test = scaler.transform(test_data)

# Right: Fit only on training data
scaler = StandardScaler().fit(train_data)
X_train = scaler.transform(train_data)
X_test = scaler.transform(test_data)  # Uses train statistics
```

Understanding Overfitting vs Underfitting
Think of overfitting and underfitting like cooking pasta. Underfit models are like undercooked pasta; they have not learned enough to be useful. Overfit models are like overcooked pasta; they have learned too much detail and become rigid and unusable.

Underfitting (High Bias): Your model is too simple to capture the underlying patterns. It performs poorly on both training and validation data. For example, trying to predict house prices using only the number of bedrooms; you are missing crucial information like location, size, and condition.

Overfitting (High Variance): Your model memorizes training data instead of learning generalizable patterns. It performs excellently on training data but poorly on validation and test data. This happens when you have too many features relative to your dataset size, or when your model is overly complex.

The Sweet Spot: A well-fitted model captures the essential patterns without memorizing noise. It shows good performance on training data and similar (slightly lower) performance on validation data.

![Overfitting vs Underfitting](https://hrcdn.net/ai-engineering/module-1/light/1.1.3_underfitting_overfitting.svg)

Bias-Variance Intuition
High bias → underfit (too rigid)
High variance → overfit (too sensitive)
Aim for the simplest model that performs well on validation and is stable across time and data slices.

To understand overfitting and underfitting, plot your training and validation loss over time. If training loss decreases while validation loss increases or plateaus, you're overfitting. If both remain high, you're underfitting.

Adjust the model complexity slider to see how it affects training and validation loss in real-time. Watch how underfitting, good fit, and overfitting manifest in the loss curves; a fundamental concept in machine learning that determines whether your model will succeed in production.

Experiment: Start with complexity at 1 (underfitting), gradually increase to 5 (sweet spot), then push to 10 (overfitting). Observe how the gap between training and validation loss changes. This hands-on experience helps understand the bias-variance tradeoff that is critical in production Machine learning.

Model and Data Versioning
In software development, you version your code. In ML, you must version both your models and datasets because both evolve constantly. Data versioning is often overlooked but equally critical since any model's performance is only as good as the data quality and consistency.

You must be able to answer: "Which model, trained on which data, made this decision?" That means versioning all three layers:

Data Versioning Strategy: Every time you collect new data, clean existing data, or modify features, create a new version. Use tools like DVC (Data Version Control) or simple naming conventions with timestamps. For instance, customer_data_v2.1_2024_03_15 clearly indicates version and collection date.

Model Versioning Approach: Version models after each training run, not just successful ones. Include metadata about the training data version, hyperparameters, and performance metrics. A practical naming scheme might be fraud_detection_v1.3_acc_0.94_2024_03_15, which immediately tells you the model version, accuracy, and training date.

Code & Configuration: Track git SHA, library versions, hyperparameters, random seeds, decision thresholds, and the version of your label-generation logic.

Netflix versions their recommendation models continuously. When they discovered that user behavior changed during the pandemic, they could quickly roll back to previous model versions or retrain with updated data while maintaining full traceability of what changed and why.

## Production Lifecycle Management
Moving from Jupyter notebooks to production systems requires understanding the complete model lifecycle.

Development Phase
Start with exploratory data analysis and feature engineering. Use your training/validation split to iterate quickly on model architectures and hyperparameters. Document everything: which features you tried, why you chose specific algorithms, and what didn't work.

Staging Phase
Test your model with production-like data volumes and latency requirements. This is where you discover that your beautiful gradient boosting model takes 10 seconds per prediction—unacceptable for real-time applications. You might need to switch to a faster linear model or implement model compression techniques.

Production Deployment
Deploy safely by running in shadow mode, then canary to a small percentage of traffic. Implement monitoring for data drift, model performance degradation, and system health. Real-world data changes constantly. Your customer behavior model trained on pre-pandemic data might become useless during economic uncertainty.

Continuous Improvement
Monitor latency (p50/p95), errors, score distributions, and precision/recall at your chosen threshold once labels arrive. Detect drift by watching input drift, output drift, and performance drift when ground truth catches up. Establish feedback loops to collect new data and retrain models. Set up automated retraining pipelines that trigger when performance drops below thresholds or when sufficient new data becomes available.

Retraining Strategy
Implement retraining on a schedule (weekly/monthly) and on triggers (drift, schema change, metric drop). Every retrain is a new version with its own evaluation and rollback plan.

## Common Pitfalls and Solutions

Data Leakage
Data leakage occurs when information from the future or target variable inadvertently appears in your training features. This creates artificially high performance metrics that completely fail in production.

Temporal Leakage: Using future information to predict past events. For example, including "account_closed_date" as a feature to predict customer churn—obviously customers who churned have this date filled, but you won't know this information when making real-time predictions.

Target Leakage: Including features that are direct consequences of the target variable. In credit scoring, using "default_flag" to predict loan defaults seems obvious but is completely circular.

Solution: Implement strict temporal ordering in your data splits. Ensure your test set represents truly future data that your model will encounter in production. Create detailed feature documentation that traces the origin and availability timeline of each feature.

Improper Data Splitting
Random splitting works for stable datasets, but most real-world applications involve time-series data where future information must never leak into training.

The Wrong Way: Randomly shuffling all your data before splitting. This means your model might be trained on data from December and tested on data from January—but in production, it needs to predict February using only information available through January.

The Right Way: Use temporal splits where training data comes from earlier time periods than validation and test data. For a customer churn model, train on months 1-8, validate on month 9, and test on month 10.

Improper Data Splitting
Random splitting works for stable datasets, but most real-world applications involve time-series data where future information must never leak into training.

The Wrong Way: Randomly shuffling all your data before splitting. This means your model might be trained on data from December and tested on data from January—but in production, it needs to predict February using only information available through January.

The Right Way: Use temporal splits where training data comes from earlier time periods than validation and test data. For a customer churn model, train on months 1-8, validate on month 9, and test on month 10.

Overfitting Disguised as Success
High training accuracy can mask serious overfitting problems. Teams often celebrate 99% training accuracy without checking validation performance, only to discover 60% accuracy in production.

Always plot learning curves showing both training and validation performance over time. Implement early stopping when validation performance stops improving. Use cross-validation for smaller datasets to get more robust performance estimates.

Scale Mismatch
Models that work perfectly on your laptop with cleaned CSV files often fail when processing real-time streaming data with missing values, different formats, and volume constraints.

Solution: Test with production-scale data volumes during development. Implement robust preprocessing pipelines that handle missing data, outliers, and format variations. Build monitoring to detect when incoming data differs from training data distributions.

## Summary
The model lifecycle forms the backbone of successful ML engineering. Your ability to manage data splits, version control, and avoid overfitting directly determines whether your models succeed or fail in production.

A dependable ML system is the result of a disciplined lifecycle, not a lucky model. Design train/validation/test splits that mimic production (time flows forward, entities repeat, labels may be rare). Version data, code, and models together so any prediction is reproducible and rollbacks are easy. Use the train-validation gap to detect over/underfitting and guide your next step. After the "final exam," treat the model like a service: deploy safely, monitor drift and latency, and retrain on purpose.

Key concepts to remember

Split design is a product decision: Mirror reality (time, identity, imbalance) in your data splits
Ship the whole pipeline: Fit transforms on training data only to prevent preprocessing leakage
Version everything: Track data, code, and model versions together for reproducibility
Use fast signals: Monitor the train-validation gap to detect problems early
Production is different: Plan for monitoring, drift detection, and retraining from day one