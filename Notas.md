# 1. Short-Circuit Evaluation

```python
if user is not None and user.is_active:
    ...
```

Avoids evaluating expensive or unsafe expressions.

### Rule

For `A and B`

* Put the condition most likely to be `False` first.
* Put the cheapest condition first.

For `A or B`

* Put the condition most likely to be `True` first.
* Put the cheapest condition first.

---

# 2. Fail Fast

Reject invalid requests as early as possible.

Instead of:

```python
if request:
    if request.user:
        if request.user.role == "admin":
            ...
```

Use:

```python
if not request:
    return

if not request.user:
    return

if request.user.role != "admin":
    return
```

Benefits:

* Less nesting
* Easier debugging
* Less CPU work

---

# 3. Cheap Checks Before Expensive Checks

Bad:

```python
if database.user_exists(email) and email.endswith("@company.com"):
```

Good:

```python
if email.endswith("@company.com") and database.user_exists(email):
```

String operation:

```text
O(length)
```

Database query:

```text
milliseconds + network
```

---

# 4. Filter Before Transform

Bad:

```python
processed = [
    expensive_transform(x)
    for x in items
]

processed = [x for x in processed if x.valid]
```

Good:

```python
processed = [
    expensive_transform(x)
    for x in items
    if x.enabled
]
```

Reduce work before expensive operations.

---

# 5. Push Computation to the Database

Bad:

```python
users = db.get_all_users()

active = [
    u for u in users
    if u.status == "ACTIVE"
]
```

Good:

```sql
SELECT *
FROM users
WHERE status = 'ACTIVE'
```

Move filtering closer to data.

Benefits:

* Less memory
* Less network traffic
* Better index usage

---

# 6. Use Set Instead of List for Membership

Bad:

```python
if user_id in user_ids:
```

where:

```python
user_ids = [1, 2, 3, ...]
```

Complexity:

```text
O(n)
```

Better:

```python
user_ids = set(user_ids)

if user_id in user_ids:
```

Complexity:

```text
O(1)
```

Huge difference at scale.

---

# 7. Cache Expensive Operations

Bad:

```python
for order in orders:
    rate = get_exchange_rate()
```

Good:

```python
rate = get_exchange_rate()

for order in orders:
    ...
```

Avoid repeated work.

---

# 8. Batch Instead of Looping

Bad:

```python
for user_id in ids:
    db.get_user(user_id)
```

1000 queries.

Good:

```python
db.get_users(ids)
```

1 query.

This eliminates the classic N+1 problem.

---

# 9. Select Only Needed Columns

Bad:

```sql
SELECT *
FROM users
```

Good:

```sql
SELECT id, email
FROM users
```

Benefits:

* Less network
* Less memory
* Faster deserialization

---

# 10. Use Pagination Everywhere

Bad:

```sql
SELECT *
FROM transactions
```

Good:

```sql
SELECT *
FROM transactions
LIMIT 100
```

Never assume tables stay small.

---

# 11. Avoid Repeated Object Creation

Bad:

```python
for _ in range(10000):
    regex = re.compile(pattern)
```

Good:

```python
regex = re.compile(pattern)

for _ in range(10000):
    ...
```

Compiled objects are often expensive.

---

# 12. Prefer Hash Maps Over Linear Search

Bad:

```python
for user in users:
    if user.id == target:
        return user
```

Good:

```python
users_by_id = {
    user.id: user
    for user in users
}

return users_by_id[target]
```

Complexity:

```text
O(n) -> O(1)
```

---

# 13. Avoid Calling Remote Services Twice

Bad:

```python
if auth_service.exists(user):
    profile = auth_service.get(user)
```

Good:

```python
profile = auth_service.get(user)

if profile:
    ...
```

Every network call is expensive.

---

# 14. Connection Pooling

Bad:

```python
for request in requests:
    conn = create_connection()
```

Good:

```python
pool.acquire()
```

Creating connections is often more expensive than queries.

Applicable to:

* PostgreSQL
* Redis
* RabbitMQ
* HTTP clients

---

# 15. Reuse HTTP Clients

Bad:

```python
requests.get(...)
```

inside loops.

Good:

```python
session = requests.Session()
```

or

```python
httpx.Client()
```

Connection reuse saves:

* TCP handshakes
* TLS handshakes

---

# 16. Avoid Premature Serialization

Bad:

```python
json.dumps(data)
json.loads(data)
```

multiple times in the same request.

Keep data as objects as long as possible.

Serialization is surprisingly expensive.

---

# 17. Use Streaming for Large Files

Bad:

```python
content = file.read()
```

Good:

```python
for chunk in file:
    ...
```

Prevents memory spikes.

---

# 18. Idempotency for Distributed Systems

Bad:

```python
POST /charge
```

Client retries:

```text
Charge happens twice
```

Good:

```python
Idempotency-Key
```

Store processed keys.

Critical for:

* Payments
* Messaging
* Event-driven systems

---

# 19. Put High-Cardinality Columns in Indexes Carefully

