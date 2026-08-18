#!/bin/bash
# Two namespaces, so "allowed here, refused there" is a thing you can test.
kubectl create namespace team-a >/dev/null 2>&1
kubectl create namespace team-b >/dev/null 2>&1

# Something to list in each.
kubectl run web --image=nginx:1.27-alpine -n team-a >/dev/null 2>&1
kubectl run web --image=nginx:1.27-alpine -n team-b >/dev/null 2>&1

# The over-grant the learner will find in step 3. Every inherited cluster has
# one of these, and it is always there because something did not work once.
kubectl create serviceaccount legacy-ci -n team-a >/dev/null 2>&1
kubectl create clusterrolebinding legacy-ci-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=team-a:legacy-ci >/dev/null 2>&1

kubectl config set-context --current --namespace=team-a >/dev/null 2>&1
echo done
