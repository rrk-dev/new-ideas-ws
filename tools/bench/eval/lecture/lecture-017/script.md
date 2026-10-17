# lecture-017 - CPU Scheduling

Synthetic lecture (fictional lecturer and course).

Good morning everyone, I am Professor Tobias Wren, and welcome to CS 330 Operating Systems at Wingtip Institute.
Today's topic is cpu scheduling. Schedulers decide which process runs next to balance throughput and responsiveness.
Let me define a term first: context switch means saving one process's state and loading another's.
Let me define a term first: time slice means the maximum time a process runs before being preempted.
Now let us look at basic policies.
First come first served is simple but can starve short jobs.
Shortest job first minimises average waiting time.
Now let us look at interactive systems.
Round robin gives each process a time slice.
Multilevel feedback queues adapt to process behaviour.
Here is a question to think about before next time. What is the cost of a very short time slice?
Your assignment: simulate round robin for the given workload, due before the midterm.
The reading for this is the scheduling chapter of the OS textbook.
That is all for today, see you next time.
