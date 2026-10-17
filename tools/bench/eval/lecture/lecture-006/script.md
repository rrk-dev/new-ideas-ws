# lecture-006 - Hash Tables

Synthetic lecture (fictional lecturer and course).

Good morning everyone, I am Professor Alder, and welcome to CS 214 Algorithms at Fabrikam Institute.
Today's topic is hash tables. Hash tables give near constant time lookups by mapping keys to buckets.
Let me define a term first: hash function means a function that maps a key to a bucket index.
Let me define a term first: collision means two different keys that map to the same bucket.
Let me define a term first: load factor means the ratio of stored items to buckets.
Now let us look at chaining.
Each bucket holds a linked list of items.
Several of you asked about this last time, so I want to be clear.
Take a second to let that sink in before we move on.
Several of you asked about this last time, so I want to be clear.
Take a second to let that sink in before we move on.
Lookups walk the list in the bucket.
Do not worry if it is not obvious yet; it gets easier with practice.
Take a second to let that sink in before we move on.
It is easy to rush past this, so let me say it again slowly.
Several of you asked about this last time, so I want to be clear.
Now let us look at open addressing.
Collisions probe for the next free slot.
That point is worth pausing on for a moment.
Several of you asked about this last time, so I want to be clear.
We will keep coming back to this idea as the term goes on.
That point is worth pausing on for a moment.
Deletion needs a tombstone marker.
I know that can feel abstract, so hold on to it.
I know that can feel abstract, so hold on to it.
It is easy to rush past this, so let me say it again slowly.
That point is worth pausing on for a moment.
Now let us look at worked example.
We walk through one complete example on the board.
Do not worry if it is not obvious yet; it gets easier with practice.
That point is worth pausing on for a moment.
We will keep coming back to this idea as the term goes on.
Several of you asked about this last time, so I want to be clear.
Check each step against the definition.
It is easy to rush past this, so let me say it again slowly.
It is easy to rush past this, so let me say it again slowly.
Do not worry if it is not obvious yet; it gets easier with practice.
Do not worry if it is not obvious yet; it gets easier with practice.
Now let us look at common mistakes.
Students often skip the setup.
Several of you asked about this last time, so I want to be clear.
I know that can feel abstract, so hold on to it.
It is easy to rush past this, so let me say it again slowly.
That point is worth pausing on for a moment.
Units and signs cause most errors.
Do not worry if it is not obvious yet; it gets easier with practice.
We will keep coming back to this idea as the term goes on.
We will keep coming back to this idea as the term goes on.
It is easy to rush past this, so let me say it again slowly.
Now let us look at historical background.
The idea developed over several decades.
Do not worry if it is not obvious yet; it gets easier with practice.
We will keep coming back to this idea as the term goes on.
Take a second to let that sink in before we move on.
Do not worry if it is not obvious yet; it gets easier with practice.
Early versions were much simpler.
That point is worth pausing on for a moment.
I know that can feel abstract, so hold on to it.
Do not worry if it is not obvious yet; it gets easier with practice.
Several of you asked about this last time, so I want to be clear.
Now let us look at applications.
The method is used in industry every day.
It is easy to rush past this, so let me say it again slowly.
We will keep coming back to this idea as the term goes on.
Do not worry if it is not obvious yet; it gets easier with practice.
I know that can feel abstract, so hold on to it.
Smaller projects benefit as well.
It is easy to rush past this, so let me say it again slowly.
We will keep coming back to this idea as the term goes on.
I know that can feel abstract, so hold on to it.
Take a second to let that sink in before we move on.
Now let us look at limits.
Every model has assumptions.
It is easy to rush past this, so let me say it again slowly.
We will keep coming back to this idea as the term goes on.
That point is worth pausing on for a moment.
Take a second to let that sink in before we move on.
Know when they fail.
Several of you asked about this last time, so I want to be clear.
It is easy to rush past this, so let me say it again slowly.
Several of you asked about this last time, so I want to be clear.
I know that can feel abstract, so hold on to it.
Now let us look at related topics.
We will connect this to earlier weeks.
I know that can feel abstract, so hold on to it.
We will keep coming back to this idea as the term goes on.
It is easy to rush past this, so let me say it again slowly.
Several of you asked about this last time, so I want to be clear.
Later lectures extend it.
That point is worth pausing on for a moment.
Do not worry if it is not obvious yet; it gets easier with practice.
Several of you asked about this last time, so I want to be clear.
I know that can feel abstract, so hold on to it.
Here is a question to think about before next time. How does the load factor affect lookup time?
Your assignment: implement a hash table with chaining, due Friday March 20th.
The reading for this is the hashing chapter of the course reader.
That is all for today, see you next time.
