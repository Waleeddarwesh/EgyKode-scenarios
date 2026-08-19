"It is highly available" is a belief until somebody tests it.

Chaos engineering is not breaking things at random. It is the discipline of
writing down what you expect, causing the smallest failure that tests it, and
treating a disproved expectation as the finding — which means the experiments
that surprise you are the valuable ones.

**What you will do**

1. **Write a hypothesis**, then kill a Pod and measure whether reality matched it
2. **Find a failure your replicas do not survive** — and it will not be the one
   you expect
3. **Keep the record**, because an experiment nobody wrote down is an anecdote

Every experiment here runs under steady traffic, so a failure is something you
**observe** rather than infer from the absence of complaints.

```
kubectl get nodes
kubectl -n chaos get all
```{{exec}}
