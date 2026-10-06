# Types of Machine Learning: Supervised, Unsupervised, and Reinforcement
Now that you understand what Machine Learning is, you need to know which approach to use for different problems. Not all ML problems are the same; sometimes you have labeled examples to learn from, sometimes you need to discover hidden patterns in unlabeled data, and sometimes your system must learn through trial and error.

In this lesson, you will explore the three fundamental types of machine learning: supervised learning, unsupervised learning, and reinforcement learning. You will understand when to use each approach and see practical examples of how they solve real-world problems.

By the end, you will have a framework for choosing the right ML approach based on your available data and business objectives, preparing you to understand the complete model lifecycle in the next lesson.

Three Families of Machine Learning
Most real systems that learn from data fall into three big families:

Sometimes you have examples paired with the right answers and you want the computer to imitate those answers
Sometimes you have only raw data and you want the computer to discover structure you did not label
Sometimes your system must act, see what happened, and improve through trial and error

![Machine learning families](https://hrcdn.net/ai-engineering/module-1/light/foundations-lesson02-ml-types-comparison.svg)

These three situations map to supervised learning, unsupervised learning, and reinforcement learning.

Machine learning is generally divided into three paradigms, each defined by how the model learns. Supervised learning trains on labeled examples where a "teacher" provides the correct answers — like a dataset of emails tagged as spam or not spam — so the model can learn to map inputs to known outputs, making it ideal for tasks like spam detection and price prediction.

Unsupervised learning, by contrast, works with raw unlabeled data and uses algorithms to discover hidden structure on its own, grouping similar points together; it's the go-to approach for customer segmentation and anomaly detection.

Reinforcement learning learns through trial and error by interacting with an environment (shown as icons of video, chat, web, and stars) and receiving feedback in the form of rewards or penalties, which makes it well-suited for game playing and recommendation systems.

Together, these three paradigms cover virtually all modern ML applications: supervised learning answers "what is this?", unsupervised learning answers "how is this organized?", and reinforcement learning answers "what should I do next?"

## Supervised Learning
Supervised learning is the most common because most use cases already capture outcomes. You might know whether an email was marked as spam, whether a transaction was later confirmed as fraud, or how long a delivery actually took.

In supervised learning, you feed the model inputs along with the correct outputs so it can learn a mapping from inputs to outputs. Later, the model applies this mapping to new, unseen inputs.

A helpful way to picture supervised learning is flashcard study. You show the model many input–answer pairs ("this email → spam," "this email → not spam"). The model adjusts its thinking process (adjusted by parameters/weights) so that the answers it predicts match the answers you provided. When it sees a new email, it no longer needs you to say "spam"; it has internalized patterns from the examples.

Two Core Tasks
In practice, supervised learning splits into two core tasks:

Classification predicts a category, such as spam vs. not spam or churn vs. not churn
Regression predicts a number, such as price, demand next week, or estimated time of arrival

Both use the same basic concept: split the data into training, validation, and test sets; train the model on training data; tune decisions on validation data; and report performance on the test set only once.

Production Considerations
In production, supervised learning succeeds when you can obtain quality labels when your system needs them. Labels can arrive late (fraud confirmed weeks after the transaction), can be noisy (users mislabel sentiment), and can drift (the definition of "risky" changes as policies change).

You will need processes to re-label, re-train, and re-deploy, plus guardrails like shadow deployments and rollback.

The code below shows how to convert text into features, train a basic model, and evaluate it.

```python
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression

# Step 1: Prepare training data (messages + human labels)
texts = [
    "server down in region us-east",
    "can we reschedule tomorrow",
    "payment failed for multiple users",
    "lunch at 1?"
]
labels = [1, 0, 1, 0]  # 1 = urgent, 0 = not urgent

# Step 2: Convert text to numbers the model can understand
vectorizer = TfidfVectorizer()
X = vectorizer.fit_transform(texts)

# Step 3: Train the model to learn the pattern
model = LogisticRegression().fit(X, labels)

# Step 4: Make predictions on new data
new_text = ["database error affecting users"]
X_new = vectorizer.transform(new_text)
prediction = model.predict(X_new)
print(f"Urgency prediction: {prediction[0]}")  # 1 = urgent
```

Common Mistakes in Supervised Learning

Data leakage: Leaking information from the future into the past (for example, using a "delivered_at" timestamp to predict delivery time). This is a critical mistake because it gives your model access to information that would not be available at prediction time in the real world. When you train a model to predict delivery time using the actual delivery timestamp, the model learns to cheat rather than learning the underlying patterns. In production, you will not have the delivery timestamp when making the prediction, so your model's performance will collapse dramatically.

Label drift: Silently shifting the label definition over time; a policy change creates a new concept of "fraud" but you still evaluate against the old one. This mistake undermines model reliability because your training data becomes inconsistent with what you are actually trying to predict, leading to poor performance on recent data.

You can avoid these by building time-aware feature pipelines, logging the exact label generation code per model version, and validating with backtesting.

Complexity Trade-off
There is an unavoidable trade-off between model complexity and maintainability. A deep model can squeeze out more accuracy, but a smaller model may be easier to explain, faster to serve, cheaper to run, and quicker to re-train when data drifts. In latency-sensitive paths, a slightly less accurate but much faster model often wins.

## Unsupervised Learning
Unsupervised learning becomes useful when you do not have labels but still want the data to tell you something actionable.

Instead of learning to imitate answers, the goal is to reveal structure: groups that behave similarly, dimensions that summarize variation, or points that look unusual.

Common Applications
The most common unsupervised task is clustering. Imagine you have millions of support tickets but no categories. Clustering can group tickets by similarity so you can design queues, priority, and self-serve flows.

Another common task is anomaly detection. If you embed logs or metrics into vectors and learn what normal looks like, you can flag events or time windows that deviate strongly from regular behavior.

Challenge with Ground Truth
In reality, the challenge is that unsupervised results do not come with ground truth. A cluster that is mathematically neat may not map to anything your business can act on.

The safe pattern is "unsupervised to explore, supervised to operate": use clustering to propose segments, then label a sample and train a supervised classifier that recognizes those segments reliably with an evaluation metric tied to business outcomes.

You will also need to monitor whether clusters drift as user behavior changes, because the same algorithm with the same settings can produce very different groupings as data evolves.

A minimal example shows how quickly you can cluster points. In a real system, the inputs would be embeddings of customers, products, or messages rather than hand-crafted coordinates.

```python
from sklearn.cluster import KMeans

# Each inner array represents a data point with [x, y] coordinates
# In practice, these could be customer features like [age, spending] or
# product features like [price, rating], we use simple numbers for clarity

points = [[1, 2], [1, 3], [10, 11], [11, 12], [9, 10]]

# First cluster: [1, 2] and [1, 3] are close together (low x values)
# Second cluster: [10, 11], [11, 12], [9, 10] are close together (high x values)

kmeans = KMeans(n_clusters=2, n_init="auto").fit(points)

# Average position of each cluster
print("Cluster centers:", kmeans.cluster_centers_)

# Which cluster each point belongs to [0, 0, 1, 1, 1]
print("Assignments:", kmeans.labels_)
```

Common Pitfalls and Solutions

A frequent mistake is treating the output of a clustering algorithm as truth instead of a hypothesis.

The trade-off with unsupervised learning is **speed vs usefulness**. It is fast to run and can surface patterns you did not anticipate, but turning those patterns into operations typically requires a downstream supervised step and ongoing human judgment.

## Reinforcement Learning
Reinforcement learning (RL) applies when your system must choose actions, observe the consequences, and improve the policy that selects actions to maximize long-term reward. After each action it receives a signal: a reward that says how good the outcome was, possibly with delay. The agent's job is to learn a policy that chooses actions that lead to high reward.

Think of it like training a dog: when it performs the right trick, you give it a treat; when it doesn't, no reward. Over time, it learns which behaviors get the most treats.

Key Characteristics
The defining feature of RL is that feedback is experienced, not given as labeled examples. This makes RL powerful—your system can discover strategies you did not encode—but also expensive and tricky.

In practical products, you see RL and bandit methods in places where the system must balance exploration (trying new things to learn) with exploitation (showing what seems best now). Ranking and recommendation systems will often experiment with variations to learn better policies over time.

Safety Considerations
You should cap exploration, and guard against feedback loops (e.g., a recommender that narrows content diversity and harms long-term engagement).

Some common pitfalls include:

Optimizing the wrong reward: Maximizing watch time may boost short-term metrics but degrade user trust if content becomes click-bait
Insufficient safety rails: Training online without sufficient safety rails, causing an abrupt drop in user experience when the policy explores too aggressively
RL's core trade-off is performance vs cost and risk. It can achieve excellent results in dynamic environments, but it demands more data, more compute, and more safety engineering than supervised approaches.

## Choosing Between the Three
In a real engineering setting, you do not start from algorithms; you start from what data and feedback are actually available.

If you have reliable labeled outcomes, supervised learning gets you to value fastest and is the easiest to monitor with clear metrics
If you have a lake of unlabeled events and you need to orient yourself, unsupervised learning is a good first step to propose segments or detect anomalies, but plan on validating with downstream supervision
If your system must take actions and learn from their consequences, start with lightweight exploration (A/B tests, bandits) and graduate to RL only when the reward signal is well-defined and the safety story is solid

Decision Framework
A small, optional exercise that helps pick correctly is to write one sentence in the form "We will predict Y from X to optimize P."

If you can fill Y with a labeled outcome, you are in supervised territory
If Y is unknown and you want structure in X, you are in unsupervised territory
If Y depends on a sequence of actions you will take, you are in reinforcement territory

Examples
"We will predict churn probability from user activity to optimize retention campaigns" → Supervised
"We will find customer segments from purchase behavior to optimize marketing strategy" → Unsupervised
"We will select content recommendations from user interactions to optimize long-term engagement" → Reinforcement

## Summary
The three types of machine learning—supervised, unsupervised, and reinforcement—each solve different categories of problems based on the data and feedback available to you.

Key concepts to remember

Supervised learning: Use when you have labeled examples (input-output pairs). Best for classification and regression problems where you know the desired outcomes. Most common in production systems because labeled data is often available from business operations.

Unsupervised learning: Use when you have data but no labels and need to discover hidden structure. Ideal for exploratory analysis, customer segmentation, and anomaly detection. Often a first step before building supervised systems.

Reinforcement learning: Use when your system must take actions and learn from consequences. Best for dynamic environments where you need to balance exploration and exploitation, like recommendation systems and game playing.

Now that you understand the three types of machine learning, you are ready to learn how to build reliable ML systems that work in production.

In the next lesson, you will explore the complete model lifecycle: how to properly split your data, avoid common pitfalls like overfitting, and manage the versioning and deployment process that turns experimental models into robust, production-ready systems.