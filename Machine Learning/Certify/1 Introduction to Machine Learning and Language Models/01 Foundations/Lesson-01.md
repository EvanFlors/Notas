# What is Machine Learning

## Introduction to Machine Learning

Traditional software engineering relies on explicit rules, but what happens when those rules cannot keep up with constantly changing patterns? Imagine trying to detect spam emails with hard-coded rules; spammers would quickly adapt, making your filters obsolete. This fundamental limitation of rule-based systems led to the development of Machine Learning.

In this lesson, you will understand what makes Machine Learning different from traditional programming, explore the core components that every ML system needs, and see real-world examples of how ML solves problems that would be impossible with conventional approaches.

By the end, you will have a clear mental model of how ML works and when to apply it, setting the foundation for understanding the types of machine learning you will explore in the next lesson.

What is Machine Learning?
In traditional software engineering, we explicitly write rules for the computer to follow.
This works for a short time, but then spammers get smarter. They start writing "w1n m0ney" or "claim reward." Suddenly, your rules break. Adding more rules is like playing whack-a-mole—you will never keep up.

Spammers constantly change tactics. Fraudsters evolve faster than rules can be updated. User preferences (music, shopping, recommendations) shift daily. Maintaining thousands of rules quickly becomes impossible.

This is where Machine Learning (ML) comes in.

Traditional: Rules + Data → Output
Machine Learning: Data + Outputs (labels) → Learning Algorithm → Model (rules automatically learned)

At its core, Machine Learning (ML) is about building programs that improve their performance at a task as they are exposed to more data.

If we have to translate into simple terms, the three blocks for Machine Learning include:

What do you want the model to do? (e.g., detect spam emails)
What data does it see while learning? (e.g., thousands of labeled emails)
How do you measure success? (e.g., accuracy, precision, recall)
When all three are in place, we have Machine Learning.

Core Components of ML
Data → Inputs and outputs (features & labels)
Model → The function mapping inputs → predictions
Algorithm → The step-by-step process that helps the model learn from data. For example, when the model makes wrong predictions, the algorithm adjusts the model's internal weights to perform better next time
Evaluation Metric → The measure of performance (accuracy, recall, F1, RMSE)
In spam detection, the data is email content with labels (spam/not spam), the model is a pattern-recognition system, the algorithm is the method that teaches the model (example: logistic regression), and the metric tells us how accurate the predictions are.

How Machine Learning Works
Think of ML as a pipeline:

