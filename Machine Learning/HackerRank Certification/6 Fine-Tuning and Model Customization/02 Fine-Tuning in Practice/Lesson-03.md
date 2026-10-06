## PEFT (LoRA, QLoRA) Fundamentals

Full fine-tuning updates all model parameters, requiring substantial GPU memory (often 80GB+ for 7B models) and long training times. For your customer support chatbot, you have a 7B model and a 16GB GPU - full fine-tuning is not possible. Parameter-Efficient Fine-Tuning (PEFT) techniques like LoRA and QLoRA enable fine-tuning with minimal parameter updates, reducing memory requirements by 10-100x while maintaining performance.

Many teams assume full fine-tuning is necessary, leading to infrastructure costs and training times that exceed budgets. Understanding PEFT techniques enables you to fine-tune your customer support chatbot on accessible hardware, train multiple task-specific adapters efficiently, and iterate faster on fine-tuning experiments.

In this lesson, you will learn LoRA and QLoRA fundamentals, configure adapters for your customer support chatbot, and implement PEFT fine-tuning workflows that work on your 16GB GPU.

LoRA Fundamentals
LoRA (Low-Rank Adaptation) adds trainable low-rank matrices to model layers instead of updating all parameters. This approach reduces trainable parameters by 100-1000x while maintaining fine-tuning effectiveness.

How LoRA Works

LoRA works by adding small, trainable adapter layers to your model instead of updating all the original weights. Think of it like adding a small adjustment layer on top of your pretrained model rather than modifying the model itself.

The Core Idea

Instead of updating a large weight matrix W (which has billions of parameters), LoRA learns two much smaller matrices A and B. These small matrices work together to create the same effect as updating W, but with far fewer parameters. The key insight is that most weight updates can be represented efficiently using these smaller matrices.

During Training

When training your customer support chatbot with LoRA:

Pretrained weights stay frozen: The original model weights W remain unchanged. These weights contain all the general language knowledge the model learned during pretraining.

Small adapters learn your task: Two small matrices A and B are added and trained. Matrix A starts with random values, and matrix B starts at zero. Together, they learn how to adapt the model for your specific task.

Combined computation: For each input, the model computes the output using both paths: the frozen pretrained weights (Wx) plus the adapter weights (BAx). The final output is h = Wx + BAx, combining general knowledge with task-specific adaptations.

This approach lets your model learn customer support patterns without forgetting its general language understanding, and it requires training only a tiny fraction of parameters.

After Training: Weight Merging

Once training is complete, you can merge the adapter weights directly into the pretrained weights. Instead of keeping W, A, and B separate, you create a single merged weight matrix W_merged = W + BA. This merged model produces identical outputs but is simpler to deploy - you only need to store one set of weights instead of three. The merged model works exactly like a fully fine-tuned model during inference, but you achieved this by training only the small A and B matrices.