Bad index:

```sql
CREATE INDEX idx_status
ON users(status)
```

if:

```text
ACTIVE = 99%
INACTIVE = 1%
```

Low selectivity.

Better:

```sql
CREATE INDEX idx_email
ON users(email)
```

High-cardinality fields benefit indexes more.

---

# 20. Reduce Lock Duration

Bad:

```python
BEGIN

SELECT ...

call_external_api()

UPDATE ...

COMMIT
```

Good:

```python
call_external_api()

BEGIN

SELECT ...

UPDATE ...

COMMIT
```

Hold locks for the shortest time possible.

---

# 21. Avoid Work Inside Critical Sections

Bad:

```python
with lock:
    process_large_file()
```

Good:

```python
result = process_large_file()

with lock:
    save_result(result)
```

Improves concurrency.

---

# 22. Use Lazy Evaluation

Bad:

```python
results = [
    expensive(x)
    for x in million_records
]
```

Good:

```python
results = (
    expensive(x)
    for x in million_records
)
```

Generator:

* Lower memory
* Starts processing immediately

---

# 23. Measure Before Optimizing

Many engineers optimize:

```python
string concatenation
```

while the real bottleneck is:

```python
database
network
serialization
```

Typical latency hierarchy:

```text
CPU cache        ~ ns
RAM              ~ 100 ns
SSD              ~ 100 µs
Database         ~ ms
Remote service   ~ 10-1000 ms
```

The biggest gains usually come from:

1. Reducing network calls.
2. Reducing database queries.
3. Better indexes.
4. Caching.
5. Batching.

Micro-optimizations come later.

---

A useful mental model for backend systems is:

```text
Avoid work.
If work is necessary:
    Do it once.
If it must be repeated:
    Batch it.
If it cannot be batched:
    Cache it.
If it cannot be cached:
    Move it closer to the data.
```

That single principle explains a large percentage of high-performance backend design decisions.

---

# 24. Reduce Object Allocations

Every object allocation has a cost.

Bad:

```python
for user in users:
    result = {
        "id": user.id,
        "name": user.name,
    }
```

Creates thousands of temporary dictionaries.

Better:

* Reuse objects when possible.
* Process data directly.

General rule:

```text
Less allocation = less GC work
```

---

# 25. Avoid Creating Temporary Objects

Bad:

```python
total = sum([x.price for x in products])
```

Creates an intermediate list.

Better:

```python
total = sum(x.price for x in products)
```

Uses a generator.

Memory:

```text
O(n) → O(1)
```

---

# 26. Prefer Iterators Over Materialization

Bad:

```python
records = list(database_stream)
```

Good:

```python
for record in database_stream:
    process(record)
```

Useful when processing:

* CSV files
* Database cursors
* Kafka messages
* Large API responses

---

# 27. Reduce Garbage Collection Pressure

GC is not free.

Bad:

```python
while True:
    obj = SomeObject()
```

Millions of short-lived objects.

Good:

```python
obj = SomeObject()

while True:
    obj.reset()
```

Common in:

* High-frequency trading
* Game engines
* Low-latency services

---

# 28. Object Pooling

Instead of:

```python
request = Request()
```

every time.

Use:

```python
request = pool.acquire()
```

then:

```python
pool.release(request)
```

Useful when objects are:

* Large
* Expensive to initialize
* Frequently reused

Examples:

* DB connections
* HTTP connections
* Buffers

---

# 29. Beware of Hidden Copies

Bad:

```python
new_data = data[:]
```

Copies the entire structure.

Also:

```python
new_data = list(data)
```

or

```python
new_data = dict(data)
```

For large collections this can become expensive.

Ask:

```text
Do I really need a copy?
```

---

# 30. Pass References Instead of Cloning

Bad:

```python
process(big_object.copy())
```

Good:

```python
process(big_object)
```

unless mutation is required.

Copying large objects is often one of the biggest hidden memory costs.

---

# 31. Use String Builders

Bad:

```python
result = ""

for item in items:
    result += item
```

Potentially creates many intermediate strings.

Good:

```python
result = "".join(items)
```

or

```python
buffer = io.StringIO()
```

Many languages provide specialized builders:

* Java → StringBuilder
* C# → StringBuilder
* Go → strings.Builder

---

# 32. Avoid Large Objects on Hot Paths

Bad:

```python
class User:
    ...
    profile_picture
    preferences
    history
    analytics
```

when only:

```python
user.id
```

is needed.

Better:

```python
class UserSummary:
    id
    email
```

Load only what you need.

---

# 33. Use Memory-Friendly Data Structures

Example:

Bad:

```python
users = [
    {"id":1, "name":"John"},
    ...
]
```

Good:

```python
@dataclass(slots=True)
class User:
    id: int
    name: str
```

or in other languages:

* Structs
* Records
* POD objects

Less memory overhead.

---

# 34. Understand Cache Locality

CPU cache is orders of magnitude faster than RAM.

Bad:

```text
Linked List
```

Memory scattered everywhere.