![How machine learning works](https://hrcdn.net/ai-engineering/module-1/light/foundations-lesson01-ml-pipeline.svg)

Data (Features & labels) → Algorithm (Learns from data) → Model (Learned function) → Predictions → Evaluation Metric (Accuracy, Recall, F1 Score)
ML pipeline from data to deployment

Data Collection → Gather examples (emails labeled spam/not spam, transactions marked fraud/not fraud)
Feature Representation → Convert raw data into numerical form
Training → Use algorithms to find patterns that map inputs → outputs
Evaluation → Test the model on unseen data to see if it is able to understand the data
Deployment → Integrate into a product, monitor, and retrain as needed

In simpler terms, training is like studying past exam questions and evaluation is like taking a new exam to test if you have truly learned.

## How ML Differs from Traditional Programming

In traditional software development, we follow a deterministic approach:
Rules + Data → Output This represents the traditional programming approach.

In machine learning, the process is reversed:
Data + Outputs (labels) → Learning Algorithm → Model (rules automatically learned)

Spam Detection Example
Let's take a look at how spam detection will differ in a traditional and ML-based approach.

Traditional Approach
You might hard-code rules:

```python
if "win" in email and "money" in email:
    spam = True
```

Engineers write explicit rules

ML Approach
Collect thousands of examples labeled spam or not spam, then let an algorithm (e.g., logistic regression) learn statistical patterns. Now the program can generalize to unseen spam tactics.

![ML approach](https://hrcdn.net/ai-engineering/module-1/light/foundations-lesson01-traditional-vs-ml.svg)

```python
# ML approach: Learn from examples, then generalize

# Algorithm learns statistical patterns
model.train(thousands_of_labeled_examples)

# → "spam" (generalizes to unseen tactics)
model.classify("w1n m0n3y fast")
```

Algorithm discovers patterns automatically

What Exactly Is a Model?
A model in ML is just a function that maps inputs to outputs, with parameters that are adjusted during training.

![ML model](https://hrcdn.net/ai-engineering/module-1/light/foundations-lesson01-model-concept.svg)

A machine learning model is essentially a parameterized function that maps inputs to outputs — for example, taking purchase history features like age and location as inputs and producing a prediction like $450. The function's behavior is controlled by learnable parameters (weights such as w₁ = 250 and w₂ = 50,000, plus a bias b = 100,000 in a simple housing-price formula like price = w₁ × area + w₂ × bedrooms + b), which are not hand-coded but discovered from training data. Learning, then, is the iterative process of tuning those parameter values to minimize prediction error, and the same principle scales from simple models with just a handful of weights to complex ones like GPT-4 that contain billions of parameters arranged in deep neural networks.

For example, in linear regression:

price = w1 * area + w2 * bedrooms + b

Here, w1, w2, and b are parameters (also known as weights) that are learned from data.

In Neural Networks
Instead of a few weights, there may be millions (or billions) of parameters.

The learning process = finding the parameter values that make predictions closest to reality.

The Ingredients of Machine Learning

Data
Features: Measurable input variables (e.g., word counts, transaction amount)
Labels: Desired outputs (e.g., spam/not spam, fraud/not fraud)

Algorithm
The method used to adjust the model parameters (e.g., gradient descent)

Model
The function that represents the relationship between inputs and outputs

Evaluation Metric
The yardstick to measure success (e.g., accuracy, F1 score, RMSE)

Real-World Examples

Everyday Applications You Already Use
Spam filtering → Gmail detecting spam automatically
Recommendations → Netflix suggesting movies, Amazon recommending products
Voice Assistants → Siri and Alexa recognizing speech and intent

Business & Industry
Fraud detection → Banks flagging unusual transactions
Predictive maintenance → Machines in factories warning before they fail
Healthcare → Models assisting in diagnosing diseases from scans

Developer Use Cases
Code completion → GitHub Copilot predicting the next line
Bug detection → Static analysis powered by ML models
Monitoring → Detecting anomalies in logs

Machine Learning in Production
Training a model in a Jupyter notebook is just the beginning. Deploying to production introduces new challenges:

Data Drift: Monitoring how the real-world data evolves
Latency & Scale: The model must respond in milliseconds at high traffic (e.g., autocomplete)
Monitoring: A model that works today may degrade tomorrow due to data drift (e.g., spammers changing tactics)
Versioning: Need to know which data + code + parameters produced the deployed model
Feedback Loop: Collect predictions + outcomes to retrain and improve

This is why modern ML engineering often blends ML with MLOps practices.

## Traditional Rules vs Learning from Data
The code snippet below shows the fundamental difference between writing explicit rules versus letting a system learn patterns from examples, using the spam detection concept from the lesson.

You can run this code directly to see machine learning in action.

```python
# Traditional Programming: Rules + Data → Output

def traditional_approach(email_text):
    """
    Hard-coded rules (like the lesson example)
    """
    spam_words = ["win", "money", "free", "prize", "urgent"]
    email_lower = email_text.lower()

    spam_count = 0
    for word in spam_words:
        if word in email_lower:
            spam_count += 1

    if spam_count >= 2:
        return "SPAM"
    else:
        return "NOT SPAM"

# Machine Learning: Data + Labels → Learn Rules

def learn_from_examples(training_examples):
    """
    Learn what words indicate spam from examples
    """
    spam_words = {}
    legit_words = {}

    # Count word frequencies in spam vs legitimate emails
    for email, label in training_examples:
        words = email.lower().split()
        if label == "SPAM":
            for word in words:
                spam_words[word] = spam_words.get(word, 0) + 1
        else:
            for word in words:
                legit_words[word] = legit_words.get(word, 0) + 1

    return spam_words, legit_words

def ml_prediction(email_text, spam_words, legit_words):
    """
    Use learned patterns to classify new email
    """
    words = email_text.lower().split()
    spam_score = 0
    legit_score = 0

    for word in words:
        spam_score += spam_words.get(word, 0)
        legit_score += legit_words.get(word, 0)

    if spam_score > legit_score:
        return "SPAM"
    else:
        return "NOT SPAM"

# Example data (what the system learns from)
training_data = [
    ("win free money now", "SPAM"),
    ("urgent action required", "SPAM"),
    ("meeting tomorrow at 3pm", "NOT SPAM"),
    ("project deadline friday", "NOT SPAM"),
    ("claim your prize today", "SPAM"),
    ("lunch with team tuesday", "NOT SPAM"),
    ("w1n money in few days", "SPAM")
]

print("=== TRAINING DATA ===")
for email, label in training_data:
    print(f"'{email}' → {label}")

# Learn from the data
spam_patterns, legit_patterns = learn_from_examples(training_data)

print("\n=== WHAT THE SYSTEM LEARNED ===")
print("Spam indicators:", dict(spam_patterns))
print("Legitimate indicators:", dict(legit_patterns))

# Test both approaches
test_emails = [
    "win money fast",           # Should be caught by both
    "w1n m0n3y fast",           # Traditional rules might miss this
    "meeting about budget",     # Should be legitimate
    "urgent prize notification" # Mixed signals
]

print("\n=== COMPARING APPROACHES ===")
print(f"{'Email':<25} {'Traditional':<12} {'ML Learned'}")
print("-" * 50)

for email in test_emails:
    traditional_result = traditional_approach(email)
    ml_result = ml_prediction(email, spam_patterns, legit_patterns)
    print(f"{email:<25} {traditional_result:<12} {ml_result}")

print("\n=== KEY DIFFERENCE ===")
print("Traditional: We write the rules manually")
print("ML: The system discovers patterns from examples")
print("ML can adapt when spammers change tactics!")
```

Summary
Machine Learning represents a fundamental shift from writing explicit rules to learning patterns from data. Instead of trying to anticipate every possible scenario with hard-coded logic, ML systems discover relationships automatically and adapt as new data becomes available.

Key concepts to remember

Learning from data instead of rules: Teaching computers to find patterns rather than programming every decision is the core of Machine Learning
Essential components: Every ML system needs a clear task, quality data, an appropriate model, a learning algorithm, and evaluation metrics
Real-world applications: From spam filtering to fraud detection, ML powers systems that would be impossible to build with traditional rule-based approaches
Production considerations: Successful ML involves monitoring, versioning, retraining, and scaling—not just training models