![LoRA weight merging diagram showing during training (pretrained weights W plus low-rank matrices BA) and after training (merged weights W_merged)](https://hrcdn.net/ai-engineering/module-6/light/lora-weight-merging.svg)

LoRA weight merging: training vs inference

```python
# LoRA Implementation for Customer Support Chatbot
# This demonstrates configuring LoRA for your 7B chatbot model

from peft import LoraConfig, get_peft_model
from transformers import AutoModelForCausalLM

# Configure LoRA for customer support chatbot (moderate complexity task)
lora_config = LoraConfig(
  r=16,  # Rank - good balance for chatbot tasks
  lora_alpha=32,  # Scaling factor (typically 2x rank)
  target_modules=["q_proj", "v_proj"],  # Attention layers for instruction following
  lora_dropout=0.1,  # Dropout for regularization
  bias="none",  # Don't train bias terms
  task_type="CAUSAL_LM"  # Causal language modeling for chatbot
)

# Load base model (7B Llama-2 for chatbot)
base_model = AutoModelForCausalLM.from_pretrained(
  "meta-llama/Llama-2-7b-chat-hf",
  torch_dtype=torch.float16,  # Use float16 to save memory
  device_map="auto"  # Automatic device placement
)

# Apply LoRA adapter
model = get_peft_model(base_model, lora_config)

# Check trainable parameters
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
total_params = sum(p.numel() for p in model.parameters())
print(f"Trainable parameters: {trainable_params:,} ({100 * trainable_params / total_params:.2f}%)")
print(f"Memory usage: ~16GB (vs 80GB for full fine-tuning)")
# Output: Trainable parameters: ~4M (0.05% of total)
```

LoRA Configuration Parameters

Key parameters control LoRA behavior:

r (rank): Controls adapter capacity. Lower r = fewer parameters but less capacity. Typical values: 8-64.
lora_alpha: Scaling factor for adapter weights. Higher alpha = stronger adapter influence. Typically 2x r.
target_modules: Which layers to adapt. Common choices: attention layers (q_proj, v_proj) or all linear layers.
lora_dropout: Dropout rate for regularization. Typical values: 0.05-0.1.

```python
# LoRA Configuration for Customer Support Chatbot
# This demonstrates choosing the right configuration for your chatbot

# Configuration 1: Small, efficient (for simple classification only)
# NOT recommended for your chatbot - too limited
small_lora = LoraConfig(
  r=8,
  lora_alpha=16,
  target_modules=["q_proj", "v_proj"],  # Only attention layers
  lora_dropout=0.1
)

# Configuration 2: Medium capacity (RECOMMENDED for your chatbot)
# Good balance for classification + generation tasks
medium_lora = LoraConfig(
  r=16,
  lora_alpha=32,
  target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],  # All attention layers
  lora_dropout=0.1
)

# Configuration 3: High capacity (for very complex multi-task scenarios)
# Use if you need advanced reasoning or complex multi-step tasks
large_lora = LoraConfig(
  r=64,
  lora_alpha=128,
  target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],  # All linear layers
  lora_dropout=0.05
)

# For your customer support chatbot (classification + generation):
# Use medium_lora - it handles varied instructions well without overfitting
```

Memory and Training Benefits

LoRA reduces memory requirements significantly. Your 7B customer support chatbot model requires 80GB for full fine-tuning, but only needs 16GB with LoRA - perfect for your 16GB GPU. This enables training on accessible hardware without cloud compute costs.

Training time also decreases because fewer parameters are updated. LoRA typically trains 2-5x faster than full fine-tuning while achieving similar or better performance. Your chatbot training that would take 8 hours with full fine-tuning might complete in 2-3 hours with LoRA.

QLoRA Fundamentals
QLoRA (Quantized LoRA) combines quantization with LoRA to further reduce memory requirements. QLoRA enables fine-tuning 7B models on 8GB GPUs by using 4-bit quantization for the base model while keeping adapters in full precision.

How QLoRA Works

QLoRA works by compressing the pretrained model weights to use less memory, then adding the same small adapter layers that LoRA uses. Think of it like storing your model in a compressed format during training, then decompressing it only when needed for computation.

The Core Idea

Quantization reduces the precision of numbers stored in memory. Instead of storing weights as 16-bit or 32-bit floating-point numbers, QLoRA stores them as 4-bit integers. This reduces memory by 4x (16 bits ÷ 4 bits = 4x reduction). However, the adapter matrices A and B remain in full precision to ensure training quality.

During Training

When training your customer support chatbot with QLoRA:

Base model is quantized: The pretrained weights W are stored in 4-bit format, reducing memory from 14GB to approximately 3.5GB for a 7B model.

Adapters stay in full precision: The LoRA matrices A and B are stored in 16-bit or 32-bit precision, ensuring they can learn effectively. These small matrices (typically 10-50MB) do not significantly impact memory.

Dynamic dequantization: During forward and backward passes, the quantized weights are temporarily converted back to higher precision for computation, then quantized again for storage. This process is automatic and transparent.

Combined computation: The output is computed as h = W_dequantized x + BAx, where W_dequantized is the temporarily decompressed pretrained weights. The model learns task-specific adaptations just like LoRA, but uses far less memory.

Why 4-bit Works

4-bit quantization works because neural network weights have redundancy - many weights have similar values. Quantization maps similar weight values to the same 4-bit representation, losing some precision but preserving the overall weight distribution. Research shows that 4-bit quantization maintains 95-99% of model performance while reducing memory by 4x. The adapter matrices compensate for any quantization loss by learning task-specific adjustments.

Memory Savings Breakdown

For your 7B customer support chatbot:

Full fine-tuning: 80-100GB (model + gradients + optimizer states)
LoRA: 16GB (model in float16 + small adapters)
QLoRA: 8GB (model in 4-bit + small adapters in float16)
QLoRA enables training on consumer GPUs (8GB) that would otherwise be insufficient.

```python
# QLoRA Implementation for Customer Support Chatbot
# Use this if you only have 8GB GPU instead of 16GB

from transformers import BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

# Configure 4-bit quantization (reduces memory by 4x)
bnb_config = BitsAndBytesConfig(
  load_in_4bit=True,  # 4-bit quantization
  bnb_4bit_quant_type="nf4",  # NormalFloat4 quantization (best quality)
  bnb_4bit_compute_dtype=torch.float16,  # Computation in float16
  bnb_4bit_use_double_quant=True  # Double quantization for better quality
)

# Load model with quantization
model = AutoModelForCausalLM.from_pretrained(
  "meta-llama/Llama-2-7b-chat-hf",
  quantization_config=bnb_config,
  device_map="auto"  # Automatic device placement
)

# Prepare model for k-bit training
model = prepare_model_for_kbit_training(model)

# Configure LoRA adapter (same as before)
lora_config = LoraConfig(
  r=16,
  lora_alpha=32,
  target_modules=["q_proj", "v_proj"],
  lora_dropout=0.1,
  bias="none",
  task_type="CAUSAL_LM"
)

# Apply LoRA adapter
model = get_peft_model(model, lora_config)

# Now model uses ~8GB GPU memory instead of 80GB
# Perfect if you only have 8GB GPU available
print(f"Model memory usage: ~8GB (vs 16GB for LoRA, 80GB for full fine-tuning)")
```

QLoRA vs LoRA Trade-offs

QLoRA enables training on smaller GPUs but introduces slight quality degradation from quantization (typically 1-3% performance loss). LoRA requires more memory but maintains full precision.

Quality Impact: The 4-bit quantization causes a small loss in model precision. For most tasks, this translates to 1-3% lower accuracy or slightly less natural outputs. For your customer support chatbot, this might mean 97% accuracy instead of 99% - often acceptable if it enables training on available hardware.

Training Speed: QLoRA may be slightly slower (10-20%) than LoRA due to quantization/dequantization overhead, but both are much faster than full fine-tuning.

When to Choose Each

For your customer support chatbot:

You have 16GB GPU: Use LoRA for maximum quality (recommended)
If you only had 8GB GPU: Use QLoRA (acceptable 1-3% quality trade-off)
Choose QLoRA when:

GPU memory is limited (8-16GB)
Slight quality trade-off is acceptable for your use case
Need to train on consumer hardware
Want to experiment with multiple models on limited hardware
Choose LoRA when:

GPU memory is available (16GB+) - your situation
Maximum quality is required - important for customer support
Training on professional GPUs
Quality is more important than hardware constraints
PEFT Training Workflow
Implementing PEFT fine-tuning follows a standard workflow with adapter-specific considerations.

Step 1: Configure Adapter

Choose LoRA or QLoRA based on memory constraints and quality requirements. Configure rank, alpha, and target modules based on task complexity.

Step 2: Prepare Model

Load base model (with quantization for QLoRA) and apply adapter configuration.

Step 3: Train Adapter

Train only adapter parameters. Use standard training loops but ensure only adapter parameters have requires_grad=True.

```python
# Complete PEFT Training Workflow for Customer Support Chatbot
# Assumes you've already configured LoRA adapter and loaded model (see earlier examples)

from transformers import TrainingArguments, Trainer, AutoTokenizer
import json

# Load your prepared dataset
with open("data/customer_support_final.json", "r") as f:
  dataset = json.load(f)

# Format dataset for instruction tuning
def format_instruction(example):
  instruction = example["instruction"]
  input_text = example["input"]
  output = example["output"]
  prompt = f"### Instruction:\n{instruction}\n\n### Input:\n{input_text}\n\n### Response:\n{output}"
  return {"text": prompt}

formatted_dataset = [format_instruction(ex) for ex in dataset]

# Configure training arguments
training_args = TrainingArguments(
  output_dir="./chatbot_results",
  num_train_epochs=3,
  per_device_train_batch_size=4,
  gradient_accumulation_steps=4,  # Effective batch size = 16
  learning_rate=2e-4,  # LoRA uses higher learning rates than full fine-tuning
  logging_steps=10,
  save_steps=500,
  evaluation_strategy="steps",
  eval_steps=500,
  save_total_limit=3
)

# Create trainer and train
trainer = Trainer(
  model=model,  # Your LoRA model from earlier setup
  args=training_args,
  train_dataset=formatted_dataset[:2000],
  eval_dataset=formatted_dataset[2000:],
  tokenizer=tokenizer
)

trainer.train()

# Save adapter (only ~20MB, not full 14GB model)
model.save_pretrained("./chatbot_adapter")
print("✅ Adapter saved! Ready for deployment.")
```

Step 4: Save and Load Adapters

Save only adapter weights (typically 10-50MB) rather than full model weights. Load adapters onto base models for inference or further training.

Multiple Adapters

PEFT enables training multiple task-specific adapters on the same base model. You can train separate adapters for different tasks (e.g., one for classification, one for generation) and switch between them during inference without retraining the base model. Each adapter is small (10-50MB), making it practical to maintain multiple specialized models.

To use multiple adapters, train each adapter separately with its task-specific dataset, save each adapter to a different directory, then load the appropriate adapter when needed for inference. This approach is more efficient than training separate full models for each task.

Choosing Between LoRA and QLoRA
Selecting between LoRA and QLoRA depends on your hardware constraints and quality requirements. For your customer support chatbot with a 16GB GPU, LoRA is the recommended choice.

Memory Constraints

8-16GB GPU: Use QLoRA (4-bit quantization required)
16-24GB GPU: Use LoRA (full precision possible) - Your situation
24GB+ GPU: Use LoRA for maximum quality
Quality Requirements

Maximum quality needed: Use LoRA (full precision) - Important for customer support
Slight quality trade-off acceptable: Use QLoRA (1-3% degradation)
Training Speed

QLoRA may be slightly slower due to quantization overhead, but the difference is typically minimal. Both are much faster than full fine-tuning.

Common Pitfalls
Rank Too Low: Using rank r=4 for complex tasks leads to underfitting. Start with r=16 for most tasks, increase to r=32-64 for complex tasks.

Rank Too High: Using rank r=128 for simple tasks wastes parameters and increases overfitting risk. Use lower ranks for simpler tasks.

Wrong Target Modules: Adapting only q_proj may be insufficient for complex tasks. Adapt q_proj, k_proj, v_proj, o_proj for better capacity.

Ignoring Quantization Quality Loss: QLoRA introduces slight quality degradation. Validate that QLoRA performance meets requirements before deploying.

Summary
PEFT techniques (LoRA, QLoRA) enable efficient fine-tuning with minimal parameter updates. For your customer support chatbot, LoRA reduces memory requirements from 80GB to 16GB, enabling training on your available hardware. QLoRA would enable training on 8GB GPUs with slight quality trade-offs.

You configured LoRA with r=16, alpha=32, targeting all attention layers - appropriate for your moderate complexity chatbot that handles classification, generation, and extraction. This configuration balances capacity and efficiency, avoiding overfitting while maintaining good performance.

Key concepts to remember
LoRA - Reduces memory 10-100x, maintains full precision (use for your 16GB GPU)
QLoRA - Enables training on 8GB GPUs with 4-bit quantization (1-3% quality trade-off)
Configuration - Rank r=16 with all attention layers for your chatbot
Memory Requirements - LoRA: 16GB+ (your setup), QLoRA: 8GB+
Training - Only adapter weights are trainable (~4M params vs 7B full model)