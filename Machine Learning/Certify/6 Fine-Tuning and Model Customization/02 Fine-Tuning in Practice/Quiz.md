## Quiz: Fine-Tuning in Practice

Fine-Tuning in Practice
You are fine-tuning a 7B language model for a customer support chatbot. You have a dataset of 2,000 support interactions, need to train on a 16GB GPU, and want to achieve 90% accuracy on support ticket classification and response generation.


Your chatbot needs to handle varied user instructions (classify tickets, generate responses, extract information). Which tuning approach should you use?

Completion tuning - it's more efficient

Instruction tuning - it teaches models to follow varied instructions

Either works equally well

Full fine-tuning only - adapters are insufficient
Correct Answer!
Instruction tuning teaches models to interpret and follow varied instructions, making it suitable for interactive applications that handle multiple task types.

You have 2,000 examples for a chatbot that handles classification and generation. Is this sufficient?

Yes, 2,000 is more than enough for any task

Yes, 2,000 is sufficient for moderate complexity tasks like chatbots

No, you need at least 10,000 examples

No, you need at least 50,000 examples
Correct Answer!
2,000 examples is within the typical range (2,000-5,000) for moderate complexity tasks like chatbots that handle classification and generation.

You have a 16GB GPU and want to fine-tune a 7B model. Should you use LoRA or QLoRA?

QLoRA - 16GB is not enough for LoRA

LoRA - 16GB is sufficient and provides better quality

QLoRA - it's always better

Full fine-tuning - adapters are insufficient
Correct Answer!
LoRA works on 16GB GPUs for 7B models and maintains full precision, providing better quality than QLoRA's 4-bit quantization.

What LoRA configuration is appropriate for a moderate complexity chatbot task?

r=4, alpha=8, target only q_proj

r=16, alpha=32, target q_proj and v_proj

r=128, alpha=256, target all linear layers

r=8, alpha=8, target only v_proj
Correct Answer!
r=16 with alpha=32 is a standard configuration for moderate complexity tasks. Targeting q_proj and v_proj provides good capacity without overfitting.

During training, you observe that training loss decreases steadily but validation loss increases after epoch 2. What is happening?

The model is learning well - continue training

The model is overfitting - increase dropout or reduce capacity

The model is underfitting - increase capacity

Training is unstable - reduce learning rate
Correct Answer!
This is classic overfitting: the model memorizes training data (decreasing train loss) but fails to generalize (increasing val loss). Fix with increased dropout, reduced LoRA rank, or regularization.