Good:

```text
Array
Vector
Slice
```

Memory contiguous.

This is why many modern systems prefer:

```text
Array + Index
```

instead of

```text
Pointer-heavy trees
```

for performance-critical workloads.

---

# 35. Minimize Pointer Chasing

Bad:

```text
User
 └─ Profile
     └─ Settings
         └─ Theme
```

Every dereference may miss cache.

Better:

```text
UserSettings
```

flattened when performance matters.

Common in:

* Databases
* Search engines
* Game engines

---

# 36. Avoid Excessive Recursion

Every recursive call consumes stack memory.

Bad:

```python
def walk(node):
    walk(node.left)
```

Deep trees can cause:

```text
Stack overflow
```

Better:

```python
stack = [root]
```

Use an explicit stack.

---

# 37. Watch for Memory Leaks Through References

A classic leak:

```python
cache = []

while True:
    cache.append(big_object)
```

Objects are never freed.

GC only frees objects that are unreachable.

If references remain:

```text
Memory never returns
```

---

# 38. Beware of Closures Capturing Large Objects

Bad:

```python
large_data = load_1gb_file()

handler = lambda: process(large_data)
```

The closure keeps the entire object alive.

Common source of leaks in:

* Async systems
* Event handlers
* Callbacks

---

# 39. Avoid Global Caches Without Limits

Bad:

```python
cache[key] = value
```

forever.

Good:

```python
LRU Cache
TTL Cache
Size-Limited Cache
```

Examples:

```python
functools.lru_cache
Redis TTL
Guava Cache
Caffeine
```

---

# 40. Stream Instead of Buffering

Bad:

```python
response = requests.get(url).content
```

Loads everything.

Better:

```python
requests.get(url, stream=True)
```

Process chunks.

Useful for:

* PDFs
* Videos
* Backups
* Data pipelines

---

# 41. Avoid Deserializing Unused Data

Bad:

```python
user = json.loads(big_json)
```

Need only:

```python
user["id"]
```

Some parsers support:

* Partial parsing
* Streaming parsing
* SAX parsing

Huge savings for large payloads.

---

# 42. Reuse Buffers

Bad:

```python
buffer = bytearray(1024 * 1024)
```

inside a loop.

Good:

```python
buffer = bytearray(1024 * 1024)

while True:
    ...
```

Popular in:

* Networking
* Compression
* File processing

---

# 43. Know Your Language's GC Characteristics

### Python

Reference counting + generational GC.

Problem:

```python
Circular references
```

can survive until GC runs.

---

### Java

GC pauses depend heavily on allocation rate.

Rule:

```text
Lower allocation rate = lower GC activity
```

---

### Go

GC targets low pauses, but:

```text
More allocations = more GC cycles
```

Common optimization:

```go
sync.Pool
```

---

### Node.js

Single-threaded event loop.

Large GC pauses can affect all requests.

---

# 44. Profile Allocations, Not Just CPU

Most engineers look only at:

```text
CPU %
```

But often the real problem is:

```text
Allocation rate
Heap growth
GC pauses
```

Useful tools:

* Python → tracemalloc, memory_profiler
* Go → pprof
* Java → JFR, VisualVM
* Node → heap snapshots

---

# 45. Data-Oriented Thinking

Many developers think:

```text
What objects do I need?
```

High-performance systems think:

```text
What data do I need?
```

Example:

Bad:

```python
for user in users:
    process(user)
```

where `user` contains 50 fields.

Good:

```python
for user_id in user_ids:
    process(user_id)
```

Move less data through the system.

---

# 46. Avoid Large Heap Growth Spikes

Bad:

```python
records = db.fetch_10_million_rows()
```

Good:

```python
for batch in db.fetch_batches(1000):
    process(batch)
```

Benefits:

* Lower memory usage
* Smaller GC pauses
* Better latency

---

# 47. Prefer Stack Allocation When Available

In languages like C, C++, Rust, and sometimes Go:

Stack:

```text
Fast allocation
Fast deallocation
No GC
```

Heap:

```text
Allocator cost
GC cost
Fragmentation
```

General rule:

```text
Small, short-lived objects belong on the stack.
Large or dynamic objects belong on the heap.
```

---

# 48. The Latency Hierarchy Every Backend Engineer Should Know

Approximate costs:

```text
CPU Register      ~ 1 cycle
L1 Cache          ~ 1-3 cycles
L2 Cache          ~ 10 cycles
L3 Cache          ~ 40 cycles
RAM               ~ 100-300 cycles
SSD               ~ 100,000 cycles
Network           ~ millions of cycles
```

This leads to a useful optimization order:

```text
1. Eliminate network calls
2. Eliminate database queries
3. Reduce disk access
4. Improve memory access patterns
5. Reduce allocations
6. Reduce CPU work
```

Many systems spend more time waiting for memory than executing instructions. Understanding allocations, cache locality, and GC behavior is often what separates a backend that handles 1,000 requests/sec from one that handles 100,000 requests/sec